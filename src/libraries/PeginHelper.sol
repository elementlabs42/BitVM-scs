pragma solidity >=0.5.10;
import "./SafeMath.sol";
import {TaprootHelper} from "./TaprootHelper.sol";

library  PeginHelper {
    using SafeMath for uint256;
    using TaprootHelper for bytes32;

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
         * @notice Raw transaction.
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


    function generatePreSignScript(bytes32 nOfNPubkey) internal pure returns (bytes memory) {
        return abi.encodePacked(nOfNPubkey, " CHECKSIG");
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

    function generateDepositTaproot(bytes32 nOfNPubkey , address evmAddress, bytes32 userPk, uint256 lockDuration) internal view returns (bytes32) {
        bytes memory depositScript = generateDepositScript(nOfNPubkey, evmAddress);
        bytes memory timelockScript = generateTimelockLeaf(userPk, lockDuration);
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = depositScript;
        scripts[1] = timelockScript;
        return nOfNPubkey.createTaprootAddress(scripts);
    }

    function validatePeginProof(bytes32 nOfNPubkey, address evmAddress, BtcTxProof memory proof1, BtcTxProof memory proof2) internal pure returns (bool) {
        // todo: do all proof verification logic here
        return true;
    }
}
