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
import "erc3475/IERC3475.sol";
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
            msg.sender == exchangeStorage.getAuction(_auctionId).owner,
            "Exchange: Caller is not the auction owner"
        );
        _;
    }

    /**
    * @notice create an Auction with the ERC3475 Assets of the creator
    * @param creator the creator of the  of the token to purchase with
    * @param erc3475Address the address of the ERC3475 contract
    * @param classIds ERC3475 class Ids collection
    * @param nonceIds ERC3475 nonce Ids collection
    * @param amounts collection of bond amounts
    * @param minDBITAmount minimum auction's DBIT amount can reach
    * @param maxDBITAmount maximum auction's DBIT amount can reach
    * @param auctionDuration duration of the auction
    */
    function createAuction(
        address creator,
        address erc3475Address,
        uint256[] memory classIds,
        uint256[] memory nonceIds,
        uint256[] memory amounts,
        uint256 minDBITAmount,
        uint256 maxDBITAmount,
        uint256 auctionDuration
    ) external {
        // validation steps
        require(
            classIds.length == nonceIds.length &&
            classIds.length == amounts.length,
            "Exchange: inputs not correct"
        );
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
        require(
            minDBITAmount > 0,
            "Exchange: min DBIT Amount Should be greater 0"
        );
        require(
            exchangeStorageAddress != address(0),
            "Storage address is null address"
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
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
            .getAuction(id);

        IERC3475.Transaction[] memory transactions = new IERC3475.Transaction[](
            classIds.length
        );
        for (uint256 i = 0; i < classIds.length; i++) {
            IERC3475.Transaction memory transaction = IERC3475.Transaction(
                classIds[i],
                nonceIds[i],
                amounts[i]
            );
            transactions[0] = transaction;
        }

        IExchangeStorage.ERC3475Product memory product;
        product.ERC3475Address = erc3475Address;
        product.transactions = transactions;
        exchangeStorage.setProduct(id, product);

        // we are transferring the bonds to the exchange contract
        IERC3475(erc3475Address).transferFrom(
            creator,
            exchangeStorageAddress,
            transactions
        );
        emit AuctionStarted(id, auction.owner);
    }

    /**
    * @notice bid the auction, the first bidder gets the Assets
    * @param _auctionId Id of the auction requested
    */
    function bid(uint256 _auctionId) external nonReentrant {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
            .getAuction(_auctionId);
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
        address bidder = msg.sender;
        uint256 finalPrice = currentPrice(_auctionId);

        exchangeStorage.completeAuction(
            _auctionId,
            bidder,
            block.timestamp,
            finalPrice
        );

        IERC20(auction.erc20Currency).safeTransferFrom(
            msg.sender,
            auction.owner,
            finalPrice
        );
        exchangeStorage.completeERC3475Send(_auctionId);

        emit AuctionCompleted(_auctionId, bidder);
    }

    function cancelAuction(uint256 _auctionId)
    external
    onlyAuctionOwner(_auctionId)
    {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
        .getAuction(_auctionId);
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
        IExchangeStorage.AuctionParam memory auction = exchangeStorage
        .getAuction(_auctionId);
        uint256 time_passed = block.timestamp - auction.startingTime;
        require(
            time_passed < auction.duration,
            "auction ended,equal to faceValue"
        );
        auctionPrice =
        auction.maxCurrencyAmount -
        ((auction.maxCurrencyAmount - auction.minCurrencyAmount) *
        time_passed) /
        auction.duration;
    }

    function getAuctionIds() external view returns (uint256[] memory) {
        return exchangeStorage.getAuctionIds();
    }

    function getAuction(uint256 _auctionId)
    external
    view
    returns (IExchangeStorage.AuctionParam memory)
    {
        return exchangeStorage.getAuction(_auctionId);
    }
}
