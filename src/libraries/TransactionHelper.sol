// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma experimental ABIEncoderV2;

import "./Endian.sol";
import "../interfaces/IBridge.sol";

library TransactionHelper {
    error ScriptBytesTooLong();

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

    function paramToProof(ProofParam calldata proofParam) public pure returns (ProofInfo memory) {
        (bytes4 version, bytes4 locktime, bytes32 txId, bytes memory rawVin, bytes memory rawVout) =
            parseRawTx(proofParam.rawTx);
        bytes32 merkleRoot = calculateMerkleRoot(proofParam.merkleProof);

        ProofInfo memory proofInfo = ProofInfo({
            version: version,
            locktime: locktime,
            txId: txId,
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

    function calculateMerkleRoot(bytes32[] calldata merkleProof) internal pure returns (bytes32) {
        bytes32 hash = merkleProof[0];

        for (uint256 i = 1; i < merkleProof.length; i++) {
            bytes32 proofElement = merkleProof[i];

            if (i % 2 == 1) {
                hash = sha256(abi.encodePacked(hash, proofElement));
            } else {
                hash = sha256(abi.encodePacked(proofElement, hash));
            }
        }

        return hash;
    }

    function parseRawTx(bytes calldata rawTx)
        internal
        pure
        returns (bytes4 version, bytes4 locktime, bytes32 txId, bytes memory rawVin, bytes memory rawVout)
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

        txId = sha256(abi.encodePacked(sha256(rawTx)));
        locktime = bytes4(rawTx[offset:offset + 4]);
    }
}
