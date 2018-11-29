const SortedDoublyLL = artifacts.require("SortedDoublyLL");

const StakingManager = artifacts.require("StakingManager");

module.exports = function(deployer) {
    deployer.deploy(SortedDoublyLL);
    deployer.link(SortedDoublyLL, StakingManager);
};


