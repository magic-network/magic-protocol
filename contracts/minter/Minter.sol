pragma solidity ^0.4.4;

import "../Manager.sol";
import "./IMinter.sol";
import "../token/IMagicToken.sol";
import "../rounds/IRoundsManager.sol";
import "../staking/IStakingManager.sol";
import "../libraries/MathUtils.sol";

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

/**
 * @title Minter
 * @dev Manages inflation rate and the minting of new tokens for each round of the Magic protocol
 */
contract Minter is Manager, IMinter {
    using SafeMath for uint256;

    // Per round inflation rate
    uint256 public inflation;
    // Change in inflation rate per round until the target bonding rate is achieved
    uint256 public inflationChange;
    // Target bonding rate
    uint256 public targetBondingRate;

    // Current number of mintable tokens. Reset every round
    uint256 public currentMintableTokens;
    // Current number of minted tokens. Reset every round
    uint256 public currentMintedTokens;

    // Checks if caller is StakingManager
    modifier onlyStakingManager() {
        require(msg.sender == controller.getContract("StakingManager"));
        _;
    }

    // Checks if caller is RoundsManager
    modifier onlyRoundsManager() {
        require(msg.sender == controller.getContract("RoundsManager"));
        _;
    }

    // Checks if caller is either StakingManager or JobsManager
    modifier onlyStakingManagerOrJobsManager() {
        require(msg.sender == controller.getContract("StakingManager") || msg.sender == controller.getContract("JobsManager"));
        _;
    }

    // Checks if caller is either the currently registered Minter or JobsManager
    modifier onlyMinterOrJobsManager() {
        require(msg.sender == controller.getContract("Minter") || msg.sender == controller.getContract("JobsManager"));
        _;
    }

    /**
     * @dev Minter constructor
     * @param _inflation Base inflation rate as a percentage of current total token supply
     * @param _inflationChange Change in inflation rate each round (increase or decrease) if target bonding rate is not achieved
     * @param _targetBondingRate Target bonding rate as a percentage of total bonded tokens / total token supply
     */
    constructor (address _controller, uint256 _inflation, uint256 _inflationChange, uint256 _targetBondingRate) public Manager(_controller) {
        // Inflation must be valid percentage
        require(MathUtils.validPerc(_inflation));
        // Inflation change must be valid percentage
        require(MathUtils.validPerc(_inflationChange));
        // Target bonding rate must be valid percentage
        require(MathUtils.validPerc(_targetBondingRate));

        inflation = _inflation;
        inflationChange = _inflationChange;
        targetBondingRate = _targetBondingRate;
    }

    /**
     * @dev Set targetBondingRate. Only callable by Controller owner
     * @param _targetBondingRate Target bonding rate as a percentage of total bonded tokens / total token supply
     */
    function setTargetBondingRate(uint256 _targetBondingRate) external onlyControllerOwner {
        // Must be valid percentage
        require(MathUtils.validPerc(_targetBondingRate));

        targetBondingRate = _targetBondingRate;

        emit ParameterUpdate("targetBondingRate");
    }

    /**
     * @dev Set inflationChange. Only callable by Controller owner
     * @param _inflationChange Inflation change as a percentage of total token supply
     */
    function setInflationChange(uint256 _inflationChange) external onlyControllerOwner {
        // Must be valid percentage
        require(MathUtils.validPerc(_inflationChange));

        inflationChange = _inflationChange;

        emit ParameterUpdate("inflationChange");
    }

    /**
     * @dev Migrate to a new Minter by transferring ownership of the token as well
     * as the current Minter's token balance to the new Minter. Only callable by Controller when system is paused
     * @param _newMinter Address of new Minter
     */
    function migrateToNewMinter(IMinter _newMinter) external onlyControllerOwner whenSystemPaused {
        // New Minter cannot be the current Minter
        require(_newMinter != this);
        // Check for null address
        require(address(_newMinter) != address(0));

        IController newMinterController = _newMinter.getController();
        // New Minter must have same Controller as current Minter
        require(newMinterController == controller);
        // New Minter's Controller must have the current Minter registered
        require(newMinterController.getContract("Minter") == address(this));

        // Transfer ownership of token to new Minter
        magicToken().transferOwnership(_newMinter);
        // Transfer current Minter's token balance to new Minter
        magicToken().transfer(_newMinter, magicToken().balanceOf(this));
        // Transfer current Minter's ETH balance to new Minter
        _newMinter.depositETH.value(address(this).balance)();
    }

    /**
     * @dev Create reward based on a fractional portion of the mintable tokens for the current round
     * @param _fracNum Numerator of fraction (active transcoder's stake)
     * @param _fracDenom Denominator of fraction (total active stake)
     */
    function createReward(uint256 _fracNum, uint256 _fracDenom) external onlyStakingManager whenSystemNotPaused returns (uint256) {
        // Compute and mint fraction of mintable tokens to include in reward
        uint256 mintAmount = MathUtils.percOf(currentMintableTokens, _fracNum, _fracDenom);
        // Update amount of minted tokens for round
        currentMintedTokens = currentMintedTokens.add(mintAmount);
        // Minted tokens must not exceed mintable tokens
        require(currentMintedTokens <= currentMintableTokens);
        // Mint new tokens
        magicToken().mint(this, mintAmount);

        // Reward = minted tokens
        return mintAmount;
    }

    /**
     * @dev Transfer tokens to a receipient. Only callable by StakingManager - always trusts StakingManager
     * @param _to Recipient address
     * @param _amount Amount of tokens
     */
    function trustedTransferTokens(address _to, uint256 _amount) external onlyStakingManager whenSystemNotPaused {
        magicToken().transfer(_to, _amount);
    }

    /**
     * @dev Burn tokens. Only callable by StakingManager - always trusts StakingManager
     * @param _amount Amount of tokens to burn
     */
    function trustedBurnTokens(uint256 _amount) external onlyStakingManager whenSystemNotPaused {
        magicToken().burn(_amount);
    }

    /**
     * @dev Withdraw ETH to a recipient. Only callable by StakingManager or JobsManager - always trusts these two contracts
     * @param _to Recipient address
     * @param _amount Amount of ETH
     */
    function trustedWithdrawETH(address _to, uint256 _amount) external onlyStakingManagerOrJobsManager whenSystemNotPaused {
        _to.transfer(_amount);
    }

    /**
     * @dev Deposit ETH to this contract. Only callable by the currently registered Minter or JobsManager
     */
    function depositETH() external payable onlyMinterOrJobsManager whenSystemNotPaused returns (bool) {
        return true;
    }

    /**
     * @dev Set inflation and mintable tokens for the round. Only callable by the RoundsManager
     */
    function setCurrentRewardTokens() external onlyRoundsManager whenSystemNotPaused {
        setInflation();

        // Set mintable tokens based upon current inflation and current total token supply
        currentMintableTokens = MathUtils.percOf(magicToken().totalSupply(), inflation);
        currentMintedTokens = 0;

        emit SetCurrentRewardTokens(currentMintableTokens, inflation);
    }

    /**
     * @dev Returns Controller interface
     */
    function getController() public view returns (IController) {
        return controller;
    }

    /**
     * @dev Set inflation based upon the current bonding rate and target bonding rate
     */
    function setInflation() internal {
        uint256 currentBondingRate = 0;
        uint256 totalSupply = magicToken().totalSupply();

        if (totalSupply > 0) {
            uint256 totalBonded = stakingManager().getTotalBonded();
            currentBondingRate = MathUtils.percPoints(totalBonded, totalSupply);
        }

        if (currentBondingRate < targetBondingRate) {
            // Bonding rate is below the target - increase inflation
            inflation = inflation.add(inflationChange);
        } else if (currentBondingRate > targetBondingRate) {
            // Bonding rate is above the target - decrease inflation
            if (inflationChange > inflation) {
                inflation = 0;
            } else {
                inflation = inflation.sub(inflationChange);
            }
        }
    }

    /**
     * @dev Returns MagicToken interface
     */
    function magicToken() internal view returns (IMagicToken) {
        return IMagicToken(controller.getContract("MagicToken"));
    }

    /**
     * @dev Returns StakingManager interface
     */
    function stakingManager() internal view returns (IStakingManager) {
        return IStakingManager(controller.getContract("StakingManager"));
    }
}
