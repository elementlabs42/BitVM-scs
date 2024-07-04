// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BtcTxProof, BitcoinTx} from "./IBtcBridge.sol";
import "./IBtcMirror.sol";

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
// IBtcTxVerifier provides functions to prove things about Bitcoin transactions.
// Verifies merkle inclusion proofs, transaction IDs, and payment details.

/**
 * @notice Verifies Bitcoin transaction proofs.
 */
interface IBtcTxVerifier {
    /**
     * @notice Verifies that a transaction has been cleared, paying a given amount to
     *         a given address. Specifically, verifies a proof that the tx was
     *         in block N, and that block N has at least M confirmations.
     */
    function verifyPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx,
        bytes20 destScriptHash,
        uint256 amountSats
    ) external view returns (bool);

    /**
     * @notice Returns the underlying mirror associated with this verifier.
     */
    function mirror() external view returns (IBtcMirror);

    /**
     * @dev Compute a block hash given a block header.
     */
    function getBlockHash(bytes calldata blockHeader) external returns (bytes32);

    /**
     * @dev Get the transactions merkle root given a block header.
     */
    function getBlockTxMerkleRoot(bytes calldata blockHeader) external returns (bytes32);

    /**
     * @dev Recomputes the transactions root given a merkle proof.
     */
    function getTxMerkleRoot(bytes32 txId, uint256 txIndex, bytes calldata siblings) external returns (bytes32);

    /**
     * @dev Recomputes the transaction ID for a raw transaction.
     */
    function getTxID(bytes calldata rawTransaction) external returns (bytes32);

    /**
     * @dev Parses a HASH-SERIALIZED Bitcoin transaction.
     *      This means no flags and no segwit witnesses.
     */
    function parseBitcoinTx(bytes calldata rawTx) external returns (BitcoinTx memory ret);

    /**
     * @dev Parses a Segregated Witness Bitcoin transaction.
     */
    function parseSegwitTx(bytes calldata rawTx) external returns (BitcoinTx memory ret);

    /**
     * Reads a Bitcoin-serialized varint = a u256 serialized in 1-9 bytes.
     */
    function readVarInt(bytes calldata buf, uint256 offset) external returns (uint256 val, uint256 newOffset);

    /**
     * @dev Verifies that `script` is a standard P2SH (pay to script hash) tx.
     * @return hash The recipient script hash, or 0 if verification failed.
     */
    function getP2SH(uint256 scriptLen, bytes32 script) external pure returns (bytes20);
}
