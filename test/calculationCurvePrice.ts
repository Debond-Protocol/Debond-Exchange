import {BN, ether, expectEvent, expectRevert, time} from '@openzeppelin/test-helpers';
import {ExchangeInstance, ExchangeStorageInstance, ERC3475TestInstance,  ERC20CurrencyInstance } from '../types/truffle-contracts'


const Exchange = artifacts.require("Exchange");
const ExchangeStorage =  artifacts.require("ExchangeStorage");
const ERC3475Test = artifacts.require("ERC3475Test");
const ERC20Currency = artifacts.require("ERC20Currency");





/**
 * 
 * @param maxPrice is the maxPrice and starting for auction.
 * @param minPrice is minPrice based on the without bidding.
 * @param duration the time period taken without bid , so that face value reaches from maxPrice to minPrice.
 * @param isCurve bool to determine the formula for calculation from getting pricing from the curve formula or linear 
 * @param time is the time between initialTime to the presentTime 
 * @param initialPrice 
 * @returns 
 */

 function calculationExchangePricing(maxPrice: number, minPrice: number, duration: number, isCurve: boolean, time: number, initialPrice: number): number {
    let bidPrice;
    if (!isCurve) {
        bidPrice = minPrice + Math.pow((maxPrice - minPrice), 2) / Math.pow(duration, 2) * Math.pow(time - initialPrice, 2);
    }
    else {
        bidPrice = minPrice + (maxPrice - minPrice) / duration * time;
    }
    return bidPrice;
}

contract('Exchange', function ([deployer, issuer, redeemer]) {
    const initialTime = time.now();
    let  exchangeInstance : ExchangeInstance;
    let exchangeStorage : ExchangeStorageInstance;
    let bondTest : ERC3475TestInstance;
    let tokens : ERC20CurrencyInstance; 
    before(async function () {

    
        exchangeInstance = await Exchange.deployed();
        exchangeStorage = await ExchangeStorage.deployed();
        bondTest = await ERC3475Test.deployed();
        tokens = await ERC20Currency.deployed();
            tokens.mint(redeemer,1000000{from:redeemer});

       await  bondTest.issue(issuer,0,0,100);
       await exchangeInstance.createSecondaryMarketAuction(
        issuer,
        [bondTest.address],
        [0],
        [0],
        [web3.utils.toWei('100', 'ether')],
        tokens.address,
        web3.utils.toWei('150', 'ether'),
        web3.utils.toWei('200', 'ether'),
        3600,
        true,
        { from: issuer }
    );

    await exchangeInstance.createSecondaryMarketAuction(
        issuer,
        [bondTest.address],
        [1],
        [0],
        [web3.utils.toWei('100', 'ether')],
        tokens.address,
        web3.utils.toWei('150', 'ether'),
        web3.utils.toWei('200', 'ether'),
        3600,
        false,
        { from: issuer }
    );




    })
    
    
    it('check current price formula works with the actual calculation', async () => {

        let timeInitial = time.latestBlock();
        let duration = 100; 

        let initialCurrentPrice = await  exchangeInstance.currentPrice(0);
        expect(initialCurrentPrice).to.eql(200);
        await time.advanceBlockTo(100);
        // now considering that avg per block is 14.5 secs , thus in actual period time to be 1450 secs ()

      //  let priceCalculated

     //   expect 









    })






})

