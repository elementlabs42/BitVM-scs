// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Taproot} from "./Taproot.sol";
import "./Endian.sol";
import "./Base58.sol";
import "./TypedMemView.sol";
import "forge-std/console.sol";

library Script {
    using Taproot for bytes32;
    using {toChecksumHexString} for address;
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    error ScriptBytesTooLong();
    error StringsInsufficientHexLength(uint256 value, uint256 length);

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
    bytes1 constant OP_HASH160 = 0xA9;
    bytes1 constant OP_EQUALVERIFY = 0x88;
    bytes1 constant OP_EQUAL = 0x87;
    bytes1 constant OP_CHECKSIGVERIFY = 0xAD;

    bytes1 constant OP_PUSHDATA1 = 0x4c;
    bytes1 constant OP_PUSHDATA2 = 0x4d;
    bytes1 constant OP_PUSHDATA4 = 0x4e;

    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    function generateScript(bytes memory script) internal pure returns (bytes memory) {
        uint8 scriptLength = uint8(script.length);
        return abi.encodePacked(scriptLength, VERSION, script);
    }

    function generatePreSignScript(bytes32 nOfNPubKey) internal pure returns (bytes memory) {
        return generateScript(abi.encodePacked(nOfNPubKey, OP_CHECKSIG));
    }

    function generatePreSignScriptForTaproot(bytes32 nOfNPubKey) internal pure returns (bytes memory) {
        bytes memory script = abi.encodePacked(uint8(0x20), nOfNPubKey, OP_CHECKSIG);
        return script;
        // uint8 scriptLength = uint8(script.length);
        // return abi.encodePacked(scriptLength, script);
    }

    function generatePreSignScriptAddress(bytes32 nOfNPubKey) internal view returns (bytes memory) {
        return generateP2WSHScriptPubKey(generatePreSignScript(nOfNPubKey));
    }

    function generateTimelockLeaf(bytes32 pubKey, uint32 blocks) internal pure returns (bytes memory) {
        return abi.encodePacked(
            encodeNumber(blocks), OP_CHECKSEQUENCEVERIFY, OP_DROP, encodeData(bytes.concat(pubKey)), OP_CHECKSIG
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

    function generatePayToPubKeyHashWithInscriptionScript(string memory addr, uint32 timestamp, address evmAddress)
        internal
        view
        returns (bytes memory)
    {
        bytes memory pubKeyHash = toPubKeyHash(addr);
        bytes memory inscription =
            abi.encodePacked(pubKeyHash, bytes4(timestamp), bytes(evmAddress.toChecksumHexString()));
        bytes20 inscriptionHash = hash160(inscription);
        return abi.encodePacked(
            OP_FALSE,
            OP_IF,
            encodeData(abi.encodePacked(inscriptionHash)),
            OP_ENDIF,
            OP_DUP,
            OP_HASH160,
            encodeData(pubKeyHash),
            OP_EQUALVERIFY,
            OP_CHECKSIG
        );
    }

    function generateDepositTaprootAddress(
        bytes32 nOfNPubKey,
        address evmAddress,
        bytes32 depositorPubKey,
        uint32 lockDuration
    ) internal view returns (bytes32) {
        bytes memory timelockScript = generateTimelockLeaf(depositorPubKey, lockDuration);
        bytes memory depositScript = generateDepositScript(nOfNPubKey, evmAddress, depositorPubKey);
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = timelockScript;
        scripts[1] = depositScript;
        return depositorPubKey.createTaprootAddress(scripts);
    }

    function generateConfirmTaprootAddress(bytes32 nOfNPubKey) internal view returns (bytes32) {
        console.logBytes32(nOfNPubKey);
        bytes memory preSignScript = generatePreSignScriptForTaproot(nOfNPubKey);
        bytes[] memory scripts = new bytes[](1);
        scripts[0] = preSignScript;
        // scripts[1] = preSignScript;
        bytes32 taproot = nOfNPubKey.createTaprootAddress(scripts);
        console.logBytes32(taproot);
        return taproot;
    }

    function generateP2WSHScriptPubKey(bytes memory witnessScript) internal pure returns (bytes memory) {
        bytes32 scriptHash = sha256(witnessScript);
        // 0x00: version byte, 0x20: hash length
        return abi.encodePacked(bytes1(0x00), bytes1(0x20), scriptHash);
    }

    function toPubKeyHash(string memory addr) internal view returns (bytes memory) {
        bytes29 decoded = Base58.decodeFromString(addr).ref(0);
        // first 1 bit for version, last 4 bits for checksum
        return decoded.slice(1, decoded.len() - 5, 0).clone();
    }

    function convertToScriptPubKey(bytes32 outputKey) public pure returns (bytes memory) {
        // 0x51: OP_1, 0x20: OP_PUSHBYTES_32
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

    function hash160(bytes memory data) internal pure returns (bytes20) {
        return ripemd160(abi.encodePacked(sha256(data)));
    }

    function encodeData(bytes memory data) internal pure returns (bytes memory) {
        if (data.length > 0xFFFFFFFF) {
            revert ScriptBytesTooLong();
        }
        if (data.length == 1 && uint8(data[0]) == 0) {
            return abi.encodePacked(uint8(0));
        } else if (data.length == 1 && uint8(data[0]) <= 16) {
            return abi.encodePacked(uint8(data[0]) + 0x50);
        } else if (data.length <= 75) {
            return abi.encodePacked(uint8(data.length), data);
        } else if (data.length <= 0xFF) {
            return abi.encodePacked(OP_PUSHDATA1, uint8(data.length), data);
        } else if (data.length <= 0xFFFF) {
            return abi.encodePacked(OP_PUSHDATA2, Endian.reverse16(uint16(data.length)), data);
        } else {
            return abi.encodePacked(OP_PUSHDATA4, Endian.reverse32(uint32(data.length)), data);
        }
    }

    function encodeNumber(uint32 n) internal pure returns (bytes memory) {
        if (n <= 0xFF) {
            return encodeData(abi.encodePacked(uint8(n)));
        } else if (n <= 0xFFFF) {
            return encodeData(abi.encodePacked(Endian.reverse16(uint16(n))));
        } else if (n <= 0xFFFFFF) {
            return encodeData(abi.encodePacked(Endian.reverse24(uint24(n))));
        } else {
            return encodeData(abi.encodePacked(Endian.reverse32(n)));
        }
    }
}
