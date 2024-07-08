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
    uint256 txIndex;
}

/**
 * @notice Proof that a transaction (rawTx) is in a given block.
 */
struct BtcTxProof {
    bytes32 txId;
    bytes32 userPubKey;
    bytes32 merkleRoot;
    bytes29 intermediateNodes;
    uint256 index;
    bytes29 header;
    bytes29[] parents;
    bytes29[] children;
    uint256 blockIndex;
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
     * @dev Marker. Must be 0 to indicate a segwit transaction.
     */
    uint8 marker;
    /**
     * @dev Flag. Must be 1 or greater.
     */
    uint8 flag;
    /**
     * @dev Each input spends a previous UTXO.
     */
    BitcoinTxIn[] inputs;
    /**
     * @dev Each output creates a new UTXO.
     */
    BitcoinTxOut[] outputs;
    /**
     * @dev Witness stack.
     */
    BitcoinTxWitness[] witnesses;
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
     * @dev Input script, spending a previous UTXO.
     */
    bytes script;
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
     * @dev Output script.
     */
    bytes script;
}

struct BitcoinTxWitness {
    /**
     * @dev Witness item size.
     */
    uint32 itemSize;
    /**
     * @dev Witness item.
     */
    bytes item;
}

enum PegoutStatus {
    VOID,
    PENDING,
    CLAIMED,
    BURNT
}

struct Pegout {
    bytes destinationAddress;
    Outpoint sourceOutpoint;
    uint256 amount;
    bytes operatorPubkey;
    uint256 claimAfter;
    PegoutStatus status;
}

/**
 * @notice Manage and gatekeeping EBTC in transit during peg in/out phases.
 */
interface IBtcBridge {
    event VerifyPegInDone();
    event PegoutInitiated(
        address indexed withdrawer,
        bytes destinationAddress,
        Outpoint sourceOutpoint,
        uint256 amount,
        bytes operatorPubkey
    );
    event PegoutClaimed(address indexed withdrawer, Outpoint sourceOutpoint, uint256 amount, bytes operatorPubkey);
    event PegoutBurned(address indexed withdrawer, Outpoint sourceOutpoint, uint256 amount, bytes operatorPubkey);

    error InvalidAmount();
    error PegoutNotFound();
    error PegoutInProgress();
    error PegoutAlreadyClaimed();
    error PegoutAlreadyBurnt();
}
