// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma experimental ABIEncoderV2;

import "./Endian.sol";
import "../interfaces/IBridge.sol";
import "./ViewSPV.sol";
import "./ViewBTC.sol";
import "forge-std/console.sol";

library TransactionHelper {
    error ScriptBytesTooLong();
    using ViewSPV for bytes4;
    using TypedMemView for bytes;
    using Endian for bytes32;

    function readVarInt(bytes calldata buf, uint256 offset) public pure returns (uint256 val, uint256 newOffset) {
        uint8 pivot = uint8(buf[offset]);
        if (pivot < 0xfd) {
            val = pivot;
            newOffset = offset + 1;
        } else if (pivot == 0xfd) {
            val = Endian.reverse16(uint16(bytes2(buf[offset + 1:offset + 3])));
            newOffset = offset + 3;
        } else if (pivot == 0xfe) {
            val = Endian.reverse32(uint32(bytes4(buf[offset + 1:offset + 5])));
            newOffset = offset + 5;
        } else {
            val = Endian.reverse64(uint64(bytes8(buf[offset + 1:offset + 9])));
            newOffset = offset + 9;
        }
    }

    function parseVin(bytes calldata rawVin) public pure returns (Input[] memory inputs) {
        (uint256 nInputs, uint256 newOffset) = readVarInt(rawVin, 0);
        inputs = new Input[](nInputs);
        for (uint256 i; i < nInputs; ++i) {
            Input memory txIn;
            txIn.prevTxID = bytes32(rawVin[newOffset:newOffset + 32]);
            newOffset += 32;
            txIn.prevTxIndex = bytes4(rawVin[newOffset:newOffset + 4]);
            newOffset += 4;
            uint256 nInScriptBytes;
            (nInScriptBytes, newOffset) = readVarInt(rawVin, newOffset);

            if (nInScriptBytes > 32) {
                revert ScriptBytesTooLong();
            }

            txIn.scriptSig = rawVin[newOffset:newOffset + nInScriptBytes];
            newOffset += nInScriptBytes;
            txIn.sequence = Endian.reverse32(uint32(bytes4(rawVin[newOffset:newOffset + 4])));
            newOffset += 4;
            inputs[i] = txIn;
        }
    }

    function parseVout(bytes calldata rawVout) public pure returns (Output[] memory outputs) {
        (uint256 nOutputs, uint256 newOffset) = readVarInt(rawVout, 0);
        outputs = new Output[](nOutputs);
        for (uint256 i; i < nOutputs; ++i) {
            Output memory txOut;
            txOut.value = Endian.reverse64(uint64(bytes8(rawVout[newOffset:newOffset + 8])));
            newOffset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, newOffset) = readVarInt(rawVout, newOffset);

            txOut.scriptPubKey = rawVout[newOffset:newOffset + nOutScriptBytes];
            newOffset += nOutScriptBytes;
            outputs[i] = txOut;
        }
    }

    function paramToProof(ProofParam calldata proofParam) public view returns (ProofInfo memory) {
        (bytes4 version, bytes4 locktime, bytes memory rawVin, bytes memory rawVout) =
            parseRawTx(proofParam.rawTx);
        bytes32 merkleRoot = calculateMerkleRoot(proofParam.merkleProof);

        ProofInfo memory proofInfo = ProofInfo({
            version: version,
            locktime: locktime,
            txId: version.calculateTxId(
                rawVin.ref(uint40(ViewBTC.BTCTypes.Vin)),
                rawVout.ref(uint40(ViewBTC.BTCTypes.Vout)), locktime
            ),
            merkleRoot: merkleRoot,
            index: proofParam.index,
            header: proofParam.blockHeader,
            parents: proofParam.parents,
            children: proofParam.children,
            blockHeight: proofParam.blockHeight,
            rawVin: rawVin,
            rawVout: rawVout
        });

        return proofInfo;
    }

    function calculateMerkleRoot(bytes32[] memory txIds) public pure returns (bytes32) {
        while (txIds.length > 1) {
            if (txIds.length % 2 == 1) {
                // If odd number of elements, duplicate the last element
                bytes32[] memory extendedTxIds = new bytes32[](txIds.length + 1);
                for (uint256 i = 0; i < txIds.length; i++) {
                    extendedTxIds[i] = txIds[i];
                }
                extendedTxIds[txIds.length] = txIds[txIds.length - 1];
                txIds = extendedTxIds;
            }

            uint256 newLength = txIds.length / 2;
            bytes32[] memory tmp = new bytes32[](newLength);

            for (uint256 i = 0; i < txIds.length; i += 2) {
                tmp[i / 2] = hashPair(txIds[i], txIds[i + 1]).reverseBytes();
            }

            txIds = tmp;
        }

        return txIds[0];
    }

    function hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        bytes memory data = new bytes(64);

        for (uint256 i = 0; i < 32; i++) {
            data[i] = left[31 - i];
            data[32 + i] = right[31 - i];
        }
        return sha256(abi.encodePacked(sha256(data)));
    }

    function parseRawTx(bytes calldata rawTx)
        internal
        pure
        returns (bytes4 version, bytes4 locktime, bytes memory rawVin, bytes memory rawVout)
    {
        version = bytes4(rawTx[0:4]);
        uint256 offset = 6;
        uint256 nInputs;
        uint256 prevOffset = offset;
        (nInputs, offset) = readVarInt(rawTx, offset);
        for (uint256 i; i < nInputs; ++i) {
            offset += 36;
            uint256 nInScriptBytes;
            (nInScriptBytes, offset) = readVarInt(rawTx, offset);
            offset += uint32(nInScriptBytes);
            offset += 4;
        }
        rawVin = rawTx[prevOffset:offset];

        prevOffset = offset;
        // Read transaction outputs
        uint256 nOutputs;
        (nOutputs, offset) = readVarInt(rawTx, offset);
        for (uint256 i; i < nOutputs; ++i) {
            offset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, offset) = readVarInt(rawTx, offset);
            offset += nOutScriptBytes;
        }
        rawVout = rawTx[prevOffset:offset];
        prevOffset = offset;

        // Read transaction witness if exists
        uint256 nWitnesses;
        (nWitnesses, offset) = readVarInt(rawTx, offset);
        for (uint256 i; i < nWitnesses; ++i) {
            uint256 nWitnessItemBytes;
            (nWitnessItemBytes, offset) = readVarInt(rawTx, offset);
            offset += nWitnessItemBytes;
        }

        locktime = bytes4(rawTx[offset:offset + 4]);
    }
}
