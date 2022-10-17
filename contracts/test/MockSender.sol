pragma solidity ^0.8.17;
import {MockExchange} from "../utils/MockExchange.sol";
import {MockExchangeStorage} from "../utils/MockExchangeStorage.sol";
import {DBIT} from "../utils/CollateralTest.sol";
import {ERC3475Test} from "../test/ERC3475Test.sol";
import {DSTestPlus} from "./utils/DSTestPlus.sol";

contract Sender is DSTestPlus {
    MockExchange Exchange;
    MockExchangeStorage exchangeStorage;
    DBIT collateral;
    ERC3475Test testBond;

    function setUp() public {
        address executableAddress = address(0); // imp: in reality this MUST be non zero address accessing the parameters, here we are taking the approximation.
        collateral = new DBIT(1000000, address(this));
        exchangeStorage = new ExchangeStorage(executableAddress);
        testBond = new ERC3475Test();
        Exchange = new MockExchange(
            address(exchangeStorage),
            executableAddress,
            address(collateral)
        );
    }

    function testIssueAuction() public {
        Exchange.createAuction(
            address(this),
            testBond,
            [1],
            [0],
            [100],
            200,
            150,
            3600
        );
        assertLt(Exchange.currentPrice(0), 200);
    }

    function testCancelAuction() public {
        Exchange.cancelAuction(0);
        assertEqual(exchangeStorage.getAuction(0)[1], 0);
    }


}
