// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct Block {
    uint32 version;
    uint32 timestamp;
    bytes4 bits; // reversed order
    uint32 nonce;
    bytes32 previousBlockHash; // natural order
    bytes32 merkleRoot; // natural order
}

struct Outpoint {
    /**
     * @notice Bitcoin transaction ID, equal to SHA256(SHA256(rawTx))
     */
    bytes32 txId;
    /**
     * @notice Index of transaction within the block.
     */
    uint256 vOut;
}

struct InputPoint {
   bytes32 prevTxID;
   bytes4 prevTxIndex;
   bytes scriptSig;
   uint32 sequence;
}

struct OutputPoint {
   uint64 value;
   bytes scriptPubKey;
}

/**
 * @notice Proof that a transaction (rawTx) is in a given block.
 */
struct BtcTxProof {
    bytes4 version;
    bytes4 locktime;
    bytes32 txId;
    bytes32 merkleRoot;
    uint256 index;
    bytes32 header;
    bytes32[] parents;
    bytes32[] children;
    uint256 blockIndex;
    bytes rawVin;
    bytes rawVout;
    bytes intermediateNodes;
}

enum PegOutStatus {
    VOID,
    PENDING,
    CLAIMED,
    BURNT
}

struct PegOutInfo {
    bytes destinationAddress;
    Outpoint sourceOutpoint;
    uint256 amount;
    bytes operatorPubkey;
    uint256 claimAfter;
    PegOutStatus status;
}

/**
 * @notice Manage and gatekeeping EBTC in transit during peg in/out phases.
 */
interface IBtcBridge {
    event PegOutInitiated(
        address indexed withdrawer,
        bytes destinationAddress,
        Outpoint sourceOutpoint,
        uint256 amount,
        bytes operatorPubkey
    );
    event PegOutClaimed(address indexed withdrawer, Outpoint sourceOutpoint, uint256 amount, bytes operatorPubkey);
    event PegOutBurned(address indexed withdrawer, Outpoint sourceOutpoint, uint256 amount, bytes operatorPubkey);

    error InvalidSPVProof();
    error InvalidAmount();
    error PegOutNotFound();
    error PegOutInProgress();
    error PegOutAlreadyClaimed();
    error PegOutAlreadyBurnt();
    error InvalidPegOutProofOutputsSize();
    error InvalidPegOutProofScriptPubKey();
    error InvalidPegOutProofAmount();
    error InvalidPegOutProofTransactionId();
}
