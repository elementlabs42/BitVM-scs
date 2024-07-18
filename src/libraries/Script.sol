// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./SafeMath.sol";
import "./Endian.sol";
import {TaprootHelper} from "./TaprootHelper.sol";
import {BtcTxProof} from "../interfaces/IBridge.sol";

library Script {
    using SafeMath for uint256;
    using TaprootHelper for bytes32;

    error ScriptBytesTooLong();

    bytes1 constant PUB_KEY_LENGTH = 0x20;
    bytes1 constant ADDRESS_LENGTH = 0x2a;
    bytes1 constant VERSION = 0x02;
    bytes1 constant OP_CHECKSIG = 0xAC;
    bytes1 constant OP_CHECKSEQUENCEVERIFY = 0xb2;
    bytes1 constant OP_DROP = 0x75;
    bytes1 constant OP_TRUE = 0x51;
    bytes1 constant OP_FALSE = 0x00;
    bytes1 constant OP_IF = 0x63;
    bytes1 constant OP_ENDIF = 0x68;
    bytes1 constant OP_DUP = 0x76;
    bytes1 constant OP_RIPEMD160 = 0xA6;
    bytes1 constant OP_EQUALVERIFY = 0x88;
    bytes1 constant OP_EQUAL = 0x87;
    bytes1 constant OP_CHECKSIGVERIFY = 0xAD;

    bytes1 constant OP_PUSHDATA1 = 0x4c;
    bytes1 constant OP_PUSHDATA2 = 0x4d;
    bytes1 constant OP_PUSHDATA4 = 0x4e;
    bytes1 constant OP_1 = 0x51;
    bytes1 constant OP_2 = 0x52;
    bytes1 constant OP_3 = 0x53;
    bytes1 constant OP_4 = 0x54;
    bytes1 constant OP_5 = 0x55;
    bytes1 constant OP_6 = 0x56;
    bytes1 constant OP_7 = 0x57;
    bytes1 constant OP_8 = 0x58;
    bytes1 constant OP_9 = 0x59;
    bytes1 constant OP_10 = 0x5A;
    bytes1 constant OP_11 = 0x5B;
    bytes1 constant OP_12 = 0x5C;
    bytes1 constant OP_13 = 0x5D;
    bytes1 constant OP_14 = 0x5E;
    bytes1 constant OP_15 = 0x5F;
    bytes1 constant OP_16 = 0x60;

    function generateScript(bytes memory script) internal pure returns (bytes memory) {
        uint8 scriptLength = uint8(script.length);
        return abi.encodePacked(scriptLength, VERSION, script);
    }

    function generatePreSignScript(bytes32 nOfNPubkey) internal pure returns (bytes memory) {
        bytes memory script = abi.encodePacked(nOfNPubkey, OP_CHECKSIG);
        return generateScript(script);
    }

    function generatePreSignScriptAddress(bytes32 nOfNPubkey) internal pure returns (bytes memory) {
        return generateP2WSHScriptPubKey(generatePreSignScript(nOfNPubkey));
    }

    function generateTimelockLeaf(bytes32 pubkey, uint32 blocks) internal pure returns (bytes memory) {
        bytes memory script =
            abi.encodePacked(encodeBlocks(blocks), OP_CHECKSEQUENCEVERIFY, OP_DROP, PUB_KEY_LENGTH, pubkey, OP_CHECKSIG);
        return script;
    }

    function generateDepositScript(bytes32 nOfNPubkey, address evmAddress, bytes32 userPk)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory script = abi.encodePacked(
            OP_FALSE,
            OP_IF,
            ADDRESS_LENGTH,
            addressToString(evmAddress),
            OP_ENDIF,
            PUB_KEY_LENGTH,
            nOfNPubkey,
            OP_CHECKSIGVERIFY,
            PUB_KEY_LENGTH,
            userPk,
            OP_CHECKSIG
        );
        return script;
    }

    function generatePayToPubkeyScript(bytes memory pubKey) internal pure returns (bytes memory script) {
        script = abi.encodePacked(encodeData(pubKey), OP_CHECKSIG);
    }

    function generateDepositTaprootAddress(bytes32 nOfNPubkey, address evmAddress, bytes32 userPk, uint32 lockDuration)
        internal
        pure
        returns (bytes32)
    {
        bytes memory timelockScript = generateTimelockLeaf(userPk, lockDuration);
        bytes memory depositScript = generateDepositScript(nOfNPubkey, evmAddress, userPk);
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = timelockScript;
        scripts[1] = depositScript;
        return nOfNPubkey.createTaprootAddress(scripts);
    }

    function generateP2WSHScriptPubKey(bytes memory witnessScript) internal pure returns (bytes memory) {
        bytes32 scriptHash = sha256(witnessScript);

        bytes1 versionByte = 0x00;
        bytes1 hashLength = 0x20;
        return abi.encodePacked(versionByte, hashLength, scriptHash);
    }

    function equals(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        return keccak256(a) == keccak256(b);
    }

    function addressToString(address _address) public pure returns (string memory) {
        bytes memory addressBytes = abi.encodePacked(_address);
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(2 + addressBytes.length * 2);

        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < addressBytes.length; i++) {
            str[2 + i * 2] = hexChars[uint8(addressBytes[i] >> 4)];
            str[3 + i * 2] = hexChars[uint8(addressBytes[i] & 0x0f)];
        }

        return string(str);
    }

    function encodeData(bytes memory data) internal pure returns (bytes memory) {
        if (data.length > 0xFFFFFFFF) {
            revert ScriptBytesTooLong();
        }
        if (data.length <= 75) {
            return abi.encodePacked(uint8(data.length), data);
        } else if (data.length <= 0xFF) {
            return abi.encodePacked(OP_PUSHDATA1, uint8(data.length), data);
        } else if (data.length <= 0xFFFF) {
            return abi.encodePacked(OP_PUSHDATA2, Endian.reverse16(uint16(data.length)), data);
        } else {
            return abi.encodePacked(OP_PUSHDATA4, Endian.reverse32(uint32(data.length)), data);
        }
    }

    function encodeBlocks(uint32 blocks) internal pure returns (bytes memory) {
        if (blocks == 0) {
            revert("Blocks must be greater than 0");
        } else if (blocks <= 16) {
            return abi.encodePacked(getSmallIntegerOpcode(blocks));
        } else if (blocks <= 0xFF) {
            return abi.encodePacked(bytes1(0x01), bytes1(uint8(blocks)));
        } else if (blocks <= 0xFFFF) {
            return abi.encodePacked(bytes1(0x02), bytes1(uint8(blocks & 0xFF)), bytes1(uint8((blocks >> 8) & 0xFF)));
        } else if (blocks <= 0xFFFFFF) {
            return abi.encodePacked(
                bytes1(0x03),
                bytes1(uint8(blocks & 0xFF)),
                bytes1(uint8((blocks >> 8) & 0xFF)),
                bytes1(uint8((blocks >> 16) & 0xFF))
            );
        } else {
            return abi.encodePacked(
                bytes1(0x04),
                bytes1(uint8(blocks & 0xFF)),
                bytes1(uint8((blocks >> 8) & 0xFF)),
                bytes1(uint8((blocks >> 16) & 0xFF)),
                bytes1(uint8((blocks >> 24) & 0xFF))
            );
        }
    }

    function getSmallIntegerOpcode(uint32 value) internal pure returns (bytes1) {
        if (value == 1) return OP_1;
        if (value == 2) return OP_2;
        if (value == 3) return OP_3;
        if (value == 4) return OP_4;
        if (value == 5) return OP_5;
        if (value == 6) return OP_6;
        if (value == 7) return OP_7;
        if (value == 8) return OP_8;
        if (value == 9) return OP_9;
        if (value == 10) return OP_10;
        if (value == 11) return OP_11;
        if (value == 12) return OP_12;
        if (value == 13) return OP_13;
        if (value == 14) return OP_14;
        if (value == 15) return OP_15;
        if (value == 16) return OP_16;
        revert("Value out of range for small integer opcode");
    }
}
