var Migrations = artifacts.require("./AuctchainHouse");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};
