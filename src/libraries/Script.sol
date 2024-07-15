// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./SafeMath.sol";
import {TaprootHelper} from "./TaprootHelper.sol";
import {BtcTxProof} from "../interfaces/IBtcBridge.sol";

library Script {
    using SafeMath for uint256;
    using TaprootHelper for bytes32;
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

    function generateTimelockLeaf(bytes32 pubkey, uint256 blocks) internal pure returns (bytes memory) {
        bytes memory script = abi.encodePacked(blocks, OP_CHECKSEQUENCEVERIFY, OP_DROP, pubkey, OP_CHECKSIG);
        return script;
    }

    function generateDepositScript(bytes32 nOfNPubkey, address evmAddress, bytes32 userPk) internal pure returns (bytes memory) {
        bytes memory script = abi.encodePacked(OP_FALSE, OP_IF, evmAddress, OP_ENDIF, nOfNPubkey, OP_CHECKSIGVERIFY, userPk, OP_CHECKSIG);
        return script;
    }

    function generateDepositTaproot(bytes32 nOfNPubkey, address evmAddress, bytes32 userPk, uint256 lockDuration)
        internal
        view
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
        // Perform SHA-256 hash of the witness script
        bytes32 scriptHash = sha256(witnessScript);

        // Construct the P2WSH scriptPubKey
        bytes1 versionByte = 0x00; // SegWit version 0
        bytes1 hashLength = 0x20; // Length of the hash (32 bytes)
        return abi.encodePacked(versionByte, hashLength, scriptHash);
    }

    function equal(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        for (uint256 i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }
}
