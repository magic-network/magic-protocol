pragma solidity ^0.4.4;

import "./IController.sol";
import "./IManager.sol";

import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';


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
