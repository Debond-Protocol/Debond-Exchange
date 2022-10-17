pragma solidity ^0.8.17;

import "../ExchangeStorage.sol";

contract MockExchangeStorage is ExchangeStorage{

constructor (address _executableAddress) ExchangeStorage(_executableAddress) public {}

}