// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IBridge.sol";
import "./interfaces/IStorage.sol";
import "./libraries/ViewBTC.sol";
import "./libraries/ViewSPV.sol";
import "./libraries/Script.sol";
import "./libraries/Coder.sol";
import "./EBTC.sol";

contract Bridge is IBridge {
    using ViewBTC for bytes29;
    using ViewSPV for bytes32;
    using ViewSPV for bytes29;
    using ViewSPV for bytes4;
    using Script for bytes;
    using Script for bytes32;
    using Script for string;
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    uint256 private constant PEG_OUT_MAX_PENDING_TIME = 8 weeks;
    uint256 public immutable difficultyThreshold;
    uint32 public immutable pegInTimelock;

    /**
     * @dev withdrawer to pegOut
     */
    mapping(address withdrawer => PegOutInfo info) pegOuts;
    /**
     * @dev back reference from an pegOut to the withdrawer
     */
    mapping(bytes32 txId => mapping(uint256 vOut => address withdrawer)) usedUtxos;
    mapping(bytes32 txId => bool) pegIns;
    EBTC ebtc;
    IStorage blockStorage;
    bytes32 nOfNPubKey;
    bytes4 private version = 0x02000000;
    bytes4 private locktime = 0x00000000;

    constructor(EBTC _ebtc, IStorage _blockStorage, bytes32 _nOfNPubKey) {
        ebtc = _ebtc;
        blockStorage = _blockStorage;
        nOfNPubKey = _nOfNPubKey;
        // difficult from block 855614(90666502495565) and 2016 blocks two weeks
        difficultyThreshold = 182783669031059040;
        // two weeks block count
        pegInTimelock = 2016;
    }

    function pegIn(address depositor, bytes32 depositorPubKey, ProofInfo calldata proof1, ProofInfo calldata proof2)
        external
    {
        if (isPegInExist(proof1.txId)) {
            revert PegInInvalid();
        }

        bytes29 vout1 = proof1.rawVout.ref(uint40(ViewBTC.BTCTypes.Vout));
        bytes29 vout2 = proof2.rawVout.ref(uint40(ViewBTC.BTCTypes.Vout));
        bytes29 vin2 = proof2.rawVin.ref(uint40(ViewBTC.BTCTypes.Vin));
        if (vout1.voutCount() != 1 || vout2.voutCount() != 1) {
            revert InvalidVoutLength();
        }

        if (vin2.vinCount() != 1) {
            revert InvalidVinLength();
        }

        bytes29 txOut1 = vout1.indexVout(0);
        bytes29 txOut2 = vout2.indexVout(0);
        bytes29 txIn2 = vin2.indexVin(0);
        bytes32 taproot1 = nOfNPubKey.generateDepositTaprootAddress(depositor, depositorPubKey, pegInTimelock);
        if (!txOut1.scriptPubkeyWithoutLength().equals(taproot1.convertToScriptPubKey())) {
            revert ScriptKeyMismatch();
        }

        if (txIn2.outpoint().txidLE() != proof1.txId) {
            revert TransactionIdMismatch();
        }

        bytes32 taproot2 = nOfNPubKey.generateConfirmTaprootAddress();
        if (!txOut2.scriptPubkeyWithoutLength().equals(taproot2.convertToScriptPubKey())) {
            revert MultisigScriptMismatch();
        }
        uint64 txOut2Value = txOut2.value();
        if (!isValidAmount(txOut2Value)) {
            revert InvalidVoutValue();
        }
        if (!verifySPVProof(proof1) || !verifySPVProof(proof2)) {
            revert SpvCheckFailed();
        }

        ebtc.mint(depositor, txOut2Value);

        pegIns[proof1.txId] = true;

        emit PegInMinted(depositor, txOut2Value, depositorPubKey);
    }

    function pegOut(
        string calldata destinationBitcoinAddress,
        Outpoint calldata sourceOutpoint,
        uint256 amount,
        bytes calldata operatorPubkey
    ) external override {
        if (!isValidAmount(amount)) {
            revert InvalidAmount();
        }
        if (pegOuts[msg.sender].status == PegOutStatus.PENDING) {
            revert PegOutInProgress();
        }
        if (usedUtxos[sourceOutpoint.txId][sourceOutpoint.vOut] != address(0)) {
            revert UtxoNotAvailable(
                sourceOutpoint.txId, sourceOutpoint.vOut, usedUtxos[sourceOutpoint.txId][sourceOutpoint.vOut]
            );
        }
        pegOuts[msg.sender] = PegOutInfo(
            destinationBitcoinAddress, sourceOutpoint, amount, operatorPubkey, block.timestamp, PegOutStatus.PENDING
        );
        usedUtxos[sourceOutpoint.txId][sourceOutpoint.vOut] = msg.sender;

        ebtc.transferFrom(msg.sender, address(this), amount);
        emit PegOutInitiated(msg.sender, destinationBitcoinAddress, sourceOutpoint, amount, operatorPubkey);
    }

    function burnEBTC(address withdrawer, ProofInfo calldata proof) external override {
        PegOutInfo memory info = pegOuts[withdrawer];
        if (info.status == PegOutStatus.VOID) {
            revert PegOutNotFound();
        }

        bytes29 vout = proof.rawVout.ref(uint40(ViewBTC.BTCTypes.Vout));
        if (vout.voutCount() != 1) {
            revert InvalidPegOutProofOutputsSize();
        }

        bytes29 txOut = vout.indexVout(0);
        bytes memory inscriptionScript =
            info.destinationAddress.generatePayToPubKeyHashWithInscriptionScript(uint32(info.pegOutTime), withdrawer);
        if (!txOut.scriptPubkeyWithoutLength().equals(inscriptionScript.generateP2WSHScriptPubKey())) {
            revert InvalidPegOutProofScriptPubKey();
        }
        if (txOut.value() != info.amount) {
            revert InvalidPegOutProofAmount();
        }
        bytes32 txId = ViewSPV.calculateTxId(
            version,
            proof.rawVin.ref(uint40(ViewBTC.BTCTypes.Vin)),
            proof.rawVout.ref(uint40(ViewBTC.BTCTypes.Vout)),
            locktime
        );
        if (proof.txId != txId) {
            revert InvalidPegOutProofTransactionId();
        }
        if (!verifySPVProof(proof)) {
            revert InvalidSPVProof();
        }

        delete pegOuts[withdrawer];
        ebtc.burn(address(this), info.amount);
        emit PegOutBurnt(withdrawer, info.sourceOutpoint, info.amount, info.operatorPubkey);
    }

    function refundEBTC() external override {
        PegOutInfo memory info = pegOuts[msg.sender];
        if (info.status == PegOutStatus.VOID) {
            revert PegOutNotFound();
        }
        if (info.pegOutTime + PEG_OUT_MAX_PENDING_TIME > block.timestamp) {
            revert PegOutInProgress();
        }
        delete pegOuts[msg.sender];
        delete usedUtxos[info.sourceOutpoint.txId][info.sourceOutpoint.vOut];
        ebtc.transfer(msg.sender, info.amount);
        emit PegOutClaimed(msg.sender, info.sourceOutpoint, info.amount, info.operatorPubkey);
    }

    function verifySPVProof(ProofInfo memory proof) internal view returns (bool) {
        bytes29 header = proof.header.ref(uint40(ViewBTC.BTCTypes.Header));
        bytes32 merkleRoot =
            ViewBTC.getMerkle(proof.txId, proof.merkleProof.ref(uint40(ViewBTC.BTCTypes.MerkleArray)), proof.index);
        if (header.merkleRoot() != merkleRoot) {
            revert MerkleRootMismatch();
        }
        if (!header.checkWork(header.target())) {
            revert DifficultyMismatch();
        }

        bytes32 prevHash = blockStorage.getKeyBlock(proof.blockHeight).blockHash;
        bytes29 parentHeader = abi.encodePacked(proof.parents, proof.header).ref(uint40(ViewBTC.BTCTypes.HeaderArray));
        parentHeader.checkChain();
        if (
            proof.parents.ref(uint40(ViewBTC.BTCTypes.HeaderArray)).indexHeaderArray(0).workHash()
                != bytes32(Endian.reverse256(uint256(prevHash)))
        ) {
            revert PreviousHashMismatch();
        }

        bytes32 nextHash = blockStorage.getNextKeyBlock(proof.blockHeight).blockHash;
        bytes29 childHeader = abi.encodePacked(proof.header, proof.children).ref(uint40(ViewBTC.BTCTypes.HeaderArray));
        childHeader.checkChain();
        if (
            childHeader.indexHeaderArray(childHeader.len() / 80 - 1).workHash()
                != bytes32(Endian.reverse256(uint256(nextHash)))
        ) {
            revert NextHashMismatch();
        }

        // 3. Accumulated difficulty
        uint256 difficulty1 = blockStorage.getNextKeyBlock(proof.blockHeight).accumulatedDifficulty;
        uint256 difficulty2 = blockStorage.getLastKeyBlock().accumulatedDifficulty;
        uint256 accumulatedDifficulty = difficulty2 - difficulty1;
        if (accumulatedDifficulty <= difficultyThreshold) {
            revert InsufficientAccumulatedDifficulty();
        }

        return true;
    }

    function isPegInExist(bytes32 txId) internal view returns (bool) {
        return pegIns[txId];
    }

    /**
     * @dev checks any given number is a power of 2
     */
    function isValidAmount(uint256 n) internal pure returns (bool) {
        return (n != 0) && ((n & (n - 1)) == 0);
    }
}
