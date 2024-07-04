// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BitcoinTxIn, BitcoinTxOut, BitcoinTxWitness} from "./interfaces/IBtcBridge.sol";
import "./interfaces/IBtcMirror.sol";
import "./interfaces/IBtcTxVerifier.sol";
import "./libraries/Endian.sol";
import "forge-std/console.sol"; //TODO: delete me

//
//                                        #
//                                       # #
//                                      # # #
//                                     # # # #
//                                    # # # # #
//                                   # # # # # #
//                                  # # # # # # #
//                                 # # # # # # # #
//                                # # # # # # # # #
//                               # # # # # # # # # #
//                              # # # # # # # # # # #
//                                   # # # # # #
//                               +        #        +
//                                ++++         ++++
//                                  ++++++ ++++++
//                                    +++++++++
//                                      +++++
//                                        +
//
// BtcVerifier implements a merkle proof that a Bitcoin payment succeeded. It
// uses BtcMirror as a source of truth for which Bitcoin block hashes are in the
// canonical chain.
contract BtcTxVerifier is IBtcTxVerifier {
    error BlockNumberTooHigh();
    error NotEnoughBlockConfirmations();
    error InvalidTransactionProof();
    error BlockHashMismatch();
    error TxMerkleRootMismatch();
    error TxIdMismatch();
    error ScriptHashMismatch();
    error AmountMismatch();
    error WrongBlockHeaderLength();
    error ScriptBytesTooLong();

    IBtcMirror public immutable mirror;

    constructor(IBtcMirror _mirror) {
        mirror = _mirror;
    }

    function verifyPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx,
        bytes20 destScriptHash,
        uint256 amountSats
    ) external view returns (bool) {
        {
            uint256 mirrorHeight = mirror.getLatestBlockHeight();

            if (blockNum > mirrorHeight) {
                revert BlockNumberTooHigh();
            }

            if (minConfirmations + blockNum > mirrorHeight + 1) {
                revert NotEnoughBlockConfirmations();
            }
        }

        bytes32 blockHash = mirror.getBlockHash(blockNum);

        if (!validatePayment(blockHash, inclusionProof, txOutIx, destScriptHash, amountSats)) {
            revert InvalidTransactionProof();
        }

        return true;
    }

    /**
     * @dev Validates that a given payment appears under a given block hash.
     *
     * This verifies all of the following:
     * 1. Raw transaction really does pay X satoshis to Y script hash.
     * 2. Raw transaction hashes to the given transaction ID.
     * 3. Transaction ID appears under transaction root (Merkle proof).
     * 4. Transaction root is part of the block header.
     * 5. Block header hashes to a given block hash.
     *
     * The caller must separately verify that the block hash is in the chain.
     *
     * Always returns true or reverts with a descriptive reason.
     */
    function validatePayment(
        bytes32 blockHash,
        BtcTxProof calldata txProof,
        uint256 txOutIx,
        bytes20 destScriptHash,
        uint256 satoshisExpected
    ) internal pure returns (bool) {
        // 5. Block header to block hash
        if (blockHash != getBlockHash(txProof.blockHeader)) {
            revert BlockHashMismatch();
        }

        // 4. and 3. Transaction ID included in block
        bytes32 blockTxRoot = getBlockTxMerkleRoot(txProof.blockHeader);
        bytes32 txRoot = getTxMerkleRoot(txProof.outpoint.txId, txProof.outpoint.txIndex, txProof.txMerkleProof);
        if (txRoot != blockTxRoot) {
            revert TxMerkleRootMismatch();
        }

        // 2. Raw transaction to TxID
        if (txProof.outpoint.txId != getTxID(txProof.rawTx)) {
            revert TxIdMismatch();
        }

        // 1. Finally, validate raw transaction pays stated recipient.
        BitcoinTx memory parsedTx = parseBitcoinTx(txProof.rawTx);
        BitcoinTxOut memory txo = parsedTx.outputs[txOutIx];
        bytes20 actualScriptHash = getP2SH(txo.scriptLen, bytes32(txo.script));
        if (destScriptHash != actualScriptHash) {
            revert ScriptHashMismatch();
        }
        if (satoshisExpected != txo.valueSats) {
            revert AmountMismatch();
        }

        // We've verified that blockHash contains a P2SH transaction
        // that sends at least satoshisExpected to the given hash.
        return true;
    }

    /**
     * @dev Compute a block hash given a block header.
     */
    function getBlockHash(bytes calldata blockHeader) public pure returns (bytes32) {
        if (blockHeader.length != 80) {
            revert WrongBlockHeaderLength();
        }

        bytes32 ret = sha256(abi.encodePacked(sha256(blockHeader)));
        return bytes32(Endian.reverse256(uint256(ret)));
    }

    /**
     * @dev Get the transactions merkle root given a block header.
     */
    function getBlockTxMerkleRoot(bytes calldata blockHeader) public pure returns (bytes32) {
        if (blockHeader.length != 80) {
            revert WrongBlockHeaderLength();
        }
        return bytes32(blockHeader[36:68]);
    }

    /**
     * @dev Recomputes the transactions root given a merkle proof.
     */
    function getTxMerkleRoot(bytes32 txId, uint256 txIndex, bytes calldata siblings) public pure returns (bytes32) {
        bytes32 ret = bytes32(Endian.reverse256(uint256(txId)));
        uint256 len = siblings.length / 32;
        for (uint256 i = 0; i < len; i++) {
            bytes32 s = bytes32(Endian.reverse256(uint256(bytes32(siblings[i * 32:(i + 1) * 32]))));
            if (txIndex & 1 == 0) {
                ret = doubleSha(abi.encodePacked(ret, s));
            } else {
                ret = doubleSha(abi.encodePacked(s, ret));
            }
            txIndex = txIndex >> 1;
        }
        return ret;
    }

    /**
     * @dev Computes the ubiquitious Bitcoin SHA256(SHA256(x))
     */
    function doubleSha(bytes memory buf) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(buf)));
    }

    /**
     * @dev Recomputes the transaction ID for a raw transaction.
     */
    function getTxID(bytes calldata rawTransaction) public pure returns (bytes32) {
        bytes32 ret = doubleSha(rawTransaction);
        return bytes32(Endian.reverse256(uint256(ret)));
    }

    /**
     * @dev Parses a HASH-SERIALIZED Bitcoin transaction.
     *      This means no flags and no segwit witnesses.
     */
    function parseBitcoinTx(bytes calldata rawTx) public pure returns (BitcoinTx memory ret) {
        ret.version = Endian.reverse32(uint32(bytes4(rawTx[0:4])));
        if (ret.version < 1 || ret.version > 2) {
            return ret; // invalid version
        }

        // Read transaction inputs
        uint256 offset = 4;
        uint256 nInputs;
        (nInputs, offset) = readVarInt(rawTx, offset);
        ret.inputs = new BitcoinTxIn[](nInputs);
        for (uint256 i = 0; i < nInputs; i++) {
            BitcoinTxIn memory txIn;
            txIn.prevTxID = Endian.reverse256(uint256(bytes32(rawTx[offset:offset + 32])));
            offset += 32;
            txIn.prevTxIndex = Endian.reverse32(uint32(bytes4(rawTx[offset:offset + 4])));
            offset += 4;
            uint256 nInScriptBytes;
            (nInScriptBytes, offset) = readVarInt(rawTx, offset);

            if (nInScriptBytes > 32) {
                revert ScriptBytesTooLong();
            }

            txIn.scriptLen = uint32(nInScriptBytes);
            txIn.script = rawTx[offset:offset + nInScriptBytes];
            offset += nInScriptBytes;
            txIn.seqNo = Endian.reverse32(uint32(bytes4(rawTx[offset:offset + 4])));
            offset += 4;
            ret.inputs[i] = txIn;
        }

        // Read transaction outputs
        uint256 nOutputs;
        (nOutputs, offset) = readVarInt(rawTx, offset);
        ret.outputs = new BitcoinTxOut[](nOutputs);
        for (uint256 i = 0; i < nOutputs; i++) {
            BitcoinTxOut memory txOut;
            txOut.valueSats = Endian.reverse64(uint64(bytes8(rawTx[offset:offset + 8])));
            offset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, offset) = readVarInt(rawTx, offset);

            if (nOutScriptBytes > 32) {
                revert ScriptBytesTooLong();
            }

            txOut.scriptLen = uint32(nOutScriptBytes);
            txOut.script = rawTx[offset:offset + nOutScriptBytes];
            offset += nOutScriptBytes;
            ret.outputs[i] = txOut;
        }

        // Finally, read locktime, the last four bytes in the tx.
        ret.locktime = Endian.reverse32(uint32(bytes4(rawTx[offset:offset + 4])));
        offset += 4;
        if (offset != rawTx.length) {
            return ret; // Extra data at end of transaction.
        }

        // Parsing complete, sanity checks passed, return success.
        ret.validFormat = true;
        return ret;
    }

    /**
     * @dev Parses a Segregated Witness Bitcoin transaction.
     */
    function parseSegwitTx(bytes calldata rawTx) public pure returns (BitcoinTx memory ret) {
        // TODO: handle version bits?
        ret.version = Endian.reverse32(uint32(bytes4(rawTx[0:4])));
        if (ret.version < 1 || ret.version > 2) {
            return ret; // invalid version
        }
        ret.marker = uint8(rawTx[4]);
        if (ret.marker != 0) {
            return parseBitcoinTx(rawTx);
        }
        ret.flag = uint8(rawTx[5]);
        if (ret.flag < 1) {
            return ret; // invalid flag
        }

        // Read transaction inputs
        uint256 offset = 6;
        uint256 nInputs;
        (nInputs, offset) = readVarInt(rawTx, offset);
        ret.inputs = new BitcoinTxIn[](nInputs);
        for (uint256 i = 0; i < nInputs; i++) {
            BitcoinTxIn memory txIn;
            txIn.prevTxID = Endian.reverse256(uint256(bytes32(rawTx[offset:offset + 32])));
            offset += 32;
            txIn.prevTxIndex = Endian.reverse32(uint32(bytes4(rawTx[offset:offset + 4])));
            offset += 4;
            uint256 nInScriptBytes;
            (nInScriptBytes, offset) = readVarInt(rawTx, offset);

            txIn.scriptLen = uint32(nInScriptBytes);
            txIn.script = rawTx[offset:offset + nInScriptBytes];
            offset += nInScriptBytes;
            txIn.seqNo = Endian.reverse32(uint32(bytes4(rawTx[offset:offset + 4])));
            offset += 4;
            ret.inputs[i] = txIn;
        }

        // Read transaction outputs
        uint256 nOutputs;
        (nOutputs, offset) = readVarInt(rawTx, offset);
        ret.outputs = new BitcoinTxOut[](nOutputs);
        for (uint256 i = 0; i < nOutputs; i++) {
            BitcoinTxOut memory txOut;
            txOut.valueSats = Endian.reverse64(uint64(bytes8(rawTx[offset:offset + 8])));
            offset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, offset) = readVarInt(rawTx, offset);

            txOut.scriptLen = uint32(nOutScriptBytes);
            txOut.script = rawTx[offset:offset + nOutScriptBytes];
            offset += nOutScriptBytes;
            ret.outputs[i] = txOut;
        }

        // Read transaction witness if exists
        uint256 nWitnesses;
        (nWitnesses, offset) = readVarInt(rawTx, offset);
        ret.witnesses = new BitcoinTxWitness[](nWitnesses);
        for (uint256 i = 0; i < nWitnesses; i++) {
            BitcoinTxWitness memory txWitness;
            uint256 nWitnessItemBytes;
            (nWitnessItemBytes, offset) = readVarInt(rawTx, offset);
            txWitness.itemSize = uint32(nWitnessItemBytes);
            txWitness.item = rawTx[offset:offset + nWitnessItemBytes];
            offset += nWitnessItemBytes;
            ret.witnesses[i] = txWitness;
        }

        // Finally, read locktime, the last four bytes in the tx.
        ret.locktime = Endian.reverse32(uint32(bytes4(rawTx[offset:offset + 4])));
        offset += 4;
        if (offset != rawTx.length) {
            return ret; // Extra data at end of transaction.
        }

        // Parsing complete, sanity checks passed, return success.
        ret.validFormat = true;
        return ret;
    }

    /**
     * Reads a Bitcoin-serialized varint = a u256 serialized in 1-9 bytes.
     */
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
            // pivot == 0xff
            val = Endian.reverse64(uint64(bytes8(buf[offset + 1:offset + 9])));
            newOffset = offset + 9;
        }
    }

    /**
     * @dev Verifies that `script` is a standard P2SH (pay to script hash) tx.
     * @return hash The recipient script hash, or 0 if verification failed.
     */
    function getP2SH(uint256 scriptLen, bytes32 script) public pure returns (bytes20) {
        if (scriptLen != 23) {
            return 0;
        }
        if (script[0] != 0xa9 || script[1] != 0x14 || script[22] != 0x87) {
            return 0;
        }
        uint256 sHash = (uint256(script) >> 80) & 0x00ffffffffffffffffffffffffffffffffffffffff;
        return bytes20(uint160(sHash));
    }
}
