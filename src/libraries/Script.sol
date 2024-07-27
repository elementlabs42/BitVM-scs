// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Endian.sol";
import {TaprootHelper} from "./TaprootHelper.sol";

library Script {
    error BlocksIsZero();
    error OutOfRange();
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    using TaprootHelper for bytes32;
    using {toChecksumHexString} for address;

    error ScriptBytesTooLong();

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

    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    function generateScript(bytes memory script) internal pure returns (bytes memory) {
        uint8 scriptLength = uint8(script.length);
        return abi.encodePacked(scriptLength, VERSION, script);
    }

    function generatePreSignScript(bytes32 nOfNPubKey) internal pure returns (bytes memory) {
        return generateScript(abi.encodePacked(nOfNPubKey, OP_CHECKSIG));
    }

    function generatePreSignScriptAddress(bytes32 nOfNPubKey) internal pure returns (bytes memory) {
        return generateP2WSHScriptPubKey(generatePreSignScript(nOfNPubKey));
    }

    function generateTimelockLeaf(bytes32 pubKey, uint32 blocks) internal pure returns (bytes memory) {
        return abi.encodePacked(
            encodeBlocks(blocks), OP_CHECKSEQUENCEVERIFY, OP_DROP, encodeData(bytes.concat(pubKey)), OP_CHECKSIG
        );
    }

    function generateDepositScript(bytes32 nOfNPubKey, address evmAddress, bytes32 depositorPubKey)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            OP_FALSE,
            OP_IF,
            encodeData(bytes(evmAddress.toChecksumHexString())),
            OP_ENDIF,
            encodeData(bytes.concat(nOfNPubKey)),
            OP_CHECKSIGVERIFY,
            encodeData(bytes.concat(depositorPubKey)),
            OP_CHECKSIG
        );
    }

    function generatePayToPubkeyScript(bytes memory pubKey) internal pure returns (bytes memory) {
        return abi.encodePacked(encodeData(pubKey), OP_CHECKSIG);
    }

    function generateDepositTaprootAddress(
        bytes32 nOfNPubKey,
        address evmAddress,
        bytes32 depositorPubKey,
        uint32 lockDuration
    ) internal pure returns (bytes32) {
        bytes memory timelockScript = generateTimelockLeaf(depositorPubKey, lockDuration);
        bytes memory depositScript = generateDepositScript(nOfNPubKey, evmAddress, depositorPubKey);
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = timelockScript;
        scripts[1] = depositScript;
        return depositorPubKey.createTaprootAddress(scripts);
    }

    function generateP2WSHScriptPubKey(bytes memory witnessScript) internal pure returns (bytes memory) {
        bytes32 scriptHash = sha256(witnessScript);

        bytes1 versionByte = 0x00;
        bytes1 hashLength = 0x20;
        return abi.encodePacked(versionByte, hashLength, scriptHash);
    }

    function convertToScriptPubKey(bytes32 outputKey) public pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x51), bytes1(0x20), outputKey);
    }

    function equals(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        return keccak256(a) == keccak256(b);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its checksummed ASCII `string` hexadecimal
     * representation, according to EIP-55.
     */
    function toChecksumHexString(address addr) internal pure returns (string memory) {
        bytes memory buffer = bytes(toHexString(uint256(uint160(addr)), 20));

        // hash the hex part of buffer (skip length + 2 bytes, length 40)
        uint256 hashValue;
        // this is safe since buffer is 42 bytes long
        assembly ("memory-safe") {
            hashValue := shr(96, keccak256(add(buffer, 0x22), 40))
        }

        for (uint256 i = 41; i > 1; --i) {
            // possible values for buffer[i] are 48 (0) to 57 (9) and 97 (a) to 102 (f)
            if (hashValue & 0xf > 7 && uint8(buffer[i]) > 96) {
                // case shift by xoring with 0x20
                buffer[i] ^= 0x20;
            }
            hashValue >>= 4;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
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
            revert BlocksIsZero();
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
        revert OutOfRange();
    }
}
