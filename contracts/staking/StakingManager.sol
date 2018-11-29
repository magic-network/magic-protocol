pragma solidity ^0.4.4;

import "../ManagerProxyTarget.sol";
import "./IStakingManager.sol";
import "../libraries/SortedDoublyLL.sol";
import "../libraries/MathUtils.sol";
import "./libraries/EarningsPool.sol";
import "../token/IMagicToken.sol";
import "../minter/IMinter.sol";
import "../rounds/IRoundsManager.sol";

import 'openzeppelin-solidity/contracts/math/Math.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';


/**
 * @title StakingManager (WIP)
 * @dev Manages staking and rewards/fee accounting related operations of the Magic protocol
 */
contract StakingManager is ManagerProxyTarget, IStakingManager {

    using SafeMath for uint256;
    using SortedDoublyLL for SortedDoublyLL.Data;
    using EarningsPool for EarningsPool.Data;

    // Time between unbonding and possible withdrawal in rounds
    uint64 public unbondingPeriod;
    // Number of active enablers
    uint256 public numActiveEnablers;
    // Max number of rounds that a caller can claim earnings for at once
    uint256 public maxEarningsClaimsRounds;

    // Represents a enabler's current state
    struct Enabler {
        uint256 lastRewardRound;                             // Last round that the enabler called reward
        uint256 rewardCut;                                   // % of reward paid to enabler by a delegator
        uint256 feeShare;                                    // % of fees paid to delegators by enabler
        uint256 pricePerSegment;                             // Price per segment (denominated in MGC units) for a stream
        uint256 pendingRewardCut;                            // Pending reward cut for next round if the enabler is active
        uint256 pendingFeeShare;                             // Pending fee share for next round if the enabler is active
        uint256 pendingPricePerSegment;                      // Pending price per segment for next round if the enabler is active
        mapping (uint256 => EarningsPool.Data) earningsPoolPerRound;  // Mapping of round => earnings pool for the round
    }

    // The various states a enabler can be in
    enum EnablerStatus { NotRegistered, Registered }

    // Represents a delegator's current state
    struct Delegator {
        uint256 bondedAmount;                    // The amount of bonded tokens
        uint256 fees;                            // The amount of fees collected
        address delegateAddress;                 // The address delegated to
        uint256 delegatedAmount;                 // The amount of tokens delegated to the delegator
        uint256 startRound;                      // The round the delegator transitions to bonded phase and is delegated to someone
        uint256 withdrawRoundDEPRECATED;         // DEPRECATED - DO NOT USE
        uint256 lastClaimRound;                  // The last round during which the delegator claimed its earnings
        uint256 nextUnbondingLockId;             // ID for the next unbonding lock created
        mapping (uint256 => UnbondingLock) unbondingLocks; // Mapping of unbonding lock ID => unbonding lock
    }

    // The various states a delegator can be in
    enum DelegatorStatus { Pending, Bonded, Unbonded }

    // Represents an amount of tokens that are being unbonded
    struct UnbondingLock {
        uint256 amount;              // Amount of tokens being unbonded
        uint256 withdrawRound;       // Round at which unbonding period is over and tokens can be withdrawn
    }

    // Keep track of the known enablers and delegators
    mapping (address => Delegator) private delegators;
    mapping (address => Enabler) private enablers;

    // Keep track of total bonded tokens
    uint256 private totalBonded;

    // Candidate and reserve enablers
    SortedDoublyLL.Data private enablerPool;

    // Represents the active enabler set
    struct ActiveEnablerSet {
        address[] enablers;
        mapping (address => bool) isActive;
        uint256 totalStake;
    }

    // Keep track of active enabler set for each round
    mapping (uint256 => ActiveEnablerSet) public activeEnablerSet;

    // Check if sender is JobsManager
    modifier onlyJobsManager() {
        require(msg.sender == controller.getContract("JobsManager"));
        _;
    }

    // Check if sender is RoundsManager
    modifier onlyRoundsManager() {
        require(msg.sender == controller.getContract("RoundsManager"));
        _;
    }

    // Check if current round is initialized
    modifier currentRoundInitialized() {
        require(roundsManager().currentRoundInitialized());
        _;
    }

    // Automatically claim earnings from lastClaimRound through the current round
    modifier autoClaimEarnings() {
        updateDelegatorWithEarnings(msg.sender, roundsManager().currentRound());
        _;
    }

    /**
     * @dev StakingManager constructor. Only invokes constructor of base Manager contract with provided Controller address
     * @param _controller Address of Controller that this contract will be registered with
     */
    constructor (address _controller) public Manager(_controller) {}

    /**
     * @dev Set unbonding period. Only callable by Controller owner
     * @param _unbondingPeriod Rounds between unbonding and possible withdrawal
     */
    function setUnbondingPeriod(uint64 _unbondingPeriod) external onlyControllerOwner {
        unbondingPeriod = _unbondingPeriod;

        emit ParameterUpdate("unbondingPeriod");
    }

    /**
     * @dev Set max number of registered enablers. Only callable by Controller owner
     * @param _numEnablers Max number of registered enablers
     */
    function setNumEnablers(uint256 _numEnablers) external onlyControllerOwner {
        // Max number of enablers must be greater than or equal to number of active enablers
        require(_numEnablers >= numActiveEnablers);

        enablerPool.setMaxSize(_numEnablers);

        emit ParameterUpdate("numEnablers");
    }

    /**
     * @dev Set number of active enablers. Only callable by Controller owner
     * @param _numActiveEnablers Number of active enablers
     */
    function setNumActiveEnablers(uint256 _numActiveEnablers) external onlyControllerOwner {
        // Number of active enablers cannot exceed max number of enablers
        require(_numActiveEnablers <= enablerPool.getMaxSize());

        numActiveEnablers = _numActiveEnablers;

        emit ParameterUpdate("numActiveEnablers");
    }

    /**
     * @dev Set max number of rounds a caller can claim earnings for at once. Only callable by Controller owner
     * @param _maxEarningsClaimsRounds Max number of rounds a caller can claim earnings for at once
     */
    function setMaxEarningsClaimsRounds(uint256 _maxEarningsClaimsRounds) external onlyControllerOwner {
        maxEarningsClaimsRounds = _maxEarningsClaimsRounds;

        emit ParameterUpdate("maxEarningsClaimsRounds");
    }

    /**
     * @dev The sender is declaring themselves as a candidate for active enabling.
     * @param _rewardCut % of reward paid to enabler by a delegator
     * @param _feeShare % of fees paid to delegators by a enabler
     * @param _pricePerSegment Price per segment (denominated in Wei) for a stream
     */
    function enabler(uint256 _rewardCut, uint256 _feeShare, uint256 _pricePerSegment)
        external
        whenSystemNotPaused
        currentRoundInitialized
    {
        Enabler storage t = enablers[msg.sender];
        Delegator storage del = delegators[msg.sender];

        if (roundsManager().currentRoundLocked()) {
            // If it is the lock period of the current round
            // the lowest price previously set by any enabler
            // becomes the price floor and the caller can lower its
            // own price to a point greater than or equal to the price floor

            // Caller must already be a registered enabler
            require(enablerStatus(msg.sender) == EnablerStatus.Registered);
            // Provided rewardCut value must equal the current pendingRewardCut value
            // This value cannot change during the lock period
            require(_rewardCut == t.pendingRewardCut);
            // Provided feeShare value must equal the current pendingFeeShare value
            // This value cannot change during the lock period
            require(_feeShare == t.pendingFeeShare);

            // Iterate through the enabler pool to find the price floor
            // Since the caller must be a registered enabler, the enabler pool size will always at least be 1
            // Thus, we can safely set the initial price floor to be the pendingPricePerSegment of the first
            // enabler in the pool
            address currentEnabler = enablerPool.getFirst();
            uint256 priceFloor = enablers[currentEnabler].pendingPricePerSegment;
            for (uint256 i = 0; i < enablerPool.getSize(); i++) {
                if (enablers[currentEnabler].pendingPricePerSegment < priceFloor) {
                    priceFloor = enablers[currentEnabler].pendingPricePerSegment;
                }

                currentEnabler = enablerPool.getNext(currentEnabler);
            }

            // Provided pricePerSegment must be greater than or equal to the price floor and
            // less than or equal to the previously set pricePerSegment by the caller
            require(_pricePerSegment >= priceFloor && _pricePerSegment <= t.pendingPricePerSegment);

            t.pendingPricePerSegment = _pricePerSegment;

            emit EnablerUpdate(msg.sender, t.pendingRewardCut, t.pendingFeeShare, _pricePerSegment, true);
        } else {
            // It is not the lock period of the current round
            // Caller is free to change rewardCut, feeShare, pricePerSegment as it pleases
            // If caller is not a registered enabler, it can also register and join the enabler pool
            // if it has sufficient delegated stake
            // If caller is not a registered enabler and does not have sufficient delegated stake
            // to join the enabler pool, it can change rewardCut, feeShare, pricePerSegment
            // as information signals to delegators in an effort to camapaign and accumulate
            // more delegated stake

            // Reward cut must be a valid percentage
            require(MathUtils.validPerc(_rewardCut));
            // Fee share must be a valid percentage
            require(MathUtils.validPerc(_feeShare));

            // Must have a non-zero amount bonded to self
            require(del.delegateAddress == msg.sender && del.bondedAmount > 0);

            t.pendingRewardCut = _rewardCut;
            t.pendingFeeShare = _feeShare;
            t.pendingPricePerSegment = _pricePerSegment;

            uint256 delegatedAmount = del.delegatedAmount;

            // Check if enabler is not already registered
            if (enablerStatus(msg.sender) == EnablerStatus.NotRegistered) {
                if (!enablerPool.isFull()) {
                    // If pool is not full add new enabler
                    enablerPool.insert(msg.sender, delegatedAmount, address(0), address(0));
                } else {
                    address lastEnabler = enablerPool.getLast();

                    if (delegatedAmount > enablerPool.getKey(lastEnabler)) {
                        // If pool is full and caller has more delegated stake than the enabler in the pool with the least delegated stake:
                        // - Evict enabler in pool with least delegated stake
                        // - Add caller to pool
                        enablerPool.remove(lastEnabler);
                        enablerPool.insert(msg.sender, delegatedAmount, address(0), address(0));

                        emit EnablerEvicted(lastEnabler);
                    }
                }
            }

            emit EnablerUpdate(msg.sender, _rewardCut, _feeShare, _pricePerSegment, enablerPool.contains(msg.sender));
        }
    }

    /**
     * @dev Delegate stake towards a specific address.
     * @param _amount The amount of MGC to stake.
     * @param _to The address of the enabler to stake towards.
     */
    function bond(
        uint256 _amount,
        address _to
    )
        external
        whenSystemNotPaused
        currentRoundInitialized
        autoClaimEarnings
    {
        Delegator storage del = delegators[msg.sender];

        uint256 currentRound = roundsManager().currentRound();
        // Amount to delegate
        uint256 delegationAmount = _amount;
        // Current delegate
        address currentDelegate = del.delegateAddress;

        if (delegatorStatus(msg.sender) == DelegatorStatus.Unbonded) {
            // New delegate
            // Set start round
            // Don't set start round if delegator is in pending state because the start round would not change
            del.startRound = currentRound.add(1);
            // Unbonded state = no existing delegate and no bonded stake
            // Thus, delegation amount = provided amount
        } else if (del.delegateAddress != address(0) && _to != del.delegateAddress) {
            // A registered enabler cannot delegate its bonded stake toward another address
            // because it can only be delegated toward itself
            // In the future, if delegation towards another registered enabler as an already
            // registered enabler becomes useful (i.e. for transitive delegation), this restriction
            // could be removed
            require(enablerStatus(msg.sender) == EnablerStatus.NotRegistered);
            // Changing delegate
            // Set start round
            del.startRound = currentRound.add(1);
            // Update amount to delegate with previous delegation amount
            delegationAmount = delegationAmount.add(del.bondedAmount);
            // Decrease old delegate's delegated amount
            delegators[currentDelegate].delegatedAmount = delegators[currentDelegate].delegatedAmount.sub(del.bondedAmount);

            if (enablerStatus(currentDelegate) == EnablerStatus.Registered) {
                // Previously delegated to a enabler
                // Decrease old enabler's total stake
                enablerPool.updateKey(currentDelegate, enablerPool.getKey(currentDelegate).sub(del.bondedAmount), address(0), address(0));
            }
        }

        // Delegation amount must be > 0 - cannot delegate to someone without having bonded stake
        require(delegationAmount > 0);
        // Update delegate
        del.delegateAddress = _to;
        // Update current delegate's delegated amount with delegation amount
        delegators[_to].delegatedAmount = delegators[_to].delegatedAmount.add(delegationAmount);

        if (enablerStatus(_to) == EnablerStatus.Registered) {
            // Delegated to a enabler
            // Increase enabler's total stake
            enablerPool.updateKey(_to, enablerPool.getKey(del.delegateAddress).add(delegationAmount), address(0), address(0));
        }

        if (_amount > 0) {
            // Update bonded amount
            del.bondedAmount = del.bondedAmount.add(_amount);
            // Update total bonded tokens
            totalBonded = totalBonded.add(_amount);
            // Transfer the MGC to the Minter
            magicToken().transferFrom(msg.sender, minter(), _amount);
        }

        emit Bond(_to, currentDelegate, msg.sender, _amount, del.bondedAmount);
    }

    /**
     * @dev Unbond an amount of the delegator's bonded stake
     * @param _amount Amount of tokens to unbond
     */
    function unbond(uint256 _amount)
        external
        whenSystemNotPaused
        currentRoundInitialized
        autoClaimEarnings
    {
        // Caller must be in bonded state
        require(delegatorStatus(msg.sender) == DelegatorStatus.Bonded);

        Delegator storage del = delegators[msg.sender];

        // Amount must be greater than 0
        require(_amount > 0);
        // Amount to unbond must be less than or equal to current bonded amount
        require(_amount <= del.bondedAmount);

        address currentDelegate = del.delegateAddress;
        uint256 currentRound = roundsManager().currentRound();
        uint256 withdrawRound = currentRound.add(unbondingPeriod);
        uint256 unbondingLockId = del.nextUnbondingLockId;

        // Create new unbonding lock
        del.unbondingLocks[unbondingLockId] = UnbondingLock({
            amount: _amount,
            withdrawRound: withdrawRound
        });
        // Increment ID for next unbonding lock
        del.nextUnbondingLockId = unbondingLockId.add(1);
        // Decrease delegator's bonded amount
        del.bondedAmount = del.bondedAmount.sub(_amount);
        // Decrease delegate's delegated amount
        delegators[del.delegateAddress].delegatedAmount = delegators[del.delegateAddress].delegatedAmount.sub(_amount);
        // Update total bonded tokens
        totalBonded = totalBonded.sub(_amount);

        if (enablerStatus(del.delegateAddress) == EnablerStatus.Registered && (del.delegateAddress != msg.sender || del.bondedAmount > 0)) {
            // A enabler's delegated stake within the registered pool needs to be decreased if:
            // - The caller's delegate is a registered enabler
            // - Caller is not delegated to self OR caller is delegated to self and has a non-zero bonded amount
            // If the caller is delegated to self and has a zero bonded amount, it will be removed from the
            // enabler pool so its delegated stake within the pool does not need to be decreased
            enablerPool.updateKey(del.delegateAddress, enablerPool.getKey(del.delegateAddress).sub(_amount), address(0), address(0));
        }

        // Check if delegator has a zero bonded amount
        // If so, update its delegation status
        if (del.bondedAmount == 0) {
            // Delegator no longer delegated to anyone if it does not have a bonded amount
            del.delegateAddress = address(0);
            // Delegator does not have a start round if it is no longer delegated to anyone
            del.startRound = 0;

            if (enablerStatus(msg.sender) == EnablerStatus.Registered) {
                // If caller is a registered enabler and is no longer bonded, resign
                resignEnabler(msg.sender);
            }
        }

        emit Unbond(currentDelegate, msg.sender, unbondingLockId, _amount, withdrawRound);
    }

    /**
     * @dev Rebond tokens for an unbonding lock to a delegator's current delegate while a delegator
     * is in the Bonded or Pending states
     * @param _unbondingLockId ID of unbonding lock to rebond with
     */
    function rebond(
        uint256 _unbondingLockId
    )
        external
        whenSystemNotPaused
        currentRoundInitialized
        autoClaimEarnings
    {
        // Caller must not be an unbonded delegator
        require(delegatorStatus(msg.sender) != DelegatorStatus.Unbonded);

        // Process rebond using unbonding lock
        processRebond(msg.sender, _unbondingLockId);
    }

    /**
     * @dev Rebond tokens for an unbonding lock to a delegate while a delegator
     * is in the Unbonded state
     * @param _to Address of delegate
     * @param _unbondingLockId ID of unbonding lock to rebond with
     */
    function rebondFromUnbonded(
        address _to,
        uint256 _unbondingLockId
    )
        external
        whenSystemNotPaused
        currentRoundInitialized
        autoClaimEarnings
    {
        // Caller must be an unbonded delegator
        require(delegatorStatus(msg.sender) == DelegatorStatus.Unbonded);

        // Set delegator's start round and transition into Pending state
        delegators[msg.sender].startRound = roundsManager().currentRound().add(1);
        // Set delegator's delegate
        delegators[msg.sender].delegateAddress = _to;
        // Process rebond using unbonding lock
        processRebond(msg.sender, _unbondingLockId);
    }

    /**
     * @dev Withdraws tokens for an unbonding lock that has existed through an unbonding period
     * @param _unbondingLockId ID of unbonding lock to withdraw with
     */
    function withdrawStake(uint256 _unbondingLockId)
        external
        whenSystemNotPaused
        currentRoundInitialized
    {
        Delegator storage del = delegators[msg.sender];
        UnbondingLock storage lock = del.unbondingLocks[_unbondingLockId];

        // Unbonding lock must be valid
        require(isValidUnbondingLock(msg.sender, _unbondingLockId));
        // Withdrawal must be valid for the unbonding lock i.e. the withdraw round is now or in the past
        require(lock.withdrawRound <= roundsManager().currentRound());

        uint256 amount = lock.amount;
        uint256 withdrawRound = lock.withdrawRound;
        // Delete unbonding lock
        delete del.unbondingLocks[_unbondingLockId];

        // Tell Minter to transfer stake (MGC) to the delegator
        minter().trustedTransferTokens(msg.sender, amount);

        emit WithdrawStake(msg.sender, _unbondingLockId, amount, withdrawRound);
    }

    /**
     * @dev Withdraws fees to the caller
     */
    function withdrawFees()
        external
        whenSystemNotPaused
        currentRoundInitialized
        autoClaimEarnings
    {
        // Delegator must have fees
        require(delegators[msg.sender].fees > 0);

        uint256 amount = delegators[msg.sender].fees;
        delegators[msg.sender].fees = 0;

        // Tell Minter to transfer fees (ETH) to the delegator
        minter().trustedWithdrawETH(msg.sender, amount);

        emit WithdrawFees(msg.sender);
    }

    /**
     * @dev Set active enabler set for the current round
     */
    function setActiveEnablers() external whenSystemNotPaused onlyRoundsManager {
        uint256 currentRound = roundsManager().currentRound();
        uint256 activeSetSize = Math.min(numActiveEnablers, enablerPool.getSize());

        uint256 totalStake = 0;
        address currentEnabler = enablerPool.getFirst();

        for (uint256 i = 0; i < activeSetSize; i++) {
            activeEnablerSet[currentRound].enablers.push(currentEnabler);
            activeEnablerSet[currentRound].isActive[currentEnabler] = true;

            uint256 stake = enablerPool.getKey(currentEnabler);
            uint256 rewardCut = enablers[currentEnabler].pendingRewardCut;
            uint256 feeShare = enablers[currentEnabler].pendingFeeShare;
            uint256 pricePerSegment = enablers[currentEnabler].pendingPricePerSegment;

            Enabler storage t = enablers[currentEnabler];
            // Set pending rates as current rates
            t.rewardCut = rewardCut;
            t.feeShare = feeShare;
            t.pricePerSegment = pricePerSegment;
            // Initialize token pool
            t.earningsPoolPerRound[currentRound].init(stake, rewardCut, feeShare);

            totalStake = totalStake.add(stake);

            // Get next enabler in the pool
            currentEnabler = enablerPool.getNext(currentEnabler);
        }

        // Update total stake of all active enablers
        activeEnablerSet[currentRound].totalStake = totalStake;
    }

    /**
     * @dev Distribute the token rewards to enabler and delegates.
     * Active enablers call this once per cycle when it is their turn.
     */
    function reward() external whenSystemNotPaused currentRoundInitialized {
        uint256 currentRound = roundsManager().currentRound();

        // Sender must be an active enabler
        require(activeEnablerSet[currentRound].isActive[msg.sender]);

        // Enabler must not have called reward for this round already
        require(enablers[msg.sender].lastRewardRound != currentRound);
        // Set last round that enabler called reward
        enablers[msg.sender].lastRewardRound = currentRound;

        // Create reward based on active enabler's stake relative to the total active stake
        // rewardTokens = (current mintable tokens for the round * active enabler stake) / total active stake
        uint256 rewardTokens = minter().createReward(activeEnablerTotalStake(msg.sender, currentRound), activeEnablerSet[currentRound].totalStake);

        updateEnablerWithRewards(msg.sender, rewardTokens, currentRound);

        emit Reward(msg.sender, rewardTokens);
    }

    /**
     * @dev Update enabler's fee pool
     * @param _enabler Enabler address
     * @param _fees Fees from verified job claims
     */
    function updateEnablerWithFees(
        address _enabler,
        uint256 _fees,
        uint256 _round
    )
        external
        whenSystemNotPaused
        onlyJobsManager
    {
        // Enabler must be registered
        require(enablerStatus(_enabler) == EnablerStatus.Registered);

        Enabler storage t = enablers[_enabler];

        EarningsPool.Data storage earningsPool = t.earningsPoolPerRound[_round];
        // Add fees to fee pool
        earningsPool.addToFeePool(_fees);
    }

    /**
     * @dev Slash a enabler. Slashing can be invoked by the protocol or a finder.
     * @param _enabler Enabler address
     * @param _finder Finder that proved a enabler violated a slashing condition. Null address if there is no finder
     * @param _slashAmount Percentage of enabler bond to be slashed
     * @param _finderFee Percentage of penalty awarded to finder. Zero if there is no finder
     */
    function slashEnabler(
        address _enabler,
        address _finder,
        uint256 _slashAmount,
        uint256 _finderFee
    )
        external
        whenSystemNotPaused
        onlyJobsManager
    {
        Delegator storage del = delegators[_enabler];

        if (del.bondedAmount > 0) {
            uint256 penalty = MathUtils.percOf(delegators[_enabler].bondedAmount, _slashAmount);

            // Decrease bonded stake
            del.bondedAmount = del.bondedAmount.sub(penalty);

            // If still bonded
            // - Decrease delegate's delegated amount
            // - Decrease total bonded tokens
            if (delegatorStatus(_enabler) == DelegatorStatus.Bonded) {
                delegators[del.delegateAddress].delegatedAmount = delegators[del.delegateAddress].delegatedAmount.sub(penalty);
                totalBonded = totalBonded.sub(penalty);
            }

            // If registered enabler, resign it
            if (enablerStatus(_enabler) == EnablerStatus.Registered) {
                resignEnabler(_enabler);
            }

            // Account for penalty
            uint256 burnAmount = penalty;

            // Award finder fee if there is a finder address
            if (_finder != address(0)) {
                uint256 finderAmount = MathUtils.percOf(penalty, _finderFee);
                minter().trustedTransferTokens(_finder, finderAmount);

                // Minter burns the slashed funds - finder reward
                minter().trustedBurnTokens(burnAmount.sub(finderAmount));

                emit EnablerSlashed(_enabler, _finder, penalty, finderAmount);
            } else {
                // Minter burns the slashed funds
                minter().trustedBurnTokens(burnAmount);

                emit EnablerSlashed(_enabler, address(0), penalty, 0);
            }
        } else {
            emit EnablerSlashed(_enabler, _finder, 0, 0);
        }
    }

    /**
     * @dev Pseudorandomly elect a currently active enabler that charges a price per segment less than or equal to the max price per segment for a job
     * Returns address of elected active enabler and its price per segment
     * @param _maxPricePerSegment Max price (in MGC base units) per segment of a stream
     * @param _blockHash Job creation block hash used as a pseudorandom seed for assigning an active enabler
     * @param _round Job creation round
     */
    function electActiveEnabler(uint256 _maxPricePerSegment, bytes32 _blockHash, uint256 _round) external view returns (address) {
        uint256 activeSetSize = activeEnablerSet[_round].enablers.length;
        // Create array to store available enablers charging an acceptable price per segment
        address[] memory availableEnablers = new address[](activeSetSize);
        // Keep track of the actual number of available enablers
        uint256 numAvailableEnablers = 0;
        // Keep track of total stake of available enablers
        uint256 totalAvailableEnablerStake = 0;

        for (uint256 i = 0; i < activeSetSize; i++) {
            address activeEnabler = activeEnablerSet[_round].enablers[i];
            // If a enabler is active and charges an acceptable price per segment add it to the array of available enablers
            if (activeEnablerSet[_round].isActive[activeEnabler] && enablers[activeEnabler].pricePerSegment <= _maxPricePerSegment) {
                availableEnablers[numAvailableEnablers] = activeEnabler;
                numAvailableEnablers++;
                totalAvailableEnablerStake = totalAvailableEnablerStake.add(activeEnablerTotalStake(activeEnabler, _round));
            }
        }

        if (numAvailableEnablers == 0) {
            // There is no currently available enabler that charges a price per segment less than or equal to the max price per segment for a job
            return address(0);
        } else {
            // Pseudorandomly pick an available enabler weighted by its stake relative to the total stake of all available enablers
            uint256 r = uint256(_blockHash) % totalAvailableEnablerStake;
            uint256 s = 0;
            uint256 j = 0;

            while (s <= r && j < numAvailableEnablers) {
                s = s.add(activeEnablerTotalStake(availableEnablers[j], _round));
                j++;
            }

            return availableEnablers[j - 1];
        }
    }

    /**
     * @dev Claim token pools shares for a delegator from its lastClaimRound through the end round
     * @param _endRound The last round for which to claim token pools shares for a delegator
     */
    function claimEarnings(uint256 _endRound) external whenSystemNotPaused currentRoundInitialized {
        // End round must be after the last claim round
        require(delegators[msg.sender].lastClaimRound < _endRound);
        // End round must not be after the current round
        require(_endRound <= roundsManager().currentRound());

        updateDelegatorWithEarnings(msg.sender, _endRound);
    }

    /**
     * @dev Returns pending bonded stake for a delegator from its lastClaimRound through an end round
     * @param _delegator Address of delegator
     * @param _endRound The last round to compute pending stake from
     */
    function pendingStake(address _delegator, uint256 _endRound) public view returns (uint256) {
        uint256 currentRound = roundsManager().currentRound();
        Delegator storage del = delegators[_delegator];
        // End round must be before or equal to current round and after lastClaimRound
        require(_endRound <= currentRound && _endRound > del.lastClaimRound);

        uint256 currentBondedAmount = del.bondedAmount;

        for (uint256 i = del.lastClaimRound + 1; i <= _endRound; i++) {
            EarningsPool.Data storage earningsPool = enablers[del.delegateAddress].earningsPoolPerRound[i];

            bool isEnabler = _delegator == del.delegateAddress;
            if (earningsPool.hasClaimableShares()) {
                // Calculate and add reward pool share from this round
                currentBondedAmount = currentBondedAmount.add(earningsPool.rewardPoolShare(currentBondedAmount, isEnabler));
            }
        }

        return currentBondedAmount;
    }

    /**
     * @dev Returns pending fees for a delegator from its lastClaimRound through an end round
     * @param _delegator Address of delegator
     * @param _endRound The last round to compute pending fees from
     */
    function pendingFees(address _delegator, uint256 _endRound) public view returns (uint256) {
        uint256 currentRound = roundsManager().currentRound();
        Delegator storage del = delegators[_delegator];
        // End round must be before or equal to current round and after lastClaimRound
        require(_endRound <= currentRound && _endRound > del.lastClaimRound);

        uint256 currentFees = del.fees;
        uint256 currentBondedAmount = del.bondedAmount;

        for (uint256 i = del.lastClaimRound + 1; i <= _endRound; i++) {
            EarningsPool.Data storage earningsPool = enablers[del.delegateAddress].earningsPoolPerRound[i];

            if (earningsPool.hasClaimableShares()) {
                bool isEnabler = _delegator == del.delegateAddress;
                // Calculate and add fee pool share from this round
                currentFees = currentFees.add(earningsPool.feePoolShare(currentBondedAmount, isEnabler));
                // Calculate new bonded amount with rewards from this round. Updated bonded amount used
                // to calculate fee pool share in next round
                currentBondedAmount = currentBondedAmount.add(earningsPool.rewardPoolShare(currentBondedAmount, isEnabler));
            }
        }

        return currentFees;
    }

    /**
     * @dev Returns total bonded stake for an active enabler
     * @param _enabler Address of a enabler
     */
    function activeEnablerTotalStake(address _enabler, uint256 _round) public view returns (uint256) {
        // Must be active enabler
        require(activeEnablerSet[_round].isActive[_enabler]);

        return enablers[_enabler].earningsPoolPerRound[_round].totalStake;
    }

    /**
     * @dev Returns total bonded stake for a enabler
     * @param _enabler Address of enabler
     */
    function enablerTotalStake(address _enabler) public view returns (uint256) {
        return enablerPool.getKey(_enabler);
    }

    /*
     * @dev Computes enabler status
     * @param _enabler Address of enabler
     */
    function enablerStatus(address _enabler) public view returns (EnablerStatus) {
        if (enablerPool.contains(_enabler)) {
            return EnablerStatus.Registered;
        } else {
            return EnablerStatus.NotRegistered;
        }
    }

    /**
     * @dev Computes delegator status
     * @param _delegator Address of delegator
     */
    function delegatorStatus(address _delegator) public view returns (DelegatorStatus) {
        Delegator storage del = delegators[_delegator];

        if (del.bondedAmount == 0) {
            // Delegator unbonded all its tokens
            return DelegatorStatus.Unbonded;
        } else if (del.startRound > roundsManager().currentRound()) {
            // Delegator round start is in the future
            return DelegatorStatus.Pending;
        } else if (del.startRound > 0 && del.startRound <= roundsManager().currentRound()) {
            // Delegator round start is now or in the past
            return DelegatorStatus.Bonded;
        } else {
            // Default to unbonded
            return DelegatorStatus.Unbonded;
        }
    }

    /**
     * @dev Return enabler information
     * @param _enabler Address of enabler
     */
    function getEnabler(
        address _enabler
    )
        public
        view
        returns (uint256 lastRewardRound, uint256 rewardCut, uint256 feeShare, uint256 pricePerSegment, uint256 pendingRewardCut, uint256 pendingFeeShare, uint256 pendingPricePerSegment)
    {
        Enabler storage t = enablers[_enabler];

        lastRewardRound = t.lastRewardRound;
        rewardCut = t.rewardCut;
        feeShare = t.feeShare;
        pricePerSegment = t.pricePerSegment;
        pendingRewardCut = t.pendingRewardCut;
        pendingFeeShare = t.pendingFeeShare;
        pendingPricePerSegment = t.pendingPricePerSegment;
    }

    /**
     * @dev Return enabler's token pools for a given round
     * @param _enabler Address of enabler
     * @param _round Round number
     */
    function getEnablerEarningsPoolForRound(
        address _enabler,
        uint256 _round
    )
        public
        view
        returns (uint256 rewardPool, uint256 feePool, uint256 totalStake, uint256 claimableStake, uint256 enablerRewardCut, uint256 enablerFeeShare, uint256 enablerRewardPool, uint256 enablerFeePool, bool hasEnablerRewardFeePool)
    {
        EarningsPool.Data storage earningsPool = enablers[_enabler].earningsPoolPerRound[_round];

        rewardPool = earningsPool.rewardPool;
        feePool = earningsPool.feePool;
        totalStake = earningsPool.totalStake;
        claimableStake = earningsPool.claimableStake;
        enablerRewardCut = earningsPool.enablerRewardCut;
        enablerFeeShare = earningsPool.enablerFeeShare;
        enablerRewardPool = earningsPool.enablerRewardPool;
        enablerFeePool = earningsPool.enablerFeePool;
        hasEnablerRewardFeePool = earningsPool.hasEnablerRewardFeePool;
    }

    /**
     * @dev Return delegator info
     * @param _delegator Address of delegator
     */
    function getDelegator(
        address _delegator
    )
        public
        view
        returns (uint256 bondedAmount, uint256 fees, address delegateAddress, uint256 delegatedAmount, uint256 startRound, uint256 lastClaimRound, uint256 nextUnbondingLockId)
    {
        Delegator storage del = delegators[_delegator];

        bondedAmount = del.bondedAmount;
        fees = del.fees;
        delegateAddress = del.delegateAddress;
        delegatedAmount = del.delegatedAmount;
        startRound = del.startRound;
        lastClaimRound = del.lastClaimRound;
        nextUnbondingLockId = del.nextUnbondingLockId;
    }

    /**
     * @dev Return delegator's unbonding lock info
     * @param _delegator Address of delegator
     * @param _unbondingLockId ID of unbonding lock
     */
    function getDelegatorUnbondingLock(
        address _delegator,
        uint256 _unbondingLockId
    )
        public
        view
        returns (uint256 amount, uint256 withdrawRound)
    {
        UnbondingLock storage lock = delegators[_delegator].unbondingLocks[_unbondingLockId];

        return (lock.amount, lock.withdrawRound);
    }

    /**
     * @dev Returns max size of enabler pool
     */
    function getEnablerPoolMaxSize() public view returns (uint256) {
        return enablerPool.getMaxSize();
    }

    /**
     * @dev Returns size of enabler pool
     */
    function getEnablerPoolSize() public view returns (uint256) {
        return enablerPool.getSize();
    }

    /**
     * @dev Returns enabler with most stake in pool
     */
    function getFirstEnablerInPool() public view returns (address) {
        return enablerPool.getFirst();
    }

    /**
     * @dev Returns next enabler in pool for a given enabler
     * @param _enabler Address of a enabler in the pool
     */
    function getNextEnablerInPool(address _enabler) public view returns (address) {
        return enablerPool.getNext(_enabler);
    }

    /**
     * @dev Return total bonded tokens
     */
    function getTotalBonded() public view returns (uint256) {
        return totalBonded;
    }

    /**
     * @dev Return total active stake for a round
     * @param _round Round number
     */
    function getTotalActiveStake(uint256 _round) public view returns (uint256) {
        return activeEnablerSet[_round].totalStake;
    }

    /**
     * @dev Return whether a enabler was active during a round
     * @param _enabler Enabler address
     * @param _round Round number
     */
    function isActiveEnabler(address _enabler, uint256 _round) public view returns (bool) {
        return activeEnablerSet[_round].isActive[_enabler];
    }

    /**
     * @dev Return whether a enabler is registered
     * @param _enabler Enabler address
     */
    function isRegisteredEnabler(address _enabler) public view returns (bool) {
        return enablerStatus(_enabler) == EnablerStatus.Registered;
    }

    /**
     * @dev Return whether an unbonding lock for a delegator is valid
     * @param _delegator Address of delegator
     * @param _unbondingLockId ID of unbonding lock
     */
    function isValidUnbondingLock(address _delegator, uint256 _unbondingLockId) public view returns (bool) {
        // A unbonding lock is only valid if it has a non-zero withdraw round (the default value is zero)
        return delegators[_delegator].unbondingLocks[_unbondingLockId].withdrawRound > 0;
    }

    /**
     * @dev Remove enabler
     */
    function resignEnabler(address _enabler) internal {
        uint256 currentRound = roundsManager().currentRound();
        if (activeEnablerSet[currentRound].isActive[_enabler]) {
            // Decrease total active stake for the round
            activeEnablerSet[currentRound].totalStake = activeEnablerSet[currentRound].totalStake.sub(activeEnablerTotalStake(_enabler, currentRound));
            // Set enabler as inactive
            activeEnablerSet[currentRound].isActive[_enabler] = false;
        }

        // Remove enabler from pools
        enablerPool.remove(_enabler);

        emit EnablerResigned(_enabler);
    }

    /**
     * @dev Update a enabler with rewards
     * @param _enabler Address of enabler
     * @param _rewards Amount of rewards
     * @param _round Round that enabler is updated
     */
    function updateEnablerWithRewards(address _enabler, uint256 _rewards, uint256 _round) internal {
        Enabler storage t = enablers[_enabler];
        Delegator storage del = delegators[_enabler];

        EarningsPool.Data storage earningsPool = t.earningsPoolPerRound[_round];
        // Add rewards to reward pool
        earningsPool.addToRewardPool(_rewards);
        // Update enabler's delegated amount with rewards
        del.delegatedAmount = del.delegatedAmount.add(_rewards);
        // Update enabler's total stake with rewards
        uint256 newStake = enablerPool.getKey(_enabler).add(_rewards);
        enablerPool.updateKey(_enabler, newStake, address(0), address(0));
        // Update total bonded tokens with claimable rewards
        totalBonded = totalBonded.add(_rewards);
    }

    /**
     * @dev Update a delegator with token pools shares from its lastClaimRound through a given round
     * @param _delegator Delegator address
     * @param _endRound The last round for which to update a delegator's stake with token pools shares
     */
    function updateDelegatorWithEarnings(address _delegator, uint256 _endRound) internal {
        Delegator storage del = delegators[_delegator];

        // Only will have earnings to claim if you have a delegate
        // If not delegated, skip the earnings claim process
        if (del.delegateAddress != address(0)) {
            // Cannot claim earnings for more than maxEarningsClaimsRounds
            // This is a number to cause transactions to fail early if
            // we know they will require too much gas to loop through all the necessary rounds to claim earnings
            // The user should instead manually invoke `claimEarnings` to split up the claiming process
            // across multiple transactions
            require(_endRound.sub(del.lastClaimRound) <= maxEarningsClaimsRounds);

            uint256 currentBondedAmount = del.bondedAmount;
            uint256 currentFees = del.fees;

            for (uint256 i = del.lastClaimRound + 1; i <= _endRound; i++) {
                EarningsPool.Data storage earningsPool = enablers[del.delegateAddress].earningsPoolPerRound[i];

                if (earningsPool.hasClaimableShares()) {
                    bool isEnabler = _delegator == del.delegateAddress;

                    (uint256 fees, uint256 rewards) = earningsPool.claimShare(currentBondedAmount, isEnabler);

                    currentFees = currentFees.add(fees);
                    currentBondedAmount = currentBondedAmount.add(rewards);
                }
            }

            // Rewards are bonded by default
            del.bondedAmount = currentBondedAmount;
            del.fees = currentFees;
        }

        del.lastClaimRound = _endRound;
    }

    /**
     * @dev Update the state of a delegator and its delegate by processing a rebond using an unbonding lock
     * @param _delegator Address of delegator
     * @param _unbondingLockId ID of unbonding lock to rebond with
     */
    function processRebond(address _delegator, uint256 _unbondingLockId) internal {
        Delegator storage del = delegators[_delegator];
        UnbondingLock storage lock = del.unbondingLocks[_unbondingLockId];

        // Unbonding lock must be valid
        require(isValidUnbondingLock(_delegator, _unbondingLockId));

        uint256 amount = lock.amount;
        // Increase delegator's bonded amount
        del.bondedAmount = del.bondedAmount.add(amount);
        // Increase delegate's delegated amount
        delegators[del.delegateAddress].delegatedAmount = delegators[del.delegateAddress].delegatedAmount.add(amount);
        // Update total bonded tokens
        totalBonded = totalBonded.add(amount);

        if (enablerStatus(del.delegateAddress) == EnablerStatus.Registered) {
            // If delegate is a registered enabler increase its delegated stake in registered pool
            enablerPool.updateKey(del.delegateAddress, enablerPool.getKey(del.delegateAddress).add(amount), address(0), address(0));
        }

        // Delete lock
        delete del.unbondingLocks[_unbondingLockId];

        emit Rebond(del.delegateAddress, _delegator, _unbondingLockId, amount);
    }

    /**
     * @dev Return magicToken interface
     */
    function magicToken() internal view returns (IMagicToken) {
        return IMagicToken(controller.getContract("magicToken"));
    }

    /**
     * @dev Return Minter interface
     */
    function minter() internal view returns (IMinter) {
        return IMinter(controller.getContract("Minter"));
    }

    /**
     * @dev Return RoundsManager interface
     */
    function roundsManager() internal view returns (IRoundsManager) {
        return IRoundsManager(controller.getContract("RoundsManager"));
    }
}
