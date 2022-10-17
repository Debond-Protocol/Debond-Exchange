pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract DBIT is ERC20 {

constructor(uint initialSupply, address _mintedAddress) ERC20("DAI Token", "DAI") {

_mint(address(_mintedAddress), initialSupply);
}


}
