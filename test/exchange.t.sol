pragma solidity 0.8.17;


import { Cheats } from "forge-std/Cheats.sol";
import { console } from "forge-std/console.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import {Exchange} from '../contracts/Exchange.sol';
import {ExchangeStorage} from 
contract ExchangeTest is PRBTest, Exchange, Cheats {

constructor(        address _exchangeStorageAddress,
        address _executableAddress,
        address _DBITAddress
) Exchange(_exchangeStorageAddress,_executableAddress,_DBITAddress)
{}



function mockAuctionCall() external {
address creator = "0xc0ffee254729296a45a3885639AC7E10F9d54979" // any random address





}

}