// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IBridge.sol";
import "./EBTC.sol";
import "./libraries/ViewBTC.sol";
import "./libraries/ViewSPV.sol";
import "./libraries/Script.sol";
import {IStorage} from "./interfaces/IStorage.sol";
import {TransactionHelper} from "./libraries/TransactionHelper.sol";

contract Bridge is IBridge {
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
     * @dev withdrawer to pegOut
     */
    mapping(address withdrawer => PegOutInfo info) pegOuts;
    /**
     * @dev back reference from an pegOut to the withdrawer
     */
    mapping(bytes32 txId => mapping(uint256 vOut => address withdrawer)) withdrawers;

    mapping(bytes32 txId => bool) pegIns;

    uint256 private constant PEG_OUT_MAX_PENDING_TIME = 8 weeks;

    bytes4 private version = 0x02000000;
    bytes4 private locktime = 0x00000000;

    constructor(EBTC _ebtc, IStorage _blockStorage, uint256 _target, bytes32 _nOfNPubKey) {
        ebtc = _ebtc;
        blockStorage = _blockStorage;
        target = _target;
        nOfNPubKey = _nOfNPubKey;
    }

    function pegIn(address depositor, bytes32 depositorPubKey, ProofInfo calldata proof1, ProofInfo calldata proof2)
        external
    {
        require(doesPegInExist(proof1.txId), "Pegged in invalid");

        Output[] memory vout1 = proof1.rawVout.parseVout();
        Input[] memory vin2 = proof2.rawVin.parseVin();
        Output[] memory vout2 = proof2.rawVout.parseVout();

        require(vout1.length == 1, "Invalid vout length");

        bytes32 taproot = nOfNPubKey.generateDepositTaprootAddress(depositor, depositorPubKey, 1 days);
        require(vout1[0].scriptPubKey.equals(abi.encodePacked(taproot)), "Invalid script key");

        bytes32 tx1Id = proof1.version.calculateTxId(proof1.rawVin.ref(0), proof1.rawVout.ref(0), proof1.locktime);

        require(vin2.length == 1, "Invalid vin length");
        require(vin2[0].prevTxID == tx1Id, "Mismatch transaction id");
        bytes memory multisigScript = nOfNPubKey.generatePreSignScriptAddress();
        require(vout2[0].scriptPubKey.equals(multisigScript), "Mismatch multisig script");

        if (!isValidAmount(vout2[0].value)) {
            revert InvalidVoutValue();
        }

        bytes32 tx2Id = proof2.version.calculateTxId(proof2.rawVin.ref(0), proof2.rawVout.ref(0), proof2.locktime);

        if (tx1Id != proof1.txId) {
            revert MismatchTransactionId();
        }
        if (tx2Id != proof2.txId) {
            revert MismatchTransactionId();
        }

        require(verifySPVProof(proof1), "Spv check failed");
        require(verifySPVProof(proof2), "Spv check failed");

        ebtc.mint(depositor, vout2[0].value);

        pegIns[proof2.txId] = true;
    }

    function pegOut(
        bytes calldata destinationBitcoinAddress,
        Outpoint calldata sourceOutpoint,
        uint256 amount,
        bytes calldata operatorPubkey
    ) external {
        if (!isValidAmount(amount)) {
            revert InvalidAmount();
        }
        if (
            pegOuts[msg.sender].status == PegOutStatus.PENDING
                || withdrawers[sourceOutpoint.txId][sourceOutpoint.vOut] != address(0)
        ) {
            revert PegOutInProgress();
        }
        pegOuts[msg.sender] = PegOutInfo(
            destinationBitcoinAddress,
            sourceOutpoint,
            amount,
            operatorPubkey,
            block.timestamp + PEG_OUT_MAX_PENDING_TIME,
            PegOutStatus.PENDING
        );
        withdrawers[sourceOutpoint.txId][sourceOutpoint.vOut] = msg.sender;

        ebtc.transferFrom(msg.sender, address(this), amount);
        emit PegOutInitiated(msg.sender, destinationBitcoinAddress, sourceOutpoint, amount, operatorPubkey);
    }

    function burnEBTC(address withdrawer, ProofInfo calldata proof) external {
        PegOutInfo memory info = pegOuts[withdrawer];
        if (info.status == PegOutStatus.VOID) {
            revert PegOutNotFound();
        }
        if (info.status == PegOutStatus.CLAIMED) {
            revert PegOutAlreadyClaimed();
        }
        if (info.status == PegOutStatus.BURNT) {
            revert PegOutAlreadyBurnt();
        }

        Output[] memory outputs = proof.rawVout.parseVout();
        if (outputs.length != 1) {
            revert InvalidPegOutProofOutputsSize();
        }
        if (outputs[0].scriptPubKey.equals(Script.generatePayToPubkeyScript(info.destinationAddress))) {
            revert InvalidPegOutProofScriptPubKey();
        }
        if (outputs[0].value != info.amount) {
            revert InvalidPegOutProofAmount();
        }
        bytes32 txId = ViewSPV.calculateTxId(version, bytes29(proof.rawVin), bytes29(proof.rawVout), locktime);
        if (proof.txId != txId) {
            revert InvalidPegOutProofTransactionId();
        }
        if (!verifySPVProof(proof)) {
            revert InvalidSPVProof();
        }

        pegOuts[withdrawer].status = PegOutStatus.BURNT;
        ebtc.burn(address(this), info.amount);
        emit PegOutBurnt(withdrawer, info.sourceOutpoint, info.amount, info.operatorPubkey);
    }

    function refundEBTC() external {
        PegOutInfo memory info = pegOuts[msg.sender];
        if (info.status == PegOutStatus.VOID) {
            revert PegOutNotFound();
        }
        if (info.status == PegOutStatus.CLAIMED) {
            revert PegOutAlreadyClaimed();
        }
        if (info.status == PegOutStatus.BURNT) {
            revert PegOutAlreadyBurnt();
        }
        if (info.claimAfter > block.timestamp) {
            revert PegOutInProgress();
        }
        pegOuts[msg.sender].status = PegOutStatus.CLAIMED;
        delete withdrawers[info.sourceOutpoint.txId][info.sourceOutpoint.vOut];
        ebtc.transfer(msg.sender, info.amount);
        emit PegOutClaimed(msg.sender, info.sourceOutpoint, info.amount, info.operatorPubkey);
    }

    function verifySPVProof(ProofInfo calldata proof) internal view returns (bool) {
        bytes29 header = proof.header.ref();
        bytes29 intermediateNodes = proof.merkleProof.ref(0);
        if (!proof.txId.prove(proof.merkleRoot, intermediateNodes, proof.index)) {
            revert MerkleProofFailed();
        }
        if (header.merkleRoot() != proof.merkleRoot) {
            revert MerkleRootMismatch();
        }
        if (!header.checkWork(header.target())) {
            revert DifficultyMismatch();
        }

        bytes32 prevHash = blockStorage.getKeyBlock(proof.blockHeight).blockHash;

        uint256 i;

        for (; i < proof.parents.length; i++) {
            bytes32 parent = proof.parents[i];
            if (!header.checkParent(parent)) {
                revert ParentCheckFailed();
            }
            header = parent.ref();
        }
        if (header.workHash() != prevHash) {
            revert PreviousHashMismatch();
        }

        bytes32 nextHash = blockStorage.getKeyBlock(proof.blockHeight + 1).blockHash;

        for (; i < proof.children.length; i++) {
            bytes32 child = proof.children[i];
            if (!header.checkParent(child)) {
                revert ParentCheckFailed();
            }
            header = child.ref();
        }
        if (header.workHash() != nextHash) {
            revert NextHashMismatch();
        }

        // 3. Accumulated difficulty
        uint256 difficulty1 = blockStorage.getKeyBlock(proof.blockHeight + 1).accumulatedDifficulty;
        uint256 difficulty2 = blockStorage.getFirstKeyBlock().accumulatedDifficulty;
        uint256 accumulatedDifficulty = difficulty2 - difficulty1;
        if (accumulatedDifficulty <= target) {
            revert InsufficientAccumulatedDifficulty();
        }

        return true;
    }

    function doesPegInExist(bytes32 txId) internal view returns (bool) {
        return pegIns[txId];
    }

    /**
     * @dev checks any given number is a power of 2
     */
    function isValidAmount(uint256 n) internal pure returns (bool) {
        return (n != 0) && ((n & (n - 1)) == 0);
    }
}
