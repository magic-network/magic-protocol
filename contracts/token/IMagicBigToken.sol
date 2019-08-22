pragma solidity ^0.4.4;


import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract IMagicBigToken is ERC20, Ownable, ERC20Detailed {}
