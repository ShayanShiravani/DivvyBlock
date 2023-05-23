// var MetaMartianNFT = artifacts.require('./MetaMartianNFT.sol');
var DivvyMintFactory = artifacts.require('./DivvyMintFactory.sol');
// var DivvyPurchaseFactory = artifacts.require('./DivvyPurchaseFactory.sol');

module.exports = async function(deployer) {
	await deployer.deploy(DivvyMintFactory);
}
