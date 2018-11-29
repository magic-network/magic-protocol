const glob = require("glob")

const previousFiles = glob.sync("contracts/previous/**/*.sol").map(file => file.replace("contracts/", ""))
const testFiles = glob.sync("contracts/test/*.sol").map(file => file.replace("contracts/", ""))
const interfaces = [
    "IController.sol",
    "IManager.sol",
    "rounds/IRoundsManager.sol",
    "token/IMagicToken.sol",
    "token/IMinter.sol"
]

module.exports = {
    norpc: true,
    testCommand: "node --max-old-space-size=4096 ../node_modules/.bin/truffle test test/unit/* --network coverage",
    compileCommand: "node --max-old-space-size=4096 ../node_modules/.bin/truffle compile --network coverage",
    copyPackages: ["zeppelin-solidity"],
    skipFiles: previousFiles.concat(testFiles).concat(mockFiles).concat(interfaces)
}
