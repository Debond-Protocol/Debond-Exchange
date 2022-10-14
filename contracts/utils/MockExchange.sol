import {Exchange} from '../contracts/Exchange.sol';
import {ExchangeStorage} from '../contracts/ExchangeStorage.sol';
import {ERC3475} from "erc3475/ERC3475.sol";
/**

address _exchangeStorageAddress,
        address _executableAddress,
        address _DBITAddress
 */
contract MockExchange is Exchange {


constructor(address _exchangeStorageAddress,address _executableAddress,address _DBITAddress) Exchange(_exchangeStorageAddress, _executableAddress, _DBITAddress) {
}


}