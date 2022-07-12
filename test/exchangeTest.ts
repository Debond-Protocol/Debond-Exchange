import {
    ERC20CurrencyInstance,
    ERC3475TestInstance,
    ExchangeInstance, ExchangeStorageInstance,
} from "../types/truffle-contracts";

const Exchange = artifacts.require("Exchange");
const ExchangeStorage = artifacts.require("ExchangeStorage");
const ERC3475Test = artifacts.require("ERC3475Test");
const ERC20Currency = artifacts.require("ERC20Currency");


// delay is in msec.
async function timeout(delay: number) {
    return new Promise(resolve => setTimeout(resolve, delay));
}


contract('Exchange', async (accounts: string[]) => {
    const [deployer, seller, bidder] = accounts;
    let exchangeInstance: ExchangeInstance;
    let exchangeStorageInstance: ExchangeStorageInstance;
    let erc3475TestInstance: ERC3475TestInstance;
    let erc20CurrencyInstance: ERC20CurrencyInstance;


    const initialERC3475Issued = web3.utils.toWei('10000', 'ether');
    const initialERC20Issued = web3.utils.toWei('10000', 'ether');
    const bidAmount = web3.utils.toWei('8000', 'ether');


    enum AuctionStatus {
        Started,
        Completed,
        Cancelled
    }


    it('Initialisation', async () => {
        exchangeInstance = await Exchange.deployed();
        exchangeStorageInstance = await ExchangeStorage.deployed();
        erc3475TestInstance = await ERC3475Test.deployed();
        erc20CurrencyInstance = await ERC20Currency.deployed();


        // 1.seller needs to get some bonds
        await erc3475TestInstance.issue(seller, [{classId: 0, nonceId: 0, amount: initialERC3475Issued}])

        // 2. bidder gets some auction erc20 currency
        await erc20CurrencyInstance.mint(bidder, initialERC20Issued);

        assert.equal((await erc3475TestInstance.balanceOf(seller, 0, 0)).toString(), initialERC3475Issued.toString())
        assert.equal((await erc20CurrencyInstance.balanceOf(bidder)).toString(), initialERC20Issued.toString())

    });

    it('Should create Bond Auction', async () => {

        await erc3475TestInstance.setApprovalFor(exchangeInstance.address, true, {from: seller})
        await exchangeInstance.createSecondaryMarketAuction(
            seller,
            erc3475TestInstance.address,
            [0],
            [0],
            [bidAmount],
            erc20CurrencyInstance.address,
            web3.utils.toWei('1500', 'ether'),
            web3.utils.toWei('2000', 'ether'),
            3600,
            true,
            {from: seller}
        )
        console.log("exchange balance erc3475 tokens: " + (await erc3475TestInstance.balanceOf(exchangeStorageInstance.address, 0, 0)).toString());

        assert.equal((await exchangeInstance.getAuctionIds()).length, 1);
    });

    it('should be able to successfully bid auction ', async () => {


        const maxPrice = (await exchangeInstance.getAuction(0)).maxCurrencyAmount.toString()
        await erc20CurrencyInstance.approve(exchangeInstance.address, maxPrice, {from: bidder});
        await exchangeInstance.bid(0, {from: bidder});
        const finalPrice = (await exchangeInstance.getAuction(0)).finalPrice
        assert.equal((await erc3475TestInstance.balanceOf(bidder, 0, 0)).toString(), bidAmount)
        assert.equal(web3.utils.toBN(initialERC20Issued).sub(await erc20CurrencyInstance.balanceOf(bidder)).toString(), ((finalPrice)).toString())

    });

    it('Should cancel the created Auction  from the auction owner before bid', async () => {
        // adding another bid
        const erc3475Amount = 100;
        await exchangeInstance.createSecondaryMarketAuction(
            seller,
            erc3475TestInstance.address,
            [0],
            [0],
            [erc3475Amount],
            erc20CurrencyInstance.address,
            web3.utils.toWei('150', 'ether'),
            web3.utils.toWei('200', 'ether'),
            3600,
            false,
            {from: seller}
        )

        await exchangeInstance.cancelAuction(1, {from: seller});
        let auctionStatus = (await exchangeInstance.getAuction(1)).auctionState;

        assert.equal(auctionStatus.toString(), AuctionStatus.Cancelled.toString());


    });


    it('once the bid is successful, it cant be bid again ', async () => {
        try {
            await exchangeInstance.bid(0, {from: bidder});
        } catch (e: any) {
            assert.equal("bid is completed already", e.reason);
        }

    });


    it('the bidder should not be at same time issuer of the auction ', async () => {

        await exchangeInstance.createSecondaryMarketAuction(
            seller,
            erc3475TestInstance.address,
            [0],
            [0],
            [web3.utils.toWei('100', 'ether')],
            erc20CurrencyInstance.address,
            web3.utils.toWei('150', 'ether'),
            web3.utils.toWei('200', 'ether'),
            3600,
            true,
            {from: seller}
        );


        try {
            await exchangeInstance.bid(0, {from: seller});
        } catch (e: any) {
            assert.equal("Exchange: bidder should not be the auction owner", e.reason);
        }

    })

    it('current Price should decrease from auction initial price', async () => {
        await exchangeInstance.createSecondaryMarketAuction(
            seller,
            erc3475TestInstance.address,
            [0],
            [0],
            [web3.utils.toWei('100', 'ether')],
            erc20CurrencyInstance.address,
            web3.utils.toWei('150', 'ether'),
            web3.utils.toWei('200', 'ether'),
            3600,
            true,
            {from: seller}
        );
        await timeout(5000);

        const currentPrice = parseFloat(web3.utils.fromWei(await exchangeInstance.currentPrice(0)))
        console.log(currentPrice)
        assert.isTrue(currentPrice < 2000);

    })
});
