const Exchange = artifacts.require("Exchange");
const ExchangeStorage = artifacts.require("ExchangeStorage");
const ERC3475Test = artifacts.require("ERC3475Test");
const ERC20Currency = artifacts.require("ERC20Currency");

module.exports = async function (deployer, network, accounts) {

  await deployer.deploy(ERC3475Test);
  await deployer.deploy(ERC20Currency);
  await deployer.deploy(ExchangeStorage, accounts[0]);
  const exchangeStorageInstance = await ExchangeStorage.deployed();

  await deployer.deploy(Exchange, exchangeStorageInstance.address, accounts[0]);
  const exchangeInstance = await Exchange.deployed();
  await exchangeStorageInstance.setExchangeAddress(exchangeInstance.address);



};
