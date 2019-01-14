pragma solidity ^0.4.24;

// File: contracts/IManager.sol

contract IManager {
    event SetController(address controller);
    event ParameterUpdate(string param);

    function setController(address _controller) external;
}

// File: openzeppelin-solidity/contracts/access/Roles.sol

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
  struct Role {
    mapping (address => bool) bearer;
  }

  /**
   * @dev give an account access to this role
   */
  function add(Role storage role, address account) internal {
    require(account != address(0));
    role.bearer[account] = true;
  }

  /**
   * @dev remove an account's access to this role
   */
  function remove(Role storage role, address account) internal {
    require(account != address(0));
    role.bearer[account] = false;
  }

  /**
   * @dev check if an account has this role
   * @return bool
   */
  function has(Role storage role, address account)
    internal
    view
    returns (bool)
  {
    require(account != address(0));
    return role.bearer[account];
  }
}

// File: openzeppelin-solidity/contracts/access/roles/PauserRole.sol

contract PauserRole {
  using Roles for Roles.Role;

  event PauserAdded(address indexed account);
  event PauserRemoved(address indexed account);

  Roles.Role private pausers;

  constructor() public {
    pausers.add(msg.sender);
  }

  modifier onlyPauser() {
    require(isPauser(msg.sender));
    _;
  }

  function isPauser(address account) public view returns (bool) {
    return pausers.has(account);
  }

  function addPauser(address account) public onlyPauser {
    pausers.add(account);
    emit PauserAdded(account);
  }

  function renouncePauser() public {
    pausers.remove(msg.sender);
  }

  function _removePauser(address account) internal {
    pausers.remove(account);
    emit PauserRemoved(account);
  }
}

// File: openzeppelin-solidity/contracts/lifecycle/Pausable.sol

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is PauserRole {
  event Paused();
  event Unpaused();

  bool private _paused = false;


  /**
   * @return true if the contract is paused, false otherwise.
   */
  function paused() public view returns(bool) {
    return _paused;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!_paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(_paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() public onlyPauser whenNotPaused {
    _paused = true;
    emit Paused();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() public onlyPauser whenPaused {
    _paused = false;
    emit Unpaused();
  }
}

// File: openzeppelin-solidity/contracts/ownership/Ownable.sol

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address private _owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    _owner = msg.sender;
  }

  /**
   * @return the address of the owner.
   */
  function owner() public view returns(address) {
    return _owner;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(isOwner());
    _;
  }

  /**
   * @return true if `msg.sender` is the owner of the contract.
   */
  function isOwner() public view returns(bool) {
    return msg.sender == _owner;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   * @notice Renouncing to ownership will leave the contract without an owner.
   * It will not be possible to call the functions with the `onlyOwner`
   * modifier anymore.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(_owner);
    _owner = address(0);
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0));
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

// File: contracts/IController.sol

contract IController is Pausable, Ownable {
    event SetContractInfo(string id, address contractAddress, string gitCommitHash);

    function setContractInfo(string _id, address _contractAddress, string _gitCommitHash) external;
    function updateController(string _id, address _controller) external;
    function getContract(string _id) public view returns (address);
}

// File: contracts/Manager.sol

contract Manager is IManager {
    // Controller that contract is registered with
    IController public controller;

    // Check if sender is controller
    modifier onlyController() {
        require(msg.sender == address(controller));
        _;
    }

    // Check if sender is controller owner
    modifier onlyControllerOwner() {
        require(msg.sender == controller.owner());
        _;
    }

    // Check if controller is not paused
    modifier whenSystemNotPaused() {
        require(!controller.paused());
        _;
    }

    // Check if controller is paused
    modifier whenSystemPaused() {
        require(controller.paused());
        _;
    }

    constructor (address _controller) public {
        controller = IController(_controller);
    }

    /*
     * @dev Set controller. Only callable by current controller
     * @param _controller Controller contract address
     */
    function setController(address _controller) external onlyController {
        controller = IController(_controller);

        emit SetController(_controller);
    }
}

// File: contracts/ManagerProxyTarget.sol

/**
 * @title ManagerProxyTarget
 * @dev The base contract that target contracts used by a proxy contract should inherit from
 * Note: Both the target contract and the proxy contract (implemented as ManagerProxy) MUST inherit from ManagerProxyTarget in order to guarantee
 * that both contracts have the same storage layout. Differing storage layouts in a proxy contract and target contract can
 * potentially break the delegate proxy upgradeability mechanism
 */
contract ManagerProxyTarget is Manager {
    // Used to look up target contract address in controller's registry
    string public targetContractId;
}

// File: contracts/staking/IStakingManager.sol

/*
 * @title Interface for BondingManager
 */
contract IStakingManager {

    event EnablerUpdate(address indexed enabler, uint256 pendingRewardCut, uint256 pendingFeeShare, uint256 pendingPricePerSegment, bool registered);
    event EnablerEvicted(address indexed enabler);
    event EnablerResigned(address indexed enabler);

    event EnablerSlashed(address indexed enabler, address finder, uint256 penalty, uint256 finderReward);
    event Reward(address indexed enabler, uint256 amount);
    event Bond(address indexed newDelegate, address indexed oldDelegate, address indexed delegator, uint256 additionalAmount, uint256 bondedAmount);
    event Unbond(address indexed delegate, address indexed delegator, uint256 unbondingLockId, uint256 amount, uint256 withdrawRound);
    event Rebond(address indexed delegate, address indexed delegator, uint256 unbondingLockId, uint256 amount);
    event WithdrawStake(address indexed delegator, uint256 unbondingLockId, uint256 amount, uint256 withdrawRound);
    event WithdrawFees(address indexed delegator);

    // External functions
    function setActiveEnablers() external;
    function updateEnablerWithFees(address _enabler, uint256 _fees, uint256 _round) external;
    function slashEnabler(address _enabler, address _finder, uint256 _slashAmount, uint256 _finderFee) external;
    function electActiveEnabler(uint256 _maxPricePerSegment, bytes32 _blockHash, uint256 _round) external view returns (address);

    // Public functions
    function enablerTotalStake(address _enabler) public view returns (uint256);
    function activeEnablerTotalStake(address _enabler, uint256 _round) public view returns (uint256);
    function isRegisteredEnabler(address _enabler) public view returns (bool);
    function getTotalBonded() public view returns (uint256);
}

// File: openzeppelin-solidity/contracts/math/SafeMath.sol

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);

    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

// File: contracts/libraries/SortedDoublyLL.sol

/*
 * @title A sorted doubly linked list with nodes sorted in descending order. Optionally accepts insert position hints
 *
 * Given a new node with a `key`, a hint is of the form `(prevId, nextId)` s.t. `prevId` and `nextId` are adjacent in the list.
 * `prevId` is a node with a key >= `key` and `nextId` is a node with a key <= `key`. If the sender provides a hint that is a valid insert position
 * the insert operation is a constant time storage write. However, the provided hint in a given transaction might be a valid insert position, but if other transactions are included first, when
 * the given transaction is executed the provided hint may no longer be a valid insert position. For example, one of the nodes referenced might be removed or their keys may
 * be updated such that the the pair of nodes in the hint no longer represent a valid insert position. If one of the nodes in the hint becomes invalid, we still try to use the other
 * valid node as a starting point for finding the appropriate insert position. If both nodes in the hint become invalid, we use the head of the list as a starting point
 * to find the appropriate insert position.
 */
library SortedDoublyLL {
    using SafeMath for uint256;

    // Information for a node in the list
    struct Node {
        uint256 key;                     // Node's key used for sorting
        address nextId;                  // Id of next node (smaller key) in the list
        address prevId;                  // Id of previous node (larger key) in the list
    }

    // Information for the list
    struct Data {
        address head;                        // Head of the list. Also the node in the list with the largest key
        address tail;                        // Tail of the list. Also the node in the list with the smallest key
        uint256 maxSize;                     // Maximum size of the list
        uint256 size;                        // Current size of the list
        mapping (address => Node) nodes;     // Track the corresponding ids for each node in the list
    }

    /*
     * @dev Set the maximum size of the list
     * @param _size Maximum size
     */
    function setMaxSize(Data storage self, uint256 _size) public {
        // New max size must be greater than old max size
        require(_size > self.maxSize);

        self.maxSize = _size;
    }

    /*
     * @dev Add a node to the list
     * @param _id Node's id
     * @param _key Node's key
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function insert(Data storage self, address _id, uint256 _key, address _prevId, address _nextId) public {
        // List must not be full
        require(!isFull(self));
        // List must not already contain node
        require(!contains(self, _id));
        // Node id must not be null
        require(_id != address(0));
        // Key must be non-zero
        require(_key > 0);

        address prevId = _prevId;
        address nextId = _nextId;

        if (!validInsertPosition(self, _key, prevId, nextId)) {
            // Sender's hint was not a valid insert position
            // Use sender's hint to find a valid insert position
            (prevId, nextId) = findInsertPosition(self, _key, prevId, nextId);
        }

        self.nodes[_id].key = _key;

        if (prevId == address(0) && nextId == address(0)) {
            // Insert as head and tail
            self.head = _id;
            self.tail = _id;
        } else if (prevId == address(0)) {
            // Insert before `prevId` as the head
            self.nodes[_id].nextId = self.head;
            self.nodes[self.head].prevId = _id;
            self.head = _id;
        } else if (nextId == address(0)) {
            // Insert after `nextId` as the tail
            self.nodes[_id].prevId = self.tail;
            self.nodes[self.tail].nextId = _id;
            self.tail = _id;
        } else {
            // Insert at insert position between `prevId` and `nextId`
            self.nodes[_id].nextId = nextId;
            self.nodes[_id].prevId = prevId;
            self.nodes[prevId].nextId = _id;
            self.nodes[nextId].prevId = _id;
        }

        self.size = self.size.add(1);
    }

    /*
     * @dev Remove a node from the list
     * @param _id Node's id
     */
    function remove(Data storage self, address _id) public {
        // List must contain the node
        require(contains(self, _id));

        if (self.size > 1) {
            // List contains more than a single node
            if (_id == self.head) {
                // The removed node is the head
                // Set head to next node
                self.head = self.nodes[_id].nextId;
                // Set prev pointer of new head to null
                self.nodes[self.head].prevId = address(0);
            } else if (_id == self.tail) {
                // The removed node is the tail
                // Set tail to previous node
                self.tail = self.nodes[_id].prevId;
                // Set next pointer of new tail to null
                self.nodes[self.tail].nextId = address(0);
            } else {
                // The removed node is neither the head nor the tail
                // Set next pointer of previous node to the next node
                self.nodes[self.nodes[_id].prevId].nextId = self.nodes[_id].nextId;
                // Set prev pointer of next node to the previous node
                self.nodes[self.nodes[_id].nextId].prevId = self.nodes[_id].prevId;
            }
        } else {
            // List contains a single node
            // Set the head and tail to null
            self.head = address(0);
            self.tail = address(0);
        }

        delete self.nodes[_id];
        self.size = self.size.sub(1);
    }

    /*
     * @dev Update the key of a node in the list
     * @param _id Node's id
     * @param _newKey Node's new key
     * @param _prevId Id of previous node for the new insert position
     * @param _nextId Id of next node for the new insert position
     */
    function updateKey(Data storage self, address _id, uint256 _newKey, address _prevId, address _nextId) public {
        // List must contain the node
        require(contains(self, _id));

        // Remove node from the list
        remove(self, _id);

        if (_newKey > 0) {
            // Insert node if it has a non-zero key
            insert(self, _id, _newKey, _prevId, _nextId);
        }
    }

    /*
     * @dev Checks if the list contains a node
     * @param _transcoder Address of transcoder
     */
    function contains(Data storage self, address _id) public view returns (bool) {
        // List only contains non-zero keys, so if key is non-zero the node exists
        return self.nodes[_id].key > 0;
    }

    /*
     * @dev Checks if the list is full
     */
    function isFull(Data storage self) public view returns (bool) {
        return self.size == self.maxSize;
    }

    /*
     * @dev Checks if the list is empty
     */
    function isEmpty(Data storage self) public view returns (bool) {
        return self.size == 0;
    }

    /*
     * @dev Returns the current size of the list
     */
    function getSize(Data storage self) public view returns (uint256) {
        return self.size;
    }

    /*
     * @dev Returns the maximum size of the list
     */
    function getMaxSize(Data storage self) public view returns (uint256) {
        return self.maxSize;
    }

    /*
     * @dev Returns the key of a node in the list
     * @param _id Node's id
     */
    function getKey(Data storage self, address _id) public view returns (uint256) {
        return self.nodes[_id].key;
    }

    /*
     * @dev Returns the first node in the list (node with the largest key)
     */
    function getFirst(Data storage self) public view returns (address) {
        return self.head;
    }

    /*
     * @dev Returns the last node in the list (node with the smallest key)
     */
    function getLast(Data storage self) public view returns (address) {
        return self.tail;
    }

    /*
     * @dev Returns the next node (with a smaller key) in the list for a given node
     * @param _id Node's id
     */
    function getNext(Data storage self, address _id) public view returns (address) {
        return self.nodes[_id].nextId;
    }

    /*
     * @dev Returns the previous node (with a larger key) in the list for a given node
     * @param _id Node's id
     */
    function getPrev(Data storage self, address _id) public view returns (address) {
        return self.nodes[_id].prevId;
    }

    /*
     * @dev Check if a pair of nodes is a valid insertion point for a new node with the given key
     * @param _key Node's key
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function validInsertPosition(Data storage self, uint256 _key, address _prevId, address _nextId) public view returns (bool) {
        if (_prevId == address(0) && _nextId == address(0)) {
            // `(null, null)` is a valid insert position if the list is empty
            return isEmpty(self);
        } else if (_prevId == address(0)) {
            // `(null, _nextId)` is a valid insert position if `_nextId` is the head of the list
            return self.head == _nextId && _key >= self.nodes[_nextId].key;
        } else if (_nextId == address(0)) {
            // `(_prevId, null)` is a valid insert position if `_prevId` is the tail of the list
            return self.tail == _prevId && _key <= self.nodes[_prevId].key;
        } else {
            // `(_prevId, _nextId)` is a valid insert position if they are adjacent nodes and `_key` falls between the two nodes' keys
            return self.nodes[_prevId].nextId == _nextId && self.nodes[_prevId].key >= _key && _key >= self.nodes[_nextId].key;
        }
    }

    /*
     * @dev Descend the list (larger keys to smaller keys) to find a valid insert position
     * @param _key Node's key
     * @param _startId Id of node to start ascending the list from
     */
    function descendList(Data storage self, uint256 _key, address _startId) private view returns (address, address) {
        // If `_startId` is the head, check if the insert position is before the head
        if (self.head == _startId && _key >= self.nodes[_startId].key) {
            return (address(0), _startId);
        }

        address prevId = _startId;
        address nextId = self.nodes[prevId].nextId;

        // Descend the list until we reach the end or until we find a valid insert position
        while (prevId != address(0) && !validInsertPosition(self, _key, prevId, nextId)) {
            prevId = self.nodes[prevId].nextId;
            nextId = self.nodes[prevId].nextId;
        }

        return (prevId, nextId);
    }

    /*
     * @dev Ascend the list (smaller keys to larger keys) to find a valid insert position
     * @param _key Node's key
     * @param _startId Id of node to start descending the list from
     */
    function ascendList(Data storage self, uint256 _key, address _startId) private view returns (address, address) {
        // If `_startId` is the tail, check if the insert position is after the tail
        if (self.tail == _startId && _key <= self.nodes[_startId].key) {
            return (_startId, address(0));
        }

        address nextId = _startId;
        address prevId = self.nodes[nextId].prevId;

        // Ascend the list until we reach the end or until we find a valid insertion point
        while (nextId != address(0) && !validInsertPosition(self, _key, prevId, nextId)) {
            nextId = self.nodes[nextId].prevId;
            prevId = self.nodes[nextId].prevId;
        }

        return (prevId, nextId);
    }

    /*
     * @dev Find the insert position for a new node with the given key
     * @param _key Node's key
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function findInsertPosition(Data storage self, uint256 _key, address _prevId, address _nextId) private view returns (address, address) {
        address prevId = _prevId;
        address nextId = _nextId;

        if (prevId != address(0)) {
            if (!contains(self, prevId) || _key > self.nodes[prevId].key) {
                // `prevId` does not exist anymore or now has a smaller key than the given key
                prevId = address(0);
            }
        }

        if (nextId != address(0)) {
            if (!contains(self, nextId) || _key < self.nodes[nextId].key) {
                // `nextId` does not exist anymore or now has a larger key than the given key
                nextId = address(0);
            }
        }

        if (prevId == address(0) && nextId == address(0)) {
            // No hint - descend list starting from head
            return descendList(self, _key, self.head);
        } else if (prevId == address(0)) {
            // No `prevId` for hint - ascend list starting from `nextId`
            return ascendList(self, _key, nextId);
        } else if (nextId == address(0)) {
            // No `nextId` for hint - descend list starting from `prevId`
            return descendList(self, _key, prevId);
        } else {
            // Descend list starting from `prevId`
            return descendList(self, _key, prevId);
        }
    }
}

// File: contracts/libraries/MathUtils.sol

library MathUtils {
    using SafeMath for uint256;

    // Divisor used for representing percentages
    uint256 public constant PERC_DIVISOR = 1000000;

    /*
     * @dev Returns whether an amount is a valid percentage out of PERC_DIVISOR
     * @param _amount Amount that is supposed to be a percentage
     */
    function validPerc(uint256 _amount) internal pure returns (bool) {
        return _amount <= PERC_DIVISOR;
    }

    /*
     * @dev Compute percentage of a value with the percentage represented by a fraction
     * @param _amount Amount to take the percentage of
     * @param _fracNum Numerator of fraction representing the percentage
     * @param _fracDenom Denominator of fraction representing the percentage
     */
    function percOf(uint256 _amount, uint256 _fracNum, uint256 _fracDenom) internal pure returns (uint256) {
        return _amount.mul(percPoints(_fracNum, _fracDenom)).div(PERC_DIVISOR);
    }

    /*
     * @dev Compute percentage of a value with the percentage represented by a fraction over PERC_DIVISOR
     * @param _amount Amount to take the percentage of
     * @param _fracNum Numerator of fraction representing the percentage with PERC_DIVISOR as the denominator
     */
    function percOf(uint256 _amount, uint256 _fracNum) internal pure returns (uint256) {
        return _amount.mul(_fracNum).div(PERC_DIVISOR);
    }

    /*
     * @dev Compute percentage representation of a fraction
     * @param _fracNum Numerator of fraction represeting the percentage
     * @param _fracDenom Denominator of fraction represeting the percentage
     */
    function percPoints(uint256 _fracNum, uint256 _fracDenom) internal pure returns (uint256) {
        return _fracNum.mul(PERC_DIVISOR).div(_fracDenom);
    }
}

// File: contracts/staking/libraries/EarningsPool.sol

/**
 * @title EarningsPool
 * @dev Manages reward and fee pools for delegators and transcoders
 */
library EarningsPool {
    using SafeMath for uint256;

    // Represents rewards and fees to be distributed to delegators
    // The `hasTranscoderRewardFeePool` flag was introduced so that EarningsPool.Data structs used by the BondingManager
    // created with older versions of this library can be differentiated from EarningsPool.Data structs used by the BondingManager
    // created with a newer version of this library. If the flag is true, then the struct was initialized using the `init` function
    // using a newer version of this library meaning that it is using separate transcoder reward and fee pools
    struct Data {
        uint256 rewardPool;                // Delegator rewards. If `hasTranscoderRewardFeePool` is false, this will contain transcoder rewards as well
        uint256 feePool;                   // Delegator fees. If `hasTranscoderRewardFeePool` is false, this will contain transcoder fees as well
        uint256 totalStake;                // Transcoder's total stake during the earnings pool's round
        uint256 claimableStake;            // Stake that can be used to claim portions of the fee and reward pools
        uint256 transcoderRewardCut;       // Transcoder's reward cut during the earnings pool's round
        uint256 transcoderFeeShare;        // Transcoder's fee share during the earnings pool's round
        uint256 transcoderRewardPool;      // Transcoder rewards. If `hasTranscoderRewardFeePool` is false, this should always be 0
        uint256 transcoderFeePool;         // Transcoder fees. If `hasTranscoderRewardFeePool` is false, this should always be 0
        bool hasTranscoderRewardFeePool;   // Flag to indicate if the earnings pool has separate transcoder reward and fee pools
    }

    /**
     * @dev Initialize a EarningsPool struct
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Total stake of the transcoder during the earnings pool's round
     * @param _rewardCut Reward cut of transcoder during the earnings pool's round
     * @param _feeShare Fee share of transcoder during the earnings pool's round
     */
    function init(EarningsPool.Data storage earningsPool, uint256 _stake, uint256 _rewardCut, uint256 _feeShare) internal {
        earningsPool.totalStake = _stake;
        earningsPool.claimableStake = _stake;
        earningsPool.transcoderRewardCut = _rewardCut;
        earningsPool.transcoderFeeShare = _feeShare;
        // We set this flag to true here to differentiate between EarningsPool structs created using older versions of this library.
        // When using a version of this library after the introduction of this flag to read an EarningsPool struct created using an older version
        // of this library, this flag should be false in the returned struct because the default value for EVM storage is 0
        earningsPool.hasTranscoderRewardFeePool = true;
    }

    /**
     * @dev Return whether this earnings pool has claimable shares i.e. is there unclaimed stake
     * @param earningsPool Storage pointer to EarningsPool struct
     */
    function hasClaimableShares(EarningsPool.Data storage earningsPool) internal view returns (bool) {
        return earningsPool.claimableStake > 0;
    }

    /**
     * @dev Add fees to the earnings pool
     * @param earningsPool Storage pointer to EarningsPools struct
     * @param _fees Amount of fees to add
     */
    function addToFeePool(EarningsPool.Data storage earningsPool, uint256 _fees) internal {
        if (earningsPool.hasTranscoderRewardFeePool) {
            // If the earnings pool has a separate transcoder fee pool, calculate the portion of incoming fees
            // to put into the delegator fee pool and the portion to put into the transcoder fee pool
            uint256 delegatorFees = MathUtils.percOf(_fees, earningsPool.transcoderFeeShare);
            earningsPool.feePool = earningsPool.feePool.add(delegatorFees);
            earningsPool.transcoderFeePool = earningsPool.transcoderFeePool.add(_fees.sub(delegatorFees));
        } else {
            // If the earnings pool does not have a separate transcoder fee pool, put all the fees into the delegator fee pool
            earningsPool.feePool = earningsPool.feePool.add(_fees);
        }
    }

    /**
     * @dev Add rewards to the earnings pool
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _rewards Amount of rewards to add
     */
    function addToRewardPool(EarningsPool.Data storage earningsPool, uint256 _rewards) internal {
        if (earningsPool.hasTranscoderRewardFeePool) {
            // If the earnings pool has a separate transcoder reward pool, calculate the portion of incoming rewards
            // to put into the delegator reward pool and the portion to put into the transcoder reward pool
            uint256 transcoderRewards = MathUtils.percOf(_rewards, earningsPool.transcoderRewardCut);
            earningsPool.rewardPool = earningsPool.rewardPool.add(_rewards.sub(transcoderRewards));
            earningsPool.transcoderRewardPool = earningsPool.transcoderRewardPool.add(transcoderRewards);
        } else {
            // If the earnings pool does not have a separate transcoder reward pool, put all the rewards into the delegator reward pool
            earningsPool.rewardPool = earningsPool.rewardPool.add(_rewards);
        }
    }

    /**
     * @dev Claim reward and fee shares which decreases the reward/fee pools and the remaining claimable stake
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Stake of claimant
     * @param _isTranscoder Flag indicating whether the claimant is a transcoder
     */
    function claimShare(EarningsPool.Data storage earningsPool, uint256 _stake, bool _isTranscoder) internal returns (uint256, uint256) {
        uint256 totalFees = 0;
        uint256 totalRewards = 0;
        uint256 delegatorFees = 0;
        uint256 transcoderFees = 0;
        uint256 delegatorRewards = 0;
        uint256 transcoderRewards = 0;

        if (earningsPool.hasTranscoderRewardFeePool) {
            // EarningsPool has transcoder reward and fee pools
            // Compute fee share
            (delegatorFees, transcoderFees) = feePoolShareWithTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
            totalFees = delegatorFees.add(transcoderFees);
            // Compute reward share
            (delegatorRewards, transcoderRewards) = rewardPoolShareWithTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
            totalRewards = delegatorRewards.add(transcoderRewards);

            // Fee pool only holds delegator fees when `hasTranscoderRewardFeePool` is true - deduct delegator fees
            earningsPool.feePool = earningsPool.feePool.sub(delegatorFees);
            // Reward pool only holds delegator rewards when `hasTranscoderRewardFeePool` is true - deduct delegator rewards
            earningsPool.rewardPool = earningsPool.rewardPool.sub(delegatorRewards);

            if (_isTranscoder) {
                // Claiming as a transcoder
                // Clear transcoder fee pool
                earningsPool.transcoderFeePool = 0;
                // Clear transcoder reward pool
                earningsPool.transcoderRewardPool = 0;
            }
        } else {
            // EarningsPool does not have transcoder reward and fee pools
            // Compute fee share
            (delegatorFees, transcoderFees) = feePoolShareNoTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
            totalFees = delegatorFees.add(transcoderFees);
            // Compute reward share
            (delegatorRewards, transcoderRewards) = rewardPoolShareNoTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
            totalRewards = delegatorRewards.add(transcoderRewards);

            // Fee pool holds delegator and transcoder fees when `hasTranscoderRewardFeePool` is false - deduct delegator and transcoder fees
            earningsPool.feePool = earningsPool.feePool.sub(totalFees);
            // Reward pool holds delegator and transcoder fees when `hasTranscoderRewardFeePool` is false - deduct delegator and transcoder fees
            earningsPool.rewardPool = earningsPool.rewardPool.sub(totalRewards);
        }

        // Update remaining claimable stake
        earningsPool.claimableStake = earningsPool.claimableStake.sub(_stake);

        return (totalFees, totalRewards);
    }

    /**
     * @dev Returns the fee pool share for a claimant. If the claimant is a transcoder, include transcoder fees as well.
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Stake of claimant
     * @param _isTranscoder Flag indicating whether the claimant is a transcoder
     */
    function feePoolShare(EarningsPool.Data storage earningsPool, uint256 _stake, bool _isTranscoder) internal view returns (uint256) {
        uint256 delegatorFees = 0;
        uint256 transcoderFees = 0;

        if (earningsPool.hasTranscoderRewardFeePool) {
            (delegatorFees, transcoderFees) = feePoolShareWithTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
        } else {
            (delegatorFees, transcoderFees) = feePoolShareNoTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
        }

        return delegatorFees.add(transcoderFees);
    }

    /**
     * @dev Returns the reward pool share for a claimant. If the claimant is a transcoder, include transcoder rewards as well.
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Stake of claimant
     * @param _isTranscoder Flag indicating whether the claimant is a transcoder
     */
    function rewardPoolShare(EarningsPool.Data storage earningsPool, uint256 _stake, bool _isTranscoder) internal view returns (uint256) {
        uint256 delegatorRewards = 0;
        uint256 transcoderRewards = 0;

        if (earningsPool.hasTranscoderRewardFeePool) {
            (delegatorRewards, transcoderRewards) = rewardPoolShareWithTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
        } else {
            (delegatorRewards, transcoderRewards) = rewardPoolShareNoTranscoderRewardFeePool(earningsPool, _stake, _isTranscoder);
        }

        return delegatorRewards.add(transcoderRewards);
    }

    /**
     * @dev Helper function to calculate fee pool share if the earnings pool has a separate transcoder fee pool
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Stake of claimant
     * @param _isTranscoder Flag indicating whether the claimant is a transcoder
     */
    function feePoolShareWithTranscoderRewardFeePool(
        EarningsPool.Data storage earningsPool,
        uint256 _stake,
        bool _isTranscoder
    )
        internal
        view
        returns (uint256, uint256)
    {
        // If there is no claimable stake, the fee pool share is 0
        // If there is claimable stake, calculate fee pool share based on remaining amount in fee pool, remaining claimable stake and claimant's stake
        uint256 delegatorFees = earningsPool.claimableStake > 0 ? MathUtils.percOf(earningsPool.feePool, _stake, earningsPool.claimableStake) : 0;

        // If claimant is a transcoder, include transcoder fee pool as well
        return _isTranscoder ? (delegatorFees, earningsPool.transcoderFeePool) : (delegatorFees, 0);
    }

    /**
     * @dev Helper function to calculate reward pool share if the earnings pool has a separate transcoder reward pool
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Stake of claimant
     * @param _isTranscoder Flag indicating whether the claimant is a transcoder
     */
    function rewardPoolShareWithTranscoderRewardFeePool(
        EarningsPool.Data storage earningsPool,
        uint256 _stake,
        bool _isTranscoder
    )
        internal
        view
        returns (uint256, uint256)
    {
        // If there is no claimable stake, the reward pool share is 0
        // If there is claimable stake, calculate reward pool share based on remaining amount in reward pool, remaining claimable stake and claimant's stake
        uint256 delegatorRewards = earningsPool.claimableStake > 0 ? MathUtils.percOf(earningsPool.rewardPool, _stake, earningsPool.claimableStake) : 0;

        // If claimant is a transcoder, include transcoder reward pool as well
        return _isTranscoder ? (delegatorRewards, earningsPool.transcoderRewardPool) : (delegatorRewards, 0);
    }

    /**
     * @dev Helper function to calculate the fee pool share if the earnings pool does not have a separate transcoder fee pool
     * This implements calculation logic from a previous version of this library
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Stake of claimant
     * @param _isTranscoder Flag indicating whether the claimant is a transcoder
     */
    function feePoolShareNoTranscoderRewardFeePool(
        EarningsPool.Data storage earningsPool,
        uint256 _stake,
        bool _isTranscoder
    )
        internal
        view
        returns (uint256, uint256)
    {
        uint256 transcoderFees = 0;
        uint256 delegatorFees = 0;

        if (earningsPool.claimableStake > 0) {
            uint256 delegatorsFees = MathUtils.percOf(earningsPool.feePool, earningsPool.transcoderFeeShare);
            transcoderFees = earningsPool.feePool.sub(delegatorsFees);
            delegatorFees = MathUtils.percOf(delegatorsFees, _stake, earningsPool.claimableStake);
        }

        if (_isTranscoder) {
            return (delegatorFees, transcoderFees);
        } else {
            return (delegatorFees, 0);
        }
    }

    /**
     * @dev Helper function to calculate the reward pool share if the earnings pool does not have a separate transcoder reward pool
     * This implements calculation logic from a previous version of this library
     * @param earningsPool Storage pointer to EarningsPool struct
     * @param _stake Stake of claimant
     * @param _isTranscoder Flag indicating whether the claimant is a transcoder
     */
    function rewardPoolShareNoTranscoderRewardFeePool(
        EarningsPool.Data storage earningsPool,
        uint256 _stake,
        bool _isTranscoder
    )
        internal
        view
        returns (uint256, uint256)
    {
        uint256 transcoderRewards = 0;
        uint256 delegatorRewards = 0;

        if (earningsPool.claimableStake > 0) {
            transcoderRewards = MathUtils.percOf(earningsPool.rewardPool, earningsPool.transcoderRewardCut);
            delegatorRewards = MathUtils.percOf(earningsPool.rewardPool.sub(transcoderRewards), _stake, earningsPool.claimableStake);
        }

        if (_isTranscoder) {
            return (delegatorRewards, transcoderRewards);
        } else {
            return (delegatorRewards, 0);
        }
    }
}

// File: openzeppelin-solidity/contracts/token/ERC20/IERC20.sol

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
  function totalSupply() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender)
    external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  function approve(address spender, uint256 value)
    external returns (bool);

  function transferFrom(address from, address to, uint256 value)
    external returns (bool);

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}

// File: openzeppelin-solidity/contracts/token/ERC20/ERC20.sol

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 * Originally based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract ERC20 is IERC20 {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowed;

  uint256 private _totalSupply;

  /**
  * @dev Total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address owner) public view returns (uint256) {
    return _balances[owner];
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param owner address The address which owns the funds.
   * @param spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(
    address owner,
    address spender
   )
    public
    view
    returns (uint256)
  {
    return _allowed[owner][spender];
  }

  /**
  * @dev Transfer token for a specified address
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  */
  function transfer(address to, uint256 value) public returns (bool) {
    require(value <= _balances[msg.sender]);
    require(to != address(0));

    _balances[msg.sender] = _balances[msg.sender].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
  function approve(address spender, uint256 value) public returns (bool) {
    require(spender != address(0));

    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param from address The address which you want to send tokens from
   * @param to address The address which you want to transfer to
   * @param value uint256 the amount of tokens to be transferred
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  )
    public
    returns (bool)
  {
    require(value <= _balances[from]);
    require(value <= _allowed[from][msg.sender]);
    require(to != address(0));

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
    emit Transfer(from, to, value);
    return true;
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   * approve should be called when allowed_[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param spender The address which will spend the funds.
   * @param addedValue The amount of tokens to increase the allowance by.
   */
  function increaseAllowance(
    address spender,
    uint256 addedValue
  )
    public
    returns (bool)
  {
    require(spender != address(0));

    _allowed[msg.sender][spender] = (
      _allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   * approve should be called when allowed_[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param spender The address which will spend the funds.
   * @param subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseAllowance(
    address spender,
    uint256 subtractedValue
  )
    public
    returns (bool)
  {
    require(spender != address(0));

    _allowed[msg.sender][spender] = (
      _allowed[msg.sender][spender].sub(subtractedValue));
    emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
    return true;
  }

  /**
   * @dev Internal function that mints an amount of the token and assigns it to
   * an account. This encapsulates the modification of balances such that the
   * proper events are emitted.
   * @param account The account that will receive the created tokens.
   * @param amount The amount that will be created.
   */
  function _mint(address account, uint256 amount) internal {
    require(account != 0);
    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account.
   * @param account The account whose tokens will be burnt.
   * @param amount The amount that will be burnt.
   */
  function _burn(address account, uint256 amount) internal {
    require(account != 0);
    require(amount <= _balances[account]);

    _totalSupply = _totalSupply.sub(amount);
    _balances[account] = _balances[account].sub(amount);
    emit Transfer(account, address(0), amount);
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account, deducting from the sender's allowance for said account. Uses the
   * internal burn function.
   * @param account The account whose tokens will be burnt.
   * @param amount The amount that will be burnt.
   */
  function _burnFrom(address account, uint256 amount) internal {
    require(amount <= _allowed[account][msg.sender]);

    // Should https://github.com/OpenZeppelin/zeppelin-solidity/issues/707 be accepted,
    // this function needs to emit an event with the updated approval.
    _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(
      amount);
    _burn(account, amount);
  }
}

// File: openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol

/**
 * @title ERC20Detailed token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
contract ERC20Detailed is IERC20 {
  string private _name;
  string private _symbol;
  uint8 private _decimals;

  constructor(string name, string symbol, uint8 decimals) public {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
  }

  /**
   * @return the name of the token.
   */
  function name() public view returns(string) {
    return _name;
  }

  /**
   * @return the symbol of the token.
   */
  function symbol() public view returns(string) {
    return _symbol;
  }

  /**
   * @return the number of decimals of the token.
   */
  function decimals() public view returns(uint8) {
    return _decimals;
  }
}

// File: openzeppelin-solidity/contracts/access/roles/MinterRole.sol

contract MinterRole {
  using Roles for Roles.Role;

  event MinterAdded(address indexed account);
  event MinterRemoved(address indexed account);

  Roles.Role private minters;

  constructor() public {
    minters.add(msg.sender);
  }

  modifier onlyMinter() {
    require(isMinter(msg.sender));
    _;
  }

  function isMinter(address account) public view returns (bool) {
    return minters.has(account);
  }

  function addMinter(address account) public onlyMinter {
    minters.add(account);
    emit MinterAdded(account);
  }

  function renounceMinter() public {
    minters.remove(msg.sender);
  }

  function _removeMinter(address account) internal {
    minters.remove(account);
    emit MinterRemoved(account);
  }
}

// File: openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol

/**
 * @title ERC20Mintable
 * @dev ERC20 minting logic
 */
contract ERC20Mintable is ERC20, MinterRole {
  event MintingFinished();

  bool private _mintingFinished = false;

  modifier onlyBeforeMintingFinished() {
    require(!_mintingFinished);
    _;
  }

  /**
   * @return true if the minting is finished.
   */
  function mintingFinished() public view returns(bool) {
    return _mintingFinished;
  }

  /**
   * @dev Function to mint tokens
   * @param to The address that will receive the minted tokens.
   * @param amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(
    address to,
    uint256 amount
  )
    public
    onlyMinter
    onlyBeforeMintingFinished
    returns (bool)
  {
    _mint(to, amount);
    return true;
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting()
    public
    onlyMinter
    onlyBeforeMintingFinished
    returns (bool)
  {
    _mintingFinished = true;
    emit MintingFinished();
    return true;
  }
}

// File: openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract ERC20Burnable is ERC20 {

  /**
   * @dev Burns a specific amount of tokens.
   * @param value The amount of token to be burned.
   */
  function burn(uint256 value) public {
    _burn(msg.sender, value);
  }

  /**
   * @dev Burns a specific amount of tokens from the target address and decrements allowance
   * @param from address The address which you want to send tokens from
   * @param value uint256 The amount of token to be burned
   */
  function burnFrom(address from, uint256 value) public {
    _burnFrom(from, value);
  }

  /**
   * @dev Overrides ERC20._burn in order for burn and burnFrom to emit
   * an additional Burn event.
   */
  function _burn(address who, uint256 value) internal {
    super._burn(who, value);
  }
}

// File: contracts/token/IMagicToken.sol

contract IMagicToken is ERC20, Ownable, ERC20Detailed, ERC20Mintable, ERC20Burnable {}

// File: contracts/minter/IMinter.sol

/**
 * @title Minter interface
 */
contract IMinter {
    // Events
    event SetCurrentRewardTokens(uint256 currentMintableTokens, uint256 currentInflation);

    // External functions
    function createReward(uint256 _fracNum, uint256 _fracDenom) external returns (uint256);
    function trustedTransferTokens(address _to, uint256 _amount) external;
    function trustedBurnTokens(uint256 _amount) external;
    function trustedWithdrawETH(address _to, uint256 _amount) external;
    function depositETH() external payable returns (bool);
    function setCurrentRewardTokens() external;

    // Public functions
    function getController() public view returns (IController);
}

// File: contracts/rounds/IRoundsManager.sol

/**
 * @title RoundsManager interface
 */
contract IRoundsManager {
    // Events
    event NewRound(uint256 round);

    // External functions
    function initializeRound() external;

    // Public functions
    function blockNum() public view returns (uint256);
    function blockHash(uint256 _block) public view returns (bytes32);
    function currentRound() public view returns (uint256);
    function currentRoundStartBlock() public view returns (uint256);
    function currentRoundInitialized() public view returns (bool);
    function currentRoundLocked() public view returns (bool);
}

// File: openzeppelin-solidity/contracts/math/Math.sol

/**
 * @title Math
 * @dev Assorted math operations
 */
library Math {
  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a : b;
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function average(uint256 a, uint256 b) internal pure returns (uint256) {
    // (a + b) / 2 can overflow, so we distribute
    return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
  }
}

// File: contracts/staking/StakingManager.sol

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
