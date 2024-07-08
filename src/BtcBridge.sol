// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IBtcBridge.sol";
import "./EBTC.sol";
import "./BtcTxVerifier.sol";
import "./libraries/ViewBTC.sol";
import "./libraries/ViewSPV.sol";
import "./libraries/Script.sol";
import {IStorage} from "./interfaces/IStorage.sol";

contract BtcBridge is IBtcBridge {
    EBTC ebtc;
    BtcTxVerifier btcTxVerifier;
    IStorage blockStorage;
    uint256 target;
    bytes32 nOfNPubKey;

    using ViewBTC for bytes29;
    using ViewSPV for bytes32;
    using ViewSPV for bytes29;
    using Script for bytes32;

    /**
     * @dev withdrawer to pegout
     */
    mapping(address withdrawer => Pegout pegout) pegouts;
    /**
     * @dev back reference from an pegout to the withdrawer
     */
    mapping(bytes32 txId => mapping(uint256 txIndex => address withdrawer)) withdrawers;

    uint256 private constant PEG_OUT_MAX_PENDING_TIME = 8 weeks;

    constructor(EBTC _ebtc, BtcTxVerifier _btcTxVerifier, IStorage _blockStorage, uint256 _target, bytes32 _nOfNPubKey) {
        ebtc = _ebtc;
        btcTxVerifier = _btcTxVerifier;
        blockStorage = _blockStorage;
        target = _target;
        nOfNPubKey = _nOfNPubKey;
    }

    function pegin(
        address evmAddress,
        BtcTxProof calldata proof1,
        BtcTxProof calldata proof2
    ) external returns (bool) {
        require(is_pegin_valid(proof1.txId), "Pegged in invalid");
        bytes32 userPk = proof1.userPubKey;
        bytes32 taproot = nOfNPubKey.generateDepositTaproot(nOfNPubKey, evmAddress, userPk, 1 days);

        BitcoinTx memory tx1 = IBtcTxVerifier.parseSegwitTx(proof1.rawTx);
        BitcoinTx memory tx2 = IBtcTxVerifier.parseSegwitTx(proof2.rawTx);

        require(tx1.outputs.length == 1, "Vout length invalid");
        require(tx2.inputs.length == 1, "Vin length invalid");
        //todo: check script pubkey is equal to taproot

        IBtcTxVerifier.getTxID(proof1.rawTx);

        return true;

    }

    function check_spv_proof(BtcTxProof memory proof) internal view returns (bool) {
        require(proof.txId.prove(proof.merkleRoot, proof.intermediateNodes, proof.index), "Merkle proof failed");
        require(proof.header.merkleRoot() == proof.merkleRoot, "Merkle root mismatch");
        require(proof.header.checkWork(proof.header.target()), "Difficulty mismatch");

        bytes32 prevHash = blockStorage.getKeyBlock(proof.blockIndex).blockHash;
        bytes29 header = proof.header;

        uint256 i;

        for (;i < proof.parents.length; i++) {
            require(header.checkParent(proof.parents[i]), "Parent check failed");
            header = proof.parents[i];
        }
        require(header.workHash() == prevHash, "Previous hash mismatch");

        bytes32 nextHash = blockStorage.getKeyBlock(proof.blockIndex + 1).blockHash;
        header = proof.header;

        for (;i < proof.children.length; i++) {
            require(header.checkParent(proof.children[i]), "Parent check failed");
            header = proof.children[i];
        }
        require(header.workHash() == nextHash, "Next hash mismatch");

        // 3. Accumulated difficulty
        uint256 difficulty1 = blockStorage.getKeyBlock(proof.blockIndex + 1).accumulatedDifficulty;
        uint256 difficulty2 =  blockStorage.getFirstKeyBlock().accumulatedDifficulty;
        uint256 accumulatedDifficulty = difficulty2 - difficulty1;
        require(accumulatedDifficulty > target, "Insufficient accumulated difficulty");

        return true;
    }

    function is_pegin_valid(bytes32 txId)  internal returns (bool) {

    }
}
