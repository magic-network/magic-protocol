#!/bin/bash

node ./node_modules/truffle-flattener/index.js ./contracts/Controller.sol > ./remix/Controller.sol
node ./node_modules/truffle-flattener/index.js ./contracts/token/MagicToken.sol > ./remix/MagicToken.sol
node ./node_modules/truffle-flattener/index.js ./contracts/token/MagicTokenFaucet.sol > ./remix/MagicTokenFaucet.sol
node ./node_modules/truffle-flattener/index.js ./contracts/minter/Minter.sol > ./remix/Minter.sol
node ./node_modules/truffle-flattener/index.js ./contracts/staking/StakingManager.sol > ./remix/StakingManager.sol
node ./node_modules/truffle-flattener/index.js ./contracts/rounds/RoundsManager.sol > ./remix/RoundsManager.sol

echo "Successfully Flattened. Output found in directory: ./remix"



