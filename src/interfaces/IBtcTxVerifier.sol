// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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
 * @notice Proof that a transaction (rawTx) is in a given block.
 */
struct BtcTxProof {
    /**
     * @notice 80-byte block header.
     */
    bytes blockHeader;
    /**
     * @notice Bitcoin transaction ID, equal to SHA256(SHA256(rawTx))
     */
    // This is not gas-optimized--we could omit it and compute from rawTx. But
    //s the cost is minimal, and keeping it allows better revert messages.
    bytes32 txId;
    /**
     * @notice Index of transaction within the block.
     */
    uint256 txIndex;
    /**
     * @notice Merkle proof. Concatenated sibling hashes, 32*n bytes.
     */
    bytes txMerkleProof;
    /**
     * @notice Raw transaction, HASH-SERIALIZED, no witnesses.
     */
    bytes rawTx;
}

/**
 * @dev A parsed (but NOT fully validated) Bitcoin transaction.
 */
struct BitcoinTx {
    /**
     * @dev Whether we successfully parsed this Bitcoin TX, valid version etc.
     *      Does NOT check signatures or whether inputs are unspent.
     */
    bool validFormat;
    /**
     * @dev Version. Must be 1 or 2.
     */
    uint32 version;
    /**
     * @dev Each input spends a previous UTXO.
     */
    BitcoinTxIn[] inputs;
    /**
     * @dev Each output creates a new UTXO.
     */
    BitcoinTxOut[] outputs;
    /**
     * @dev Locktime. Either 0 for no lock, blocks if <500k, or seconds.
     */
    uint32 locktime;
}

struct BitcoinTxIn {
    /**
     * @dev Previous transaction.
     */
    uint256 prevTxID;
    /**
     * @dev Specific output from that transaction.
     */
    uint32 prevTxIndex;
    /**
     * @dev Mostly useless for tx v1, BIP68 Relative Lock Time for tx v2.
     */
    uint32 seqNo;
    /**
     * @dev Input script length
     */
    uint32 scriptLen;
    /**
     * @dev Input script, spending a previous UTXO. Over 32 bytes unsupported.
     */
    bytes32 script;
}

struct BitcoinTxOut {
    /**
     * @dev TXO value, in satoshis
     */
    uint64 valueSats;
    /**
     * @dev Output script length
     */
    uint32 scriptLen;
    /**
     * @dev Output script. Over 32 bytes unsupported.
     */
    bytes32 script;
}

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
     * Reads a Bitcoin-serialized varint = a u256 serialized in 1-9 bytes.
     */
    function readVarInt(bytes calldata buf, uint256 offset) external returns (uint256 val, uint256 newOffset);

    /**
     * @dev Verifies that `script` is a standard P2SH (pay to script hash) tx.
     * @return hash The recipient script hash, or 0 if verification failed.
     */
    function getP2SH(uint256 scriptLen, bytes32 script) external pure returns (bytes20);
}
