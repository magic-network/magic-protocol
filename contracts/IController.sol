pragma solidity ^0.4.4;

import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract IController is Pausable, Ownable {
    event SetContractInfo(string id, address contractAddress, string gitCommitHash);

    function setContractInfo(string _id, address _contractAddress, string _gitCommitHash) external;
    function updateController(string _id, address _controller) external;
    function getContract(string _id) public view returns (address);
}
