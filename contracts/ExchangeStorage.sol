// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "erc-3475/contracts/IERC3475.sol";
import "./interfaces/IExchangeStorage.sol";
import "./interfaces/IDebondBond.sol";
contract ExchangeStorage is IExchangeStorage  {

    using Counters for Counters.Counter;

    mapping(uint256 => Auction) _auctions;
    uint[] auctionsCollection;

    address exchangeAddress;
    address governanceAddress;
    uint maxAuctionDuration;
    uint minAuctionDuration;

    

    // TODO: calculate the current Bond price  to be the bond price on the time during bidding . 
    mapping(address =>  mapping(uint => mapping (uint => uint))) bondRedemtionPrize;
    Counters.Counter private idCounter;

    constructor(address _governanceAddress)  {
        governanceAddress = _governanceAddress;
       // here  MaxDuration will be  defined by redemption time of the bond for given nonce nad classId. 
        maxAuctionDuration = 30 days;
        minAuctionDuration = 3600;
    }

    modifier onlyExchange() {
        require(msg.sender == exchangeAddress, "Exchange Storage: not allowed");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governanceAddress, "Exchange Storage: not allowed");
        _;
    }

    // Only Governance
    function setExchangeAddress(address _exchangeAddress) external onlyGovernance {
        exchangeAddress = _exchangeAddress;
    }

    // only from Governance
    function setMaxAuctionDuration(uint _maxAuctionDuration) external onlyExchange {
        require(_maxAuctionDuration != 0, "Exchange: _maxAuctionDuration must be above 0");
        require(_maxAuctionDuration > minAuctionDuration, "Exchange: _maxAuctionDuration must be above min Auction Duration");
        maxAuctionDuration = _maxAuctionDuration;
    }

    function setMinAuctionDuration(uint _minAuctionDuration) external onlyExchange {
        require(_minAuctionDuration != 0, "Exchange: _minAuctionDuration must be above 0");
        require(maxAuctionDuration > _minAuctionDuration, "Exchange: _minAuctionDuration must be below max Auction Duration");
        minAuctionDuration = _minAuctionDuration;
    }

    function createAuction(
        address owner,
        uint256 startingTime,
        uint256 duration,
        address erc20CurrencyAddress,
        uint256 maxCurrencyAmount,
        uint256 minCurrencyAmount
    ) external onlyExchange {
        Auction storage auction = _auctions[idCounter._value];
        AuctionParam storage auctionParam = auction.auctionParam;

        auction.id = idCounter._value;
        auctionParam.startingTime = startingTime;
        auctionParam.owner = owner;
        auctionParam.erc20Currency = erc20CurrencyAddress;
        auctionParam.minCurrencyAmount = minCurrencyAmount;
        auctionParam.maxCurrencyAmount = maxCurrencyAmount;
        auctionParam.duration = duration;
        auctionParam.auctionState = AuctionState.Started;
        // increment the id
        idCounter.increment();
        auctionsCollection.push(auction.id);
    }

    function addProduct(uint _auctionId, uint _productId, ERC3475Product memory _product) external onlyExchange {
        Auction storage auction = _auctions[_auctionId];
        ERC3475Product storage product = auction.products[_productId];
        product.ERC3475Address = _product.ERC3475Address;
        product.classId = _product.classId;
        product.nonceId = _product.nonceId;
        product.amount = _product.amount;
        auction.productIds.push(_productId);
    }

    function completeAuction(uint auctionId, address successfulBidder, uint endingTime, uint finalPrice) external onlyExchange {
        AuctionParam storage auction = _auctions[auctionId].auctionParam;
        auction.successfulBidder = successfulBidder;
        auction.endingTime = endingTime;
        auction.finalPrice = finalPrice;
        auction.auctionState = AuctionState.Completed;
    }

    function cancelAuction(uint auctionId, uint endingTime) external onlyExchange {
        AuctionParam storage auction = _auctions[auctionId].auctionParam;
        auction.endingTime = endingTime;
        auction.auctionState = AuctionState.Cancelled;
    }

    function completeERC3475Send(uint auctionId) external onlyExchange {
        AuctionParam memory auction = _auctions[auctionId].auctionParam;
        uint[] memory productsIds = _auctions[auctionId].productIds;
        for(uint i; i < productsIds.length; i++) {
            ERC3475Product memory product = _auctions[auctionId].products[productsIds[i]];
            IERC3475(product.ERC3475Address).transferFrom(address(this), auction.successfulBidder, product.classId, product.nonceId, product.amount);
        }
    }

    function cancelERC3475Send(uint auctionId) external onlyExchange {
        AuctionParam memory auction = _auctions[auctionId].auctionParam;
        uint[] memory productsIds = _auctions[auctionId].productIds;
        for(uint i; i < productsIds.length; i++) {
            ERC3475Product memory product = _auctions[auctionId].products[productsIds[i]];
            IERC3475(product.ERC3475Address).transferFrom(address(this), auction.owner, product.classId, product.nonceId, product.amount);
        }
    }

    /**
    
     */
    function setRedemptionBondPrice(uint classId, uint nonceId, address _creator) external onlyExchange {
        bondRedemtionPrize[_creator][classId][nonceId] = IERC3475(bondAddress).balanceOf(_creator,classId,nonceId);
    } 

    function getRedemptionBondPrice( address _creator , uint classId, uint nonceId) external  view returns(uint prize) {
    
        prize = bondRedemtionPrize[_creator][classId][nonceId];
    }


    function getAuction(uint auctionId) external view returns (AuctionParam memory auction) {
        return _auctions[auctionId].auctionParam;
    }

    function getERC3475ProductIds(uint auctionId) external view returns(uint[] memory) {
        return _auctions[auctionId].productIds;
    }

    function getERC3475Product(uint auctionId, uint productId) external view returns(ERC3475Product memory) {
        return _auctions[auctionId].products[productId];
    }

    function getMinAuctionDuration() external view returns(uint) {
        return minAuctionDuration;
    }

    function getMaxAuctionDuration(address bondAddress , uint classId, uint nonceId) external view returns(uint) {
        return IDebondBond(bondAddress).bondDetails(classId, nonceId).maturityDate;
    }

    function getAuctionCount() external view returns(uint) {
        return idCounter._value;
    }

    function getAuctionIds() external view returns(uint[] memory) {
        return auctionsCollection;
    }
}
