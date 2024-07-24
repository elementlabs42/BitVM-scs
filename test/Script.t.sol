// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/libraries/Script.sol";
import "./Util.sol";

contract ScriptTest is Test {
    using Script for bytes32;

    bytes32 nOfNPubKey = hex"d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4";

    function testScript_generatePreSignScript() public view {
        bytes memory expected = (hex"2102d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4ac");
        bytes memory result = Script.generatePreSignScript(nOfNPubKey);
        assertEq(expected, result);
        // assertTrue(Script.equals(result, expected));
    }

    function testScript_generatePreSignScriptAddress() public view {
        bytes memory expected = (hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d");
        bytes memory result = Script.generatePreSignScriptAddress(nOfNPubKey);
        assertEq(expected, result);
        // assertTrue(Script.equals(result, expected));
    }

    function testScript_generateDepositTaprootAddress() public view {
        bytes32 userPubKey = 0xedf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b;
        {
            address evmAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
            uint32 time = 2;

            bytes32 expected = 0x2f9c2de2b9630bb871200e9fb38700a0924da99a362d7472259b2e0f88403a3a;
            bytes32 result = nOfNPubKey.generateDepositTaprootAddress(evmAddress, userPubKey, time);
            assertEq(expected, result);
        }
        {
            address evmAddress = 0x0000000000000000000000000000000000000000;
            uint32 time = 2;

            bytes32 expected = 0x6eda572bf2622327e74f1c450f51a4893741a5c7c712fa04bad7e805e6c5f45f;
            bytes32 result = nOfNPubKey.generateDepositTaprootAddress(evmAddress, userPubKey, time);
            assertEq(expected, result);
        }
        {
            address evmAddress = 0x0000000000000000000000000000000000000000;
            uint32 time = 4;

            bytes32 expected = 0x4d4ed1067e0bfddc5f26396fe0452966cecaac26f298a38c342c6de7cefda9ea;
            bytes32 result = nOfNPubKey.generateDepositTaprootAddress(evmAddress, userPubKey, time);
            assertEq(expected, result);
        }
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
