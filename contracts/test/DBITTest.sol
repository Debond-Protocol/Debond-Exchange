pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "@debond-protocol/debond-token-contracts/DBIT.sol";

contract DBITTest is DBIT {

    constructor(
        address governanceAddress,
        address bankAddress,
        address airdropAddress,
        address exchangeAddress
    ) DBIT(governanceAddress, bankAddress, airdropAddress, exchangeAddress) {}


}
