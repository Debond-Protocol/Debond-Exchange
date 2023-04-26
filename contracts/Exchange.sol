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

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IERC3475.sol";
import "./interfaces/IExchangeStorage.sol";
import "@debond-protocol/debond-governance-contracts/utils/ExecutableOwnable.sol";

contract Exchange is ExecutableOwnable, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address DBITAddress;
    address exchangeStorageAddress;
    IExchangeStorage exchangeStorage;

    // events for the auctions

    event AuctionStarted(uint256 _auctionId, address issuer);
    event AuctionCancelled(uint256 _auctionId, address issuer, uint256 time);
    event AuctionCompleted(uint256 _auctionId, address BidWinner);
    event AuctionSettled(uint256 _auctionId, address BidWinner);
    event BidSubmitted(address indexed sender, uint256 amount);

    constructor(
        address _exchangeStorageAddress,
        address _executableAddress,
        address _DBITAddress
    )
    ExecutableOwnable(_executableAddress)
    {
        exchangeStorageAddress = _exchangeStorageAddress;
        exchangeStorage = IExchangeStorage(_exchangeStorageAddress);
        DBITAddress = _DBITAddress;
    }

    modifier onlyAuctionOwner(uint256 _auctionId) {
        require(
            msg.sender == exchangeStorage.getAuction(_auctionId).auctionParam.owner,
            "Exchange: Caller is not the auction owner"
        );
        _;
    }

    /**
    * @notice create an Auction with the ERC3475 Assets of the creator
    * @param creator the creator of the  of the token to purchase with
    * @param erc3475Address the address of the ERC3475 contract
    * @param _transactions ERC3475 transaction object of the tokens
    * @param minDBITAmount minimum auction's DBIT amount can reach
    * @param maxDBITAmount maximum auction's DBIT amount can reach
    * @param auctionDuration duration of the auction
    */
    function createAuction(
        address creator,
        address erc3475Address,
        IERC3475.Transaction[] memory _transactions,
        uint256 minDBITAmount,
        uint256 maxDBITAmount,
        uint256 auctionDuration
    ) external {
        // validation steps
        require(
            auctionDuration < exchangeStorage.getMaxAuctionDuration(),
            "Exchange: Max Duration Exceeded"
        );
        require(
            auctionDuration >= exchangeStorage.getMinAuctionDuration(),
            "Exchange: Min Duration not reached"
        );
        require(
            minDBITAmount < maxDBITAmount,
            "Exchange: min DBIT Amount Should be less than max currency amount"
        );

        uint256 id = exchangeStorage.getAuctionCount();
        exchangeStorage.createAuction(
            creator,
            block.timestamp,
            auctionDuration,
            DBITAddress,
            maxDBITAmount,
            minDBITAmount
        );

        IExchangeStorage.ERC3475Product memory product;
        product.ERC3475Address = erc3475Address;
        product.transactions = _transactions;
        exchangeStorage.setProduct(id, product);

        // we are transferring the bonds to the exchange contract
        IERC3475(erc3475Address).transferFrom(
            creator,
            exchangeStorageAddress,
            _transactions
        );
        emit AuctionStarted(id, creator);
    }

    /**
    * @notice bid the auction, the first bidder gets the Assets
    * @param _auctionId Id of the auction requested
    */
    function bid(address _bidder, uint256 _auctionId) external nonReentrant {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
            .getAuction(_auctionId).auctionParam;
        require(
            auction.startingTime != 0,
            "Exchange: Auction id given not found"
        );
        require(
            msg.sender != auction.owner,
            "Exchange: bidder should not be the auction owner"
        );
        require(
            block.timestamp <= auction.startingTime + auction.duration,
            "Exchange: Auction Expired"
        );
        require(
            auction.auctionState == IExchangeStorage.AuctionState.Started,
            "bid is completed already"
        );
        address bidder = _bidder;
        uint256 finalPrice = currentPrice(_auctionId);

        exchangeStorage.completeAuction(
            _auctionId,
            bidder,
            block.timestamp,
            finalPrice
        );

        IERC20(auction.erc20Currency).safeTransferFrom(
            msg.sender,
            address(this),
            finalPrice
        );
        exchangeStorage.completeERC3475Send(_auctionId);

        emit AuctionCompleted(_auctionId, _bidder);
    }

    /**
    * @notice bid the auction, the first bidder gets the Assets
    * @param _auctionId Id of the auction requested
    */
    function bidWithFiat(address _bidder, uint256 _auctionId) external nonReentrant {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
            .getAuction(_auctionId).auctionParam;
        require(
            auction.startingTime != 0,
            "Exchange: Auction id given not found"
        );
        require(
            msg.sender != auction.owner,
            "Exchange: bidder should not be the auction owner"
        );
        require(
            block.timestamp <= auction.startingTime + auction.duration,
            "Exchange: Auction Expired"
        );
        require(
            auction.auctionState == IExchangeStorage.AuctionState.Started,
            "bid is completed already"
        );
        address bidder = _bidder;
        uint256 finalPrice = currentPrice(_auctionId);

        exchangeStorage.completeAuction(
            _auctionId,
            bidder,
            block.timestamp,
            finalPrice
        );

        emit AuctionCompleted(_auctionId, _bidder);
    }
    function settlement(uint256 _auctionId) external nonReentrant {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
            .getAuction(_auctionId).auctionParam;
       
        require(
            auction.auctionState == IExchangeStorage.AuctionState.Completed,
            "bid is not completed already"
        );

        IERC20(auction.erc20Currency).safeTransfer(
            auction.owner,
            auction.finalPrice
        );
        exchangeStorage.completeERC3475Send(_auctionId);

        emit AuctionSettled(_auctionId, auction.successfulBidder);
    }

    function settlementWithFiat(uint256 _auctionId) external nonReentrant {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
            .getAuction(_auctionId).auctionParam;
       
        require(
            auction.auctionState == IExchangeStorage.AuctionState.Completed,
            "bid is not completed already"
        );

        exchangeStorage.completeERC3475Send(_auctionId);

        emit AuctionSettled(_auctionId, auction.successfulBidder);
    }

    function cancelAuction(uint256 _auctionId)
    external
    onlyAuctionOwner(_auctionId)
    {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
        .getAuction(_auctionId).auctionParam;
        require(
            auction.auctionState == IExchangeStorage.AuctionState.Started,
            "auction already finished"
        );

        uint256 cancellationTime = block.timestamp;
        exchangeStorage.cancelAuction(_auctionId, cancellationTime);

        // sending back the bonds to the owner
        exchangeStorage.cancelERC3475Send(_auctionId);

        emit AuctionCancelled(_auctionId, msg.sender, cancellationTime);
    }

    function currentPrice(uint256 _auctionId)
    public
    view
    returns (uint256 auctionPrice)
    {
        uint256 time_passed = block.timestamp - exchangeStorage
        .getAuction(_auctionId).auctionParam.startingTime;
        require(
            time_passed < exchangeStorage.getAuction(_auctionId).auctionParam.duration,
            "auction ended,equal to faceValue"
        );
        auctionPrice =
        exchangeStorage.getAuction(_auctionId).auctionParam.maxCurrencyAmount -
        ((exchangeStorage.getAuction(_auctionId).auctionParam.maxCurrencyAmount - exchangeStorage.getAuction(_auctionId).auctionParam.minCurrencyAmount) *
        time_passed) /
        exchangeStorage.getAuction(_auctionId).auctionParam.duration;
    }
}
