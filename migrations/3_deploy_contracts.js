const config = require("./migrations.config.js");
const ContractDeployer = require("../utils/contractDeployer");

const Controller = artifacts.require("Controller");
const Minter = artifacts.require("Minter");
const StakingManager = artifacts.require("StakingManager");
const RoundsManager = artifacts.require("RoundsManager");
const AdjustableRoundsManager = artifacts.require("AdjustableRoundsManager");
const MagicToken = artifacts.require("MagicToken");
const MagicTokenFaucet = artifacts.require("MagicTokenFaucet");
const ManagerProxy = artifacts.require("ManagerProxy");

module.exports = function(deployer, network) {
    deployer.then(async () => {

        const mgcDeployer = new ContractDeployer(deployer, Controller, ManagerProxy);
        const controller = await mgcDeployer.deployController();

        const mgcToken = await mgcDeployer.deployAndRegister(MagicToken, "MagicToken");
        await mgcDeployer.deployAndRegister(Minter, "Minter", controller.address, config.minter.inflation, config.minter.inflationChange, config.minter.targetBondingRate);

        if (!mgcDeployer.isProduction(network)) {
            // Only deploy a faucet if not in production
            const mgcFaucet = await mgcDeployer.deployAndRegister(MagicTokenFaucet, "MagicTokenFaucet", mgcToken.address, config.mgcFaucet.requestAmount, config.mgcFaucet.requestWait)
            await Promise.all(config.mgcFaucet.whitelist.map(async (address) => await mgcFaucet.addToWhitelist(address)));
            mgcToken.mint(mgcFaucet.address, config.mgcFaucet.faucetSupply)
        }

        let roundsManager, stakingManager;

        stakingManager = await mgcDeployer.deployProxyAndRegister(StakingManager, "StakingManager", controller.address)

        if (!mgcDeployer.isLiveNetwork(network)) {
            // Only deploy the adjustable rounds manager contract if we are in an isolated testing environment and not a live network
            roundsManager = await mgcDeployer.deployProxyAndRegister(AdjustableRoundsManager, "RoundsManager", controller.address)
        } else {
            roundsManager = await mgcDeployer.deployProxyAndRegister(RoundsManager, "RoundsManager", controller.address)
        }


        deployer.logger.log("Initializing contract state...")

        // Set StakingManager parameters
        await stakingManager.setUnbondingPeriod(config.stakingManager.unbondingPeriod)

        // Set RoundsManager parameters
        await roundsManager.setRoundLength(config.roundsManager.roundLength)
        await roundsManager.setRoundLockAmount(config.roundsManager.roundLockAmount)
    })
}
