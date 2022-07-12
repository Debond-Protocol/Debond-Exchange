pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2022 Debond Protocol <info@debond.org>
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "erc-3475/contracts/IERC3475.sol";
import "./interfaces/IExchangeStorage.sol";

contract ExchangeStorage is IExchangeStorage  {

    using Counters for Counters.Counter;
    // for supplying the parameters of the bond functions.

    mapping(uint256 => Auction) _auctions;
    uint[] auctionsCollection;

    address exchangeAddress;
    address governanceAddress;
    uint maxAuctionDuration;
    uint minAuctionDuration;

    Counters.Counter private idCounter;

    constructor(address _governanceAddress)  {
        governanceAddress = _governanceAddress;
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
    function setMaxAuctionDuration(uint _maxAuctionDuration) external onlyGovernance {
        require(_maxAuctionDuration != 0, "Exchange: _maxAuctionDuration must be above 0");
        require(_maxAuctionDuration > minAuctionDuration, "Exchange: _maxAuctionDuration must be above min Auction Duration");
        maxAuctionDuration = _maxAuctionDuration;
    }

    function setMinAuctionDuration(uint _minAuctionDuration) external onlyGovernance {
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
        uint256 minCurrencyAmount,
        bool curvingPrice
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
        auctionParam.curvingPrice = curvingPrice;
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
            
            IERC3475.Transaction[] memory transactions = new IERC3475.Transaction[](1);
            IERC3475.Transaction memory transaction = IERC3475.Transaction(product.classId, product.nonceId, product.amount);
            transactions[0] = transaction;
            IERC3475(product.ERC3475Address).transferFrom(address(this), auction.successfulBidder, transactions);
        }
    }

    function cancelERC3475Send(uint auctionId) external onlyExchange {
        AuctionParam memory auction = _auctions[auctionId].auctionParam;
        uint[] memory productsIds = _auctions[auctionId].productIds;
        for(uint i; i < productsIds.length; i++) {
            ERC3475Product memory product = _auctions[auctionId].products[productsIds[i]];
            
            IERC3475.Transaction[] memory transactions = new IERC3475.Transaction[](1);
            IERC3475.Transaction memory transaction = IERC3475.Transaction(product.classId, product.nonceId, product.amount);
            transactions[0] = transaction;

            IERC3475(product.ERC3475Address).transferFrom(address(this), auction.owner, transactions);
        }
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

    function getMaxAuctionDuration() external view returns(uint) {
        return maxAuctionDuration;
    }

    function getAuctionCount() external view returns(uint) {
        return idCounter._value;
    }

    function getAuctionIds() external view returns(uint[] memory) {
        return auctionsCollection;
    }
}
