// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/libraries/TaprootHelper.sol";

contract TaprootTest is Test {
    function testTaprootAddress() public view {
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = hex"54b27520edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac";
        scripts[1] = hex"00632a3078303030303030303030303030303030303030303030303030303030303030303030303030303030306820d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4ad20edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac";
        assertEq(TaprootHelper.createTaprootAddress(0xd0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4, scripts), 0x4d4ed1067e0bfddc5f26396fe0452966cecaac26f298a38c342c6de7cefda9ea);
    }
}
