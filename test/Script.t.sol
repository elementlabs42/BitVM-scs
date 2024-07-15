// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/libraries/Script.sol";

contract ScriptTest is Test {
    using Script for bytes32;
    bytes32 nOfNPubkey = hex"d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4";

    function testGeneratePreSignScript() public {
        bytes memory expected = (
            hex"2102d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4ac"
        );
        bytes memory result = Script.generatePreSignScript(nOfNPubkey);
        console.logBytes(result);
        assertTrue(Script.equal(result, expected));
    }

    function testGeneratePreSignScriptAddress() public {
        bytes memory preSignScript = Script.generatePreSignScript(nOfNPubkey);
        bytes memory expected = (hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d");
        bytes memory result = Script.generatePreSignScriptAddress(nOfNPubkey);
        assertTrue(Script.equal(result, expected));
    }

    function testGenerateDepositTaprootAddress() public {
        address evmAddress = 0x0000000000000000000000000000000000000000;
        bytes32 userPk = 0xedf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b;
        uint256 time = 4;
        bytes32 expected = 0x04c49a30b0b5434ca94598089adc09d7c48cf1f21f2dd6cc7b11151779795ac4;
        bytes32 result = nOfNPubkey.generateDepositTaproot(evmAddress, userPk, time);
        assertEq(expected, result);
    }


    function testEqual() public {
        bytes memory a = hex"1234567890abcdef";
        bytes memory b = hex"1234567890abcdef";
        bytes memory c = hex"abcdef1234567890";
        assertTrue(Script.equal(a, b));
        assertFalse(Script.equal(a, c));
    }
}
