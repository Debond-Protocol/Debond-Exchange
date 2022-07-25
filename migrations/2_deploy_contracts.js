const Exchange = artifacts.require("Exchange");
const ExchangeStorage = artifacts.require("ExchangeStorage");
const ERC3475Test = artifacts.require("ERC3475Test");
const DBIT = artifacts.require("DBITTest");

module.exports = async function (deployer, network, accounts) {

  const [governanceAddress, bankAddress, airdropAddress, exchangeAddress] = accounts

  await deployer.deploy(ERC3475Test);
  await deployer.deploy(DBIT, governanceAddress, bankAddress, airdropAddress, exchangeAddress);
  await deployer.deploy(ExchangeStorage, accounts[0]);

  const exchangeStorageInstance = await ExchangeStorage.deployed();
  const DBITAddress = (await DBIT.deployed()).address;

  await deployer.deploy(Exchange, exchangeStorageInstance.address, governanceAddress, DBITAddress);
  const exchangeInstance = await Exchange.deployed();
  await exchangeStorageInstance.setExchangeAddress(exchangeInstance.address);



};
