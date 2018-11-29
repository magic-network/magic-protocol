const BigNumber = require("bignumber.js")

const TOKEN_UNIT = 10 ** 18

module.exports = {
    mgcFaucet: {
        requestAmount: new BigNumber(10).mul(TOKEN_UNIT),
        requestWait: 1,
        faucetSupply: new BigNumber(1000000).mul(TOKEN_UNIT),
        whitelist: [
            "0x140ade052968587ee3d9055d1f51d72004b81048"
        ]
    },
    roundsManager: {
        roundLength: 5760,
        roundLockAmount: 100000
    },
    stakingManager: {
        unbondingPeriod: 7
    },
    minter: {
        inflation: 137,
        inflationChange: 3,
        targetBondingRate: 500000
    }
};
