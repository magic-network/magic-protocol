pragma solidity ^0.4.4;

import "./IMagicToken.sol";

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

// Basic Connectivity Token
contract MagicToken is ERC20, ERC20Detailed, ERC20Mintable, ERC20Burnable, Ownable {
    constructor()
    ERC20Detailed("Magic Token", "MGC", 18)
    Ownable()
    public {}
}
