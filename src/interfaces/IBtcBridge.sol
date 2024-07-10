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


/**
 * @notice Proof that a transaction (rawTx) is in a given block.
 */
struct BtcTxProof {
    bytes32 txId;
    bytes32 userPubKey;
    bytes32 merkleRoot;
    bytes intermediateNodes;
    uint256 index;
    bytes32 header;
    bytes32[] parents;
    bytes32[] children;
    uint256 blockIndex;
    bytes rawTx;
}

enum PegoutStatus {
    VOID,
    PENDING,
    CLAIMED,
    BURNT
}

struct Pegout {
    bytes destinationAddress;
    uint256 amount;
    bytes operatorPubkey;
    uint256 claimAfter;
    PegoutStatus status;
}

/**
 * @notice Manage and gatekeeping EBTC in transit during peg in/out phases.
 */
interface IBtcBridge {
    error InvalidAmount();
    error PegoutNotFound();
    error PegoutInProgress();
    error PegoutAlreadyClaimed();
    error PegoutAlreadyBurnt();
}
