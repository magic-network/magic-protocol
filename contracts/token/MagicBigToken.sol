pragma solidity ^0.4.4;

import "./IMagicBigToken.sol";

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

// Big Token that collects inflation rewards for network use
contract MagicBigToken is ERC20, ERC20Detailed, Ownable {
    constructor()
    ERC20Detailed("Magic Big Token", "MBT", 18)
    Ownable()
    public {}
}
