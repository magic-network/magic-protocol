pragma solidity ^0.4.4;

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
