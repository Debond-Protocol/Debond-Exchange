import {Exchange} from "../contracts/Exchange.sol";
import {ExchangeStorage} from "../contracts/ExchangeStorage.sol";
import {ERC3475} from "erc3475/ERC3475.sol";

/**

address _exchangeStorageAddress,
        address _executableAddress,
        address _DBITAddress
 */
contract MockExchange is Exchange {
    constructor(
        address _exchangeStorageAddress,
        address _executableAddress,
        address _DBITAddress
    ) Exchange(_exchangeStorageAddress, _executableAddress, _DBITAddress) {}

    function mockAuction(
        address creator,
        address erc3475Address,
        uint256[] memory classIds,
        uint256[] memory nonceIds,
        uint256[] memory amounts,
        uint256 minDBITAmount,
        uint256 maxDBITAmount,
        uint256 auctionDuration
    ) external {
        this.createAuction(
            creator,
            erc3475Address,
            classIds,
            nonceIds,
            amounts,
            minDBITAmount,
            auctionDuration
        );
    }
}
