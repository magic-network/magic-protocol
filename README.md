All contributions and bug fixes are welcome as pull requests back into the repo.

# Magic Protocol

The Magic Protocol consists of the on-chain smart contracts that govern the logic of:

* Token Ownership
* Minting
* Participation & Inflation

The protocol will be outlined in the
[Magic Whitepaper](https://magic.co/waitlist/).

This protocol definition is currently a work in progress, and is subject to change.  

## Development

Built using [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-solidity) and [Truffle](http://truffle.readthedocs.io).
 
**Dependencies:**

1. Node v8.11.1+ - Use [NVM](https://github.com/creationix/nvm) if this is an issue.
2. [Ganache CLI](https://truffleframework.com/docs/ganache/quickstart)
3. (Optional) ```npm install -g truffle@4.1.14``` - This adds some cute things you can do on the command line, like `truffle console` etc. which lets you interface with the local EVM.

**Installation:**

This will deploy your contracts to a local EVM network called "development" (at http://localhost:8545)

1. Start Ganache:
```
ganache-cli -m "play ability never bench arrange reason flush order super spike father minimum"
```
2. Deploy contracts: (in separate terminal)
```
npm install
```

## Tests

You can build and test the Magic Protocol locally:

```
npm run test:unit
npm run test:integration
```
