// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EBTC is ERC20 {
  constructor() ERC20("eBTC", "ebtc") {}
}