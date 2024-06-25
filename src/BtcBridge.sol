// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./EBTC.sol";

contract BtcBridge {
  EBTC ebtc;

  constructor (EBTC _ebtc) {
    ebtc = _ebtc;
  }
}