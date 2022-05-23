pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
/*
    Copyright 2020 Sigmoid Foundation <info@SGM.finance>
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

interface IExchangeStorage {


    enum AuctionState {
        Started,
        Completed,
        Cancelled
    }

    struct ERC3475Product {
        address ERC3475Address;
        uint256 classId;
        uint256 nonceId;
        uint256 amount;
    }

    struct AuctionParam {
        address owner;
        uint256 startingTime;
        uint256 endingTime;
        uint256 duration;
        address erc20Currency;
        uint256 maxCurrencyAmount;
        uint256 minCurrencyAmount;
        AuctionState auctionState;
        bool curvingPrice;
        address successfulBidder;
        uint256 finalPrice;
    }

    struct Auction {
        uint id;
        AuctionParam auctionParam;
        mapping(uint256 => ERC3475Product) products;
        uint256[] productIds;
    }


    function setExchangeAddress(address exchangeAddress) external;

    function setMaxAuctionDuration(uint maxAuctionDuration) external;

    function setMinAuctionDuration(uint minAuctionDuration) external;

    /**
    defines the function to create an dutch auction.
    @param owner address of the owner.
    @param startingTime is the time for listing of given bond for auction.
    @param duration is the max time interval for auction   (before an bid).
    @param erc20Currency the underlying ERC20 token for underlying denomination  of the bond 
    @param maxCurrencyAmount is the  starting price of the bond 
    @param minCurrencyAmount is the min amount achieved on the pricing curve if there is not bid till (startingTime + Duration).
    @param curvingPrice defines  the nature of the price based on the type of bond (fixed or floating rate). 
     */


    function createAuction(
        address owner,
        uint256 startingTime,
        uint256 duration,
        address erc20Currency,
        uint256 maxCurrencyAmount,
        uint256 minCurrencyAmount,
        bool curvingPrice
    ) external;
    

    function addProduct(uint auctionId, uint productId, ERC3475Product calldata product) external;

    function completeAuction(uint auctionId, address successfulBidder, uint endingTime, uint finalPrice) external;

    function completeERC3475Send(uint auctionId) external;

    function cancelERC3475Send(uint auctionId) external;

    function cancelAuction(uint auctionId, uint endingTime) external;

    function getAuction(uint auctionId) external view returns (AuctionParam memory auction);

    function getERC3475ProductIds(uint auctionId) external view returns(uint[] memory);

    function getERC3475Product(uint auctionId, uint productId) external view returns(ERC3475Product memory);

    function getMinAuctionDuration() external view returns(uint);

    function getMaxAuctionDuration() external view returns(uint);

    function getAuctionCount() external view returns(uint);

    function getAuctionIds() external view returns(uint[] memory);
}
