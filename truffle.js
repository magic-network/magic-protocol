require("babel-register")
require("babel-polyfill")
require('dotenv').config()
const HDWalletProvider = require('truffle-hdwallet-provider')

let mochaConfig = {}

// Enable Mocha's --grep feature
for (let i = 0; i < process.argv.length; i++) {
    const arg = process.argv[i]
    if (arg !== "-g" &&  arg !== "--grep") continue
    if (++i >= process.argv.length) {
        console.error(arg + " option requires argument")
        process.exit(1)
    }

    const re = new RegExp(process.argv[i])
    mochaConfig.grep = new RegExp(process.argv[i])
    console.log("RegExp: " + i + ": " + re)
    break
}

module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 8545,
            network_id: "*", // Match any network id
            gas: 6700000
        },
        coverage: {
            host: "localhost",
            network_id: "*",
            port: 8555,
            gas: 0xffffffffff,
            gasPrice: 0x01
        },
        rinkeby: {
            provider: new HDWalletProvider(process.env.HDWALLET_MNEMONIC, `https://rinkeby.infura.io/${process.env.INFURA_APPKEY}`, 0, 1),
            network_id: 4,
            gas: 6600000
        }
    },
    solc: {
        optimizer: {
            enabled: true,
            runs: 200
        }
    },
    mocha: mochaConfig
}
