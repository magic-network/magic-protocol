pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/IERC20.sol';

contract MagicChannels {

    IERC20 public token;
    address public owner_addr;
    mapping (address => Enabler) enablers;

    struct Enabler {
        bool registered;
        mapping (address => Channel) channels;
    }

    struct Channel {
        uint256 balance;
        uint32 open_block_number;
    }

    event ChannelCreated(
        address indexed user,
        address indexed enabler,
        uint256 deposit);

    event ChannelToppedUp (
        address indexed user,
        address indexed enabler,
        uint256 topupAmount);

    event EnablerRegistered (
        address indexed enabler);

    event PaymentsDispensed (
        address indexed enabler,
        address[] gateways,
        uint256[] payouts,
        address[] payers,
        uint256[] payments);

    /// @notice Constructor for creating the MagicChannel contract.
    /// @param token_addr The address of the MagicCoin Token.
    constructor(address token_addr) public {

        require(token_addr != 0x0, "token_addr must be non-zero.");
        require(addressHasCode(token_addr), "token_addr must contain code.");
        token = IERC20(token_addr);

        // Check if the contract is indeed a token contract
        require(token.totalSupply() > 0, "token_addr must be a valid erc20 token with totalSupply");

        owner_addr = msg.sender;

    }

    /* ----------------------------------------------------------------------------------------- *
     *
     * User methods (called from an user entity):
     *
     * ----------------------------------------------------------------------------------------- */

    function myUserBalance(address enabler) public view returns(uint256) {
        return enablers[enabler].channels[msg.sender].balance;
    }

    /// @notice Creates/Opens a new enabler channel for the sender/user.
    /// Requires deposit amount to be approved/allowed by sender from the ERC20 token.
    /// @param enabler The address of the payment enabler.
    /// @param deposit The amount to deposit. Must be less than the allowance.
    function createChannel(address enabler, uint256 deposit) external {

        require(deposit > 0, "Deposit must be greater than 0.") ;
        require(enablers[enabler].registered, "Enabler is not registered.");
        require(enablers[enabler].channels[msg.sender].open_block_number == 0, "Channel is already created.");

        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance > 0, "You have not allowed the payment channel to transfer tokens to it.");
        require(deposit <= allowance, "Token transfer allowance is not sufficient for this transfer.");

        uint32 open_block_number = uint32(block.number);

        enablers[enabler].channels[msg.sender] = Channel({balance: deposit, open_block_number: open_block_number});
        require(token.transferFrom(msg.sender, address(this), deposit));

        emit ChannelCreated(msg.sender, enabler, deposit);

    }

    /// @notice Adds balance to a users existing payment channel.
    /// Requires deposit amount to be approved/allowed by sender from the ERC20 token.
    /// @param enabler The address of the payment enabler.
    /// @param topupAmount The amount to add to the users balance. Must be less than the current ERC20 allowance.
    function topUp(address enabler, uint256 topupAmount) external {

        require(topupAmount > 0, "topupAmount must be greater than 0.") ;
        require(enablers[enabler].registered, "Enabler is not registered.");
        require(enablers[enabler].channels[msg.sender].open_block_number != 0, "Channel isn't created yet.");

        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance > 0, "You have not allowed the payment channel to transfer tokens to it.");
        require(topupAmount <= allowance, "Token transfer allowance is not sufficient for this transfer.");

        enablers[enabler].channels[msg.sender].balance += topupAmount;
        require(token.transferFrom(msg.sender, address(this), topupAmount));

        emit ChannelToppedUp(msg.sender, enabler, topupAmount);

    }

    /* ----------------------------------------------------------------------------------------- *
     *
     * Enabler methods (called from an enabler entity):
     *
     * ----------------------------------------------------------------------------------------- */


    modifier isRegisteredEnabler() {
        require(enablers[msg.sender].registered, "Only registered enablers can utilize this method.");
        _;
    }

    function registeredEnabler(address enabler) public view returns(bool) {
        return enablers[enabler].registered;
    }

    /// @notice Registers the sender as an enabler. Users can't open up channels unless enabler is registered.
    function registerEnabler() external {
        require(enablers[msg.sender].registered == false, "Enabler already registered.");
        enablers[msg.sender].registered = true;

        emit EnablerRegistered(msg.sender);

    }

    /// @notice Dispenses payment enabler state to the gateways and deducts the payments from the users balance.
    /// @param gateways The gateway addresses that provided service to the users.
    /// @param payouts The gateway earnings to be paid out.
    /// @param gateways The payers that received service from the gateways
    /// @param gateways The payments that the associated payer has made.
    function dispensePayments(
        address[] gateways,
        uint256[] payouts,
        address[] payers,
        uint256[] payments)
    isRegisteredEnabler
    external
    {

        require(gateways.length == payouts.length, "gateways & payouts must be an array of the same length.");
        require(payers.length == payments.length, "payers & payments must be an array of the same length.");

        uint256 totalPayments = 0;
        uint256 totalPayouts = 0;

        for (uint i = 0; i < payers.length; i++) {
            totalPayments += payments[i];

            enablers[msg.sender].channels[payers[i]].balance -= payments[i];
        }

        for (uint j = 0; j < gateways.length; j++) {
            totalPayouts += payouts[j];
        }

        require(totalPayments == totalPayouts, "Payouts and charges do not match");

        for (uint h = 0; h < gateways.length; h++) {
            require(token.transfer(gateways[h], payouts[h]));
        }

        emit PaymentsDispensed(msg.sender, gateways, payouts, payers, payments);

    }

    /* ----------------------------------------------------------------------------------------- *
     *
     * Basic Utility Methods
     *
     * ----------------------------------------------------------------------------------------- */

    function addressHasCode(address _contract) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(_contract)
        }

        return size > 0;
    }

}
