// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IBtcBridge.sol";
import "./EBTC.sol";
import "./libraries/ViewBTC.sol";
import "./libraries/ViewSPV.sol";
import "./libraries/Script.sol";
import {IStorage} from "./interfaces/IStorage.sol";
import {TransactionHelper} from "./libraries/TransactionHelper.sol";

contract BtcBridge is IBtcBridge {
    EBTC ebtc;
    IStorage blockStorage;
    uint256 target;
    bytes32 nOfNPubKey;

    using ViewBTC for bytes29;
    using ViewSPV for bytes32;
    using ViewSPV for bytes29;
    using ViewSPV for bytes4;
    using Script for bytes32;
    using Script for bytes;
    using TransactionHelper for bytes;
    using TypedMemView for bytes;

    /**
     * @dev withdrawer to pegout
     */
    mapping(address withdrawer => Pegout pegout) pegouts;
    /**
     * @dev back reference from an pegout to the withdrawer
     */
    mapping(bytes32 txId => mapping(uint256 txIndex => address withdrawer)) withdrawers;

    mapping(bytes32 txId => bool) pegins;

    uint256 private constant PEG_OUT_MAX_PENDING_TIME = 8 weeks;

    constructor(EBTC _ebtc, IStorage _blockStorage, uint256 _target, bytes32 _nOfNPubKey) {
        ebtc = _ebtc;
        blockStorage = _blockStorage;
        target = _target;
        nOfNPubKey = _nOfNPubKey;
    }

    function pegin(
        address evmAddress,
        bytes32 userPk,
        BtcTxProof calldata proof1,
        BtcTxProof calldata proof2
    ) external returns (bool) {
        require(is_pegin_valid(proof1.txId), "Pegged in invalid");
        bytes32 taproot = nOfNPubKey.generateDepositTaproot(evmAddress, userPk, 1 days);
        bytes memory multisigScript = nOfNPubKey.generatePreSignScriptAddress();

        OutputPoint[] memory vout1 =  proof1.rawVout.parseVout();
        InputPoint[] memory vin2 = proof2.rawVin.parseVin();
        OutputPoint[] memory vout2 = proof2.rawVout.parseVout();

        require(vout1.length == 1, "Invalid vout length");
        require(vout1[0].scriptPubKey.equal(abi.encodePacked(taproot)), "Invalid script key");

        bytes32 tx1Id = proof1.version.calculateTxId(proof1.rawVin.ref(0), proof1.rawVout.ref(0), proof1.locktime);

        require(vin2.length == 1, "Invalid vin length");
        require(vin2[0].prevTxID == tx1Id, "Mismatch transaction id");
        require(vout2[0].scriptPubKey.equal(multisigScript), "Mismatch multisig script");

        require(isValidAmount(vout2[0].value), "Invalid vout value");

        bytes32 tx2Id = proof2.version.calculateTxId(proof2.rawVin.ref(0), proof2.rawVout.ref(0), proof2.locktime);

        require(tx1Id == proof1.txId, "Mismatch transaction id");
        require(tx2Id == proof2.txId, "Mismatch transaction id");

        require(check_spv_proof(proof1), "Spv check failed");
        require(check_spv_proof(proof2), "Spv check failed");

        ebtc.mint(evmAddress, vout2[0].value);

        pegins[proof2.txId] = true;

        return true;

    }

    function check_spv_proof(BtcTxProof calldata proof) internal view returns (bool) {
        bytes29 header = proof.header.ref();
        bytes29 intermediateNodes = proof.intermediateNodes.ref(0);
        require(proof.txId.prove(proof.merkleRoot, intermediateNodes, proof.index), "Merkle proof failed");
        require(header.merkleRoot() == proof.merkleRoot, "Merkle root mismatch");
        require(header.checkWork(header.target()), "Difficulty mismatch");

        bytes32 prevHash = blockStorage.getKeyBlock(proof.blockIndex).blockHash;

        uint256 i;

        for (;i < proof.parents.length; i++) {
            bytes32 parent = proof.parents[i];
            require(header.checkParent(parent), "Parent check failed");
            header = parent.ref();
        }
        require(header.workHash() == prevHash, "Previous hash mismatch");

        bytes32 nextHash = blockStorage.getKeyBlock(proof.blockIndex + 1).blockHash;

        for (;i < proof.children.length; i++) {
            bytes32 child = proof.children[i];
            require(header.checkParent(child), "Parent check failed");
            header = child.ref();
        }
        require(header.workHash() == nextHash, "Next hash mismatch");

        // 3. Accumulated difficulty
        uint256 difficulty1 = blockStorage.getKeyBlock(proof.blockIndex + 1).accumulatedDifficulty;
        uint256 difficulty2 =  blockStorage.getFirstKeyBlock().accumulatedDifficulty;
        uint256 accumulatedDifficulty = difficulty2 - difficulty1;
        require(accumulatedDifficulty > target, "Insufficient accumulated difficulty");

        return true;
    }

    function is_pegin_valid(bytes32 txId)  internal view returns (bool) {
            return pegins[txId];
    }

    /**
    * @dev checks any given number is a power of 2
     */
    function isValidAmount(uint256 n) internal pure returns (bool) {
        return (n != 0) && ((n & (n - 1)) == 0);
    }
}
