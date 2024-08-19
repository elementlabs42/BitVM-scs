// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/libraries/Script.sol";
import "./utils/Util.sol";

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

    function testScript_generatePayToPubKeyScript() public view {
        // txid: 351d4cfaa5589dd8252a02aaee787182fa9a01d870f7f3f7af96641866446c93 on mutinynet
        bytes memory userPubKey = hex"02f80c9d1ef9ff640df2058c431c282299f48424480d34f1bade2274746fb4df8b";
        string memory userAddress = Util.generateAddress(userPubKey, Util.P2PKH_TESTNET);
        bytes memory expected = hex"00204f82b133a5c31fd6f3b4199be2b776b7cdd9803f2e1c1848d932ee3cdd2ca521";
        bytes memory script = Script.generatePayToPubKeyHashWithInscriptionScript(
            userAddress, 1722328130, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
        );
        bytes memory result = Script.generateP2WSHScriptPubKey(script);
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

    function testScript_encodeNumber() public pure {
        assertEq(abi.encodePacked(bytes1(uint8(2 + 0x50))), Script.encodeNumber(2));
        assertEq(abi.encodePacked(bytes1(uint8(1)), bytes1(uint8(17))), Script.encodeNumber(17));
        assertEq(abi.encodePacked(bytes1(uint8(1)), bytes1(0xff)), Script.encodeNumber(0xff));
        assertEq(abi.encodePacked(bytes1(uint8(2)), bytes2(0x0001)), Script.encodeNumber(0xff + 1));
        assertEq(abi.encodePacked(bytes1(uint8(2)), bytes2(0xffff)), Script.encodeNumber(0xffff));
        assertEq(abi.encodePacked(bytes1(uint8(3)), bytes3(0x000001)), Script.encodeNumber(0xffff + 1));
        assertEq(abi.encodePacked(bytes1(uint8(3)), bytes3(0xffffff)), Script.encodeNumber(0xffffff));
        assertEq(abi.encodePacked(bytes1(uint8(3)), bytes3(0x3f39d2)), Script.encodeNumber(13777215));
        assertEq(abi.encodePacked(bytes1(uint8(4)), bytes4(0x00000001)), Script.encodeNumber(0xffffff + 1));
        assertEq(abi.encodePacked(bytes1(uint8(4)), bytes4(0xfc0353f9)), Script.encodeNumber(4182967292));
        assertEq(abi.encodePacked(bytes1(uint8(4)), bytes4(0xffffffff)), Script.encodeNumber(0xffffffff));
    }
}
