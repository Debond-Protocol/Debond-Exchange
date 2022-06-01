// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "erc-3475/contracts/IERC3475.sol";
import "./interfaces/IExchangeStorage.sol";
import "debond-governance/contracts/utils/GovernanceOwnable.sol";
import "./interfaces/IDebondBond.sol";

contract Exchange is GovernanceOwnable, AccessControl, ReentrancyGuard {

    using SafeERC20 for IERC20;

    address exchangeStorageAddress;
    IExchangeStorage exchangeStorage;
    // events for the auctions

    event AuctionStarted(uint256 _auctionId, address issuer);
    event AuctionCancelled(uint256 _auctionId, address issuer, uint256 time);
    event AuctionCompleted(uint256 _auctionId, address BidWinner);
    event BidSubmitted(address indexed sender, uint256 amount);
    constructor(address _exchangeStorageAddress, address _governanceAddress) GovernanceOwnable(_governanceAddress) {
        exchangeStorageAddress = _exchangeStorageAddress;
        exchangeStorage = IExchangeStorage(_exchangeStorageAddress);
    }

    modifier onlyAuctionOwner(uint256 _auctionId) {
        require(
            msg.sender == exchangeStorage.getAuction(_auctionId).owner,
            "Exchange: Caller is not the auction owner"
        );
        _;
    }
    function createSecondaryMarketAuction(
        address creator,
        address[] memory erc3475Addresses,
        uint256[] memory classIds,
        uint256[] memory nonceIds,
        uint256[] memory amounts, 
        address currencyAddress,
        uint256 maxCurrencyAmount,
        uint256 auctionDuration
    ) external {
        // validation steps
        require(
            erc3475Addresses.length == classIds.length &&
            erc3475Addresses.length == nonceIds.length &&
            erc3475Addresses.length == amounts.length,
                "Exchange: inputs not correct"
        );
        for(uint i = 0; i < classIds.length; i++) {
            for (uint j = 0; j < nonceIds.length; j++) {
                exchangeStorage.setRedemptionBondPrice(creator,classIds[i], nonceIds[j], creator);
            }

        }

   

        
       // require(auctionDuration < exchangeStorage.getMaxAuctionDuration(), "Exchange: Max Duration Exceeded");
       // require(auctionDuration >= exchangeStorage.getMinAuctionDuration(), "Exchange: Min Duration not reached");
        require(bondCurrentPrice < currentPrice, "Exchange: min Currency Amount Should be less than max currency amount");
        require(bondCurrentPrice > 0, "Exchange: min Currency Amount Should be greater 0");
        require(exchangeStorageAddress != address(0), "Storage address is null address");

        // we are transferring the bonds to the exchange contract
        uint id = exchangeStorage.getAuctionCount();

        //minCurrencyAmount will be different for the different bond types based on the particular time of redemption  condition of the bond nonce (for both fixed and floating).
       

        exchangeStorage.createAuction(creator, block.timestamp, auctionDuration, currencyAddress, maxCurrencyAmount, minCurrencyAmount);
        IExchangeStorage.AuctionParam memory auction = exchangeStorage.getAuction(id);

        for(uint i = 0; i < erc3475Addresses.length; i++) {
            IERC3475(erc3475Addresses[i]).transferFrom(
                creator,
                exchangeStorageAddress,
                classIds[i],
                nonceIds[i],
                amounts[i]
            );
            IExchangeStorage.ERC3475Product memory product;
            product.ERC3475Address = erc3475Addresses[i];
            product.classId = classIds[i];
            product.nonceId = nonceIds[i];
            product.amount = amounts[i];
            exchangeStorage.addProduct(id, i, product);
        }
        emit AuctionStarted(id, auction.owner);
    }

    function bid(uint256 _auctionId) nonReentrant() external {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage.getAuction(_auctionId);
        require(auction.startingTime != 0, "Exchange: Auction id given not found");
        require(msg.sender != auction.owner, "Exchange: bidder should not be the auction owner");
        require(block.timestamp <= auction.startingTime + auction.duration, "Exchange: Auction Expired");
        require(
            auction.auctionState == IExchangeStorage.AuctionState.Started,
            "bid is completed already"
        );
        address bidder = msg.sender;
        uint finalPrice = currentPrice(_auctionId);

        exchangeStorage.completeAuction(_auctionId, bidder, block.timestamp, finalPrice);

        IERC20(auction.erc20Currency).transferFrom(msg.sender, auction.owner, finalPrice);
        exchangeStorage.completeERC3475Send(_auctionId);

        emit AuctionCompleted(_auctionId, bidder);
    }

    function cancelAuction(uint256 _auctionId) external onlyAuctionOwner(_auctionId) {
        IExchangeStorage.AuctionParam memory auction = exchangeStorage.getAuction(_auctionId);
        require(auction.auctionState == IExchangeStorage.AuctionState.Started, "auction already finished");

        uint cancellationTime = block.timestamp;
        exchangeStorage.cancelAuction(_auctionId, cancellationTime);

        // sending back the bonds to the owner
        exchangeStorage.cancelERC3475Send(_auctionId);

        emit AuctionCancelled(_auctionId, msg.sender, cancellationTime);
    }

    //TODO: @drikssy this will be defining the current redemption prize OF THE GIVEN BOND of the classId and nonceId
    function currentPrice(uint256 _auctionId) public view returns (uint256 auctionPrice) {

        IExchangeStorage.AuctionParam memory auction = exchangeStorage.getAuction(_auctionId);
       
       // auction.bondCurrentPrice = exchangeStorage.getRedemptionBondPrice(classId, nonceId);

        uint256 time_passed = block.timestamp - auction.startingTime;
        require(
            time_passed < auction.duration,
            "auction ended,equal to faceValue"
        );
      
            // for fixed rate , there will be using the straight line fixed price decreasing mechanism.
            auctionPrice  = auction.bondCurrentPrice + ((auction.maxCurrencyAmount  - auction.bondCurrentPrice) * time_passed / auction.duration);
        
        // else  if  its the floating rate, which will be implemented by the other market makers as explained in the whitepaper.
           }

    function getAuctionIds() external view returns (uint[] memory) {
        return exchangeStorage.getAuctionIds();
    }

    function getAuction(uint _auctionId) external view returns (IExchangeStorage.AuctionParam memory) {
        return exchangeStorage.getAuction(_auctionId);
    }

}
