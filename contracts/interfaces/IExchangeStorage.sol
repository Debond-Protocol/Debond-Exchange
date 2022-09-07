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

import "erc3475/IERC3475.sol";

interface IExchangeStorage {
  enum AuctionState {
    Started,
    Completed,
    Cancelled
  }

  struct ERC3475Product {
    address ERC3475Address;
    IERC3475.Transaction[] transactions;
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
    address successfulBidder;
    uint256 finalPrice;
  }

  struct Auction {
    uint256 id;
    AuctionParam auctionParam;
    ERC3475Product product;
  }

  function setExchangeAddress(address exchangeAddress) external;

  function setMaxAuctionDuration(uint256 maxAuctionDuration) external;

  function setMinAuctionDuration(uint256 minAuctionDuration) external;

  function createAuction(
    address owner,
    uint256 startingTime,
    uint256 duration,
    address erc20Currency,
    uint256 maxCurrencyAmount,
    uint256 minCurrencyAmount
  ) external;

  function setProduct(uint256 auctionId, ERC3475Product memory product) external;

  function completeAuction(
    uint256 auctionId,
    address successfulBidder,
    uint256 endingTime,
    uint256 finalPrice
  ) external;

  function completeERC3475Send(uint256 auctionId) external;

  function cancelERC3475Send(uint256 auctionId) external;

  function cancelAuction(uint256 auctionId, uint256 endingTime) external;

  function getAuction(uint256 auctionId) external view returns (AuctionParam memory auction);

  function getERC3475Product(uint256 auctionId) external view returns (ERC3475Product memory);

  function getMinAuctionDuration() external view returns (uint256);

  function getMaxAuctionDuration() external view returns (uint256);

  function getAuctionCount() external view returns (uint256);

  function getAuctionIds() external view returns (uint256[] memory);
}
