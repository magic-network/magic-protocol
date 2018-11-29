pragma solidity ^0.4.24;

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

// File: contracts/IManager.sol

contract IManager {
    event SetController(address controller);
    event ParameterUpdate(string param);

    function setController(address _controller) external;
}

// File: contracts/Controller.sol

contract Controller is Pausable, Ownable, IController {
    // Track information about a registered contract
    struct ContractInfo {
        address contractAddress;                 // Address of contract
        string gitCommitHash;                   // SHA1 hash of head Git commit during registration of this contract
    }

    // Track contract ids and contract info
    mapping (bytes32 => ContractInfo) private registry;

    constructor() public {}

    /*
     * @dev Register contract id and mapped address
     * @param _id Contract id (string of contract name)
     * @param _contract Contract address
     */
    function setContractInfo(string _id, address _contractAddress, string _gitCommitHash) external onlyOwner {

        bytes32 hashedId = bytes32(keccak256(abi.encodePacked(_id)));

        registry[hashedId].contractAddress = _contractAddress;
        registry[hashedId].gitCommitHash = _gitCommitHash;

        emit SetContractInfo(_id, _contractAddress, _gitCommitHash);

    }

    /*
     * @dev Update contract's controller
     * @param _id Contract id (string of contract name)
     * @param _controller Controller address
     */
    function updateController(string _id, address _controller) external onlyOwner {

        bytes32 hashedId = bytes32(keccak256(abi.encodePacked(_id)));

        return IManager(registry[hashedId].contractAddress).setController(_controller);
    }

    /*
     * @dev Return contract info for a given contract id
     * @param _id Contract id (string  of contract name)
     */
    function getContractInfo(string _id) public view returns (address, string) {

        bytes32 hashedId = bytes32(keccak256(abi.encodePacked(_id)));

        return (registry[hashedId].contractAddress, registry[hashedId].gitCommitHash);
    }

    /*
     * @dev Get contract address for an id
     * @param _id Contract id
     */
    function getContract(string _id) public view returns (address) {

        bytes32 hashedId = bytes32(keccak256(abi.encodePacked(_id)));

        return registry[hashedId].contractAddress;
    }
}
