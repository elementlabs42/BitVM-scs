// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/libraries/Script.sol";
import "./Util.sol";

contract ScriptTest is Test {
    using Script for bytes32;

    bytes32 nOfNPubkey = hex"d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4";

    function testScript_generatePreSignScript() public view {
        bytes memory expected = (hex"2102d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4ac");
        bytes memory result = Script.generatePreSignScript(nOfNPubkey);
        assertEq(expected, result);
        // assertTrue(Script.equals(result, expected));
    }

    function testScript_generatePreSignScriptAddress() public view {
        bytes memory expected = (hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d");
        bytes memory result = Script.generatePreSignScriptAddress(nOfNPubkey);
        assertEq(expected, result);
        // assertTrue(Script.equals(result, expected));
    }

    function testScript_generateDepositTaprootAddress() public pure {
        address evmAddress = 0x0000000000000000000000000000000000000000;
        bytes32 userPk = 0xedf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b;
        uint32 time = 4;
        bytes32 expected = 0x4d4ed1067e0bfddc5f26396fe0452966cecaac26f298a38c342c6de7cefda9ea;
        bytes32 result = nOfNPubkey.generateDepositTaprootAddress(evmAddress, userPk, time);
        assertEq(expected, result);
    }

    function testScript_generatePayToPubKeyScript() public pure {
        bytes memory userPk = hex"02edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b";
        bytes memory expected = hex"2102edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac";
        bytes memory result = Script.generatePayToPubkeyScript(userPk);
        assertEq(expected, result);
    }

    function testScript_equal() public pure {
        bytes memory a = hex"1234567890abcdef";
        bytes memory b = hex"1234567890abcdef";
        bytes memory c = hex"abcdef1234567890";
        assertTrue(Script.equals(a, b));
        assertFalse(Script.equals(a, c));
    }

    function testScript_encodeData() public pure {
        bytes memory data = hex"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
        assertEq(abi.encodePacked(hex"20", data), Script.encodeData(data));

        uint8 data1Length = 224; //uint8(0xFF + 1 - data.length);
        bytes memory data1 = Util.fill(data1Length, data);
        assertEq(abi.encodePacked(Script.OP_PUSHDATA1, data1Length, data1), Script.encodeData(data1));

        uint16 data2Length = 288; //uint16(0xFF + 1 + data.length);
        bytes memory data2 = Util.fill(data2Length, data);
        assertEq(abi.encodePacked(Script.OP_PUSHDATA2, Endian.reverse16(data2Length), data2), Script.encodeData(data2));

        // EvmError: MemoryOOG
        // uint32 data4Length = 65568; //uint32(0xFFFF + 1 + data.length);
        // bytes memory data4 = Util.fill(data4Length, data);
        // assertEq(abi.encodePacked(Script.OP_PUSHDATA4, Endian.reverse32(data4Length), data4), Script.encodeData(data4));
    }
}
