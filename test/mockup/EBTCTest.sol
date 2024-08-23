// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EBTC} from "../../src/EBTC.sol";

contract EBTCTest is EBTC {
    constructor(address _bridge) EBTC(_bridge) {
        admin = msg.sender;
        bridge = _bridge;
    }

    function mintForTest(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
