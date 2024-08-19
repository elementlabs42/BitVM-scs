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

struct ProofParam {
    bytes merkleProof;
    bytes parents;
    bytes children;
    bytes rawTx;
    uint256 index;
    uint256 blockHeight;
    bytes blockHeader;
}

/**
 * @notice Proof that a transaction (rawTx) is in a given block.
 */
struct ProofInfo {
    bytes4 version;
    bytes4 locktime;
    bytes merkleProof;
    bytes32 txId;
    uint256 index; // tx index in block
    bytes header;
    bytes parents;
    bytes children;
    uint256 blockHeight;
    bytes rawVin;
    bytes rawVout;
}

enum PegOutStatus {
    VOID,
    PENDING
}

struct PegOutInfo {
    string destinationAddress;
    Outpoint sourceOutpoint;
    uint256 amount;
    bytes32 operatorPubkey;
    uint256 pegOutTime;
    PegOutStatus status;
}

/**
 * @notice Manage and gatekeeping EBTC in transit during peg in/out phases.
 */
interface IBridge {
    event PegOutInitiated(
        address indexed withdrawer,
        string destinationAddress,
        Outpoint sourceOutpoint,
        uint256 amount,
        bytes32 operatorPubkey
    );
    event PegOutClaimed(address indexed withdrawer, Outpoint sourceOutpoint, uint256 amount, bytes32 operatorPubkey);
    event PegOutBurnt(address indexed withdrawer, Outpoint sourceOutpoint, uint256 amount, bytes32 operatorPubkey);

    error PegInInvalid();
    error SpvCheckFailed();
    error InvalidVoutLength();
    error InvalidScriptKey();
    error InvalidVinLength();
    error MismatchTransactionId();
    error MismatchMultisigScript();
    error InvalidVoutValue();
    error InvalidAmount();
    error MerkleRootMismatch();
    error DifficultyMismatch();
    error PreviousHashMismatch();
    error NextHashMismatch();
    error InsufficientAccumulatedDifficulty();
    error InvalidSPVProof();
    error PegOutNotFound();
    error PegOutInProgress();
    error UtxoNotAvailable(bytes32 txId, uint256 vOut, address withdrawer);
    error InvalidPegOutProofOutputsSize();
    error InvalidPegOutProofScriptPubKey();
    error InvalidPegOutProofAmount();
    error InvalidPegOutProofTransactionId();
}
