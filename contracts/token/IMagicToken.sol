pragma solidity ^0.4.4;


import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract IMagicToken is ERC20, Ownable, ERC20Detailed, ERC20Mintable, ERC20Burnable {}
