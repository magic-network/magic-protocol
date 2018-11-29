pragma solidity ^0.4.4;

import "./ManagerProxyTarget.sol";


/**
 * @title ManagerProxy
 * @dev A proxy contract that uses delegatecall to execute function calls on a target contract using its own storage context.
 * The target contract is a Manager contract that is registered with the Controller.
 * Note: Both this proxy contract and its target contract MUST inherit from ManagerProxyTarget in order to guarantee
 * that both contracts have the same storage layout. Differing storage layouts in a proxy contract and target contract can
 * potentially break the delegate proxy upgradeability mechanism
 */
contract ManagerProxy is ManagerProxyTarget {
    /**
     * @dev ManagerProxy constructor. Invokes constructor of base Manager contract with provided Controller address.
     * Also, sets the contract ID of the target contract that function calls will be executed on.
     * @param _controller Address of Controller that this contract will be registered with
     * @param _targetContractId contract ID of the target contract
     */
    constructor (address _controller, string _targetContractId) public Manager(_controller) {
        targetContractId = _targetContractId;
    }

    /**
     * @dev Uses delegatecall to execute function calls on this proxy contract's target contract using its own storage context.
     * This fallback function will look up the address of the target contract using the Controller and the target contract ID.
     * It will then use the calldata for a function call as the data payload for a delegatecall on the target contract. The return value
     * of the executed function call will also be returned
     */
    function() public payable {
        address target = controller.getContract(targetContractId);
        // Target contract must be registered
        require(target > 0);

        assembly {
            // Solidity keeps a free memory pointer at position 0x40 in memory
            let freeMemoryPtrPosition := 0x40
            // Load the free memory pointer
            let calldataMemoryOffset := mload(freeMemoryPtrPosition)
            // Update free memory pointer to after memory space we reserve for calldata
            mstore(freeMemoryPtrPosition, add(calldataMemoryOffset, calldatasize))
            // Copy calldata (method signature and params of the call) to memory
            calldatacopy(calldataMemoryOffset, 0x0, calldatasize)

            // Call method on target contract using calldata which is loaded into memory
            let ret := delegatecall(gas, target, calldataMemoryOffset, calldatasize, 0, 0)

            // Load the free memory pointer
            let returndataMemoryOffset := mload(freeMemoryPtrPosition)
            // Update free memory pointer to after memory space we reserve for returndata
            mstore(freeMemoryPtrPosition, add(returndataMemoryOffset, returndatasize))
            // Copy returndata (result of the method invoked by the delegatecall) to memory
            returndatacopy(returndataMemoryOffset, 0x0, returndatasize)

            switch ret
            case 0 {
                // Method call failed - revert
                // Return any error message stored in mem[returndataMemoryOffset..(returndataMemoryOffset + returndatasize)]
                revert(returndataMemoryOffset, returndatasize)
            } default {
                // Return result of method call stored in mem[returndataMemoryOffset..(returndataMemoryOffset + returndatasize)]
                return(returndataMemoryOffset, returndatasize)
            }
        }
    }
}
