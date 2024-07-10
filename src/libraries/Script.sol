// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./SafeMath.sol";
import {TaprootHelper} from "./TaprootHelper.sol";
import {BtcTxProof} from "../interfaces/IBtcBridge.sol";

library Script {
    using SafeMath for uint256;
    using TaprootHelper for bytes32;

    function generatePreSignScript(bytes32 nOfNPubkey) internal pure returns (bytes memory) {
        return abi.encodePacked(nOfNPubkey, " CHECKSIG");
    }

    function generatePreSignScriptAddress(bytes32 nOfNPubkey) internal pure returns (bytes memory) {
        return generateP2WSHScriptPubKey(generatePreSignScript(nOfNPubkey));
    }

    function generateTimelockLeaf(bytes32 pubkey, uint256 blocks) internal pure returns (bytes memory) {
        return abi.encodePacked(blocks, " OP_CHECKSEQUENCEVERIFY OP_DROP ", pubkey, " OP_CHECKSIG");
    }

    function generateDepositScript(bytes32 nOfNPubkey, address evmAddress) internal pure returns (bytes memory) {
        return abi.encodePacked(generatePreSignScript(nOfNPubkey), " OP_TRUE OP_FALSE OP_IF ", evmAddress, " OP_ENDIF");
    }

    function generatePayScript(bytes32 dstAddress) internal pure returns (bytes memory) {
        return abi.encodePacked("OP_DUP OP_RIPEMD160 ", dstAddress, " CHECKSIG OP_EQUALVERIFY OP_CHECKSIG");
    }

    function generateDepositTaproot(bytes32 nOfNPubkey, address evmAddress, bytes32 userPk, uint256 lockDuration)
        internal
        pure
        returns (bytes32)
    {
        bytes memory depositScript = generateDepositScript(nOfNPubkey, evmAddress);
        bytes memory timelockScript = generateTimelockLeaf(userPk, lockDuration);
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = depositScript;
        scripts[1] = timelockScript;
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
