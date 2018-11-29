const BigNumber = require("bignumber.js")

const TOKEN_UNIT = 10 ** 18

module.exports = {
    initialSupply: new BigNumber(10000000).mul(TOKEN_UNIT),
    crowdSupply: new BigNumber(6343700).mul(TOKEN_UNIT),
    companySupply: new BigNumber(500000).mul(TOKEN_UNIT),
    teamSupply: new BigNumber(1235000).mul(TOKEN_UNIT),
    investorsSupply: new BigNumber(1900000).mul(TOKEN_UNIT),
    communitySupply: new BigNumber(21300).mul(TOKEN_UNIT),
    bankMultisig: "0x0000000000000000000000000000000000000000",
    governanceMultisig: "0x0000000000000000000000000000000000000000",
    timeToGrantsStart: new BigNumber(60).times(60).times(4),
    teamTimeToCliff: 0,
    teamVestingDuration: new BigNumber(60).times(60).times(24).times(365).times(3), // 3 years
    teamGrants: [
        {
            receiver: "0x0000000000000000000000000000000000000000",
            amount: new BigNumber(500000).mul(TOKEN_UNIT)
        }
    ],
    investorsTimeToCliff: 0,
    investorsVestingDuration: new BigNumber(60).times(60).times(24).times(365).times(3).div(2),
    investorGrants: [
        {
            receiver: "0x0000000000000000000000000000000000000000",
            amount: new BigNumber(1000).mul(TOKEN_UNIT)
        }
    ],
    communityGrants: [
        {
            receiver: "0x0000000000000000000000000000000000000000",
            amount: new BigNumber(1000).mul(TOKEN_UNIT)
        }
    ]
}
