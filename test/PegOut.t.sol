// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";
import "../src/Bridge.sol";
import "./utils/Util.sol";

contract PegOutTest is StorageFixture {
    function testPegOut_buildStorage() public {
        StorageSetupInfo memory initNormal = getPegOutSetupInfoNormal();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        string memory json = vm.readFile("test/fixture/test-data.json");
        uint256 step = abi.decode(vm.parseJson(json, ".pegOut.storage.constrcutor.step"), (uint256));
        bytes memory headers = abi.decode(vm.parseJson(json, ".pegOut.storage.submit[0].headers"), (bytes));

        IStorage _storage = IStorage(fixture._storage);
        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, headers.length / Coder.BLOCK_HEADER_LENGTH / step + 1);
    }

    function testPegOut_pegOut_normal() public {
        StorageSetupInfo memory initNormal = getPegOutSetupInfoNormal();
        StorageSetupResult memory fixture = buildStorage(initNormal);
        string memory json = vm.readFile("test/fixture/test-data.json");
        uint32 pegoutTimestamp = uint32(abi.decode(vm.parseJson(json, ".pegOut.pegOutTimestamp"), (uint256)));
        Bridge bridge = Bridge(fixture.bridge);
        address withdrawer = fixture.withdrawer;
        address operator = fixture.operator;
        ProofParam memory proofParam = getPegOutProofParamNormal();
        ProofInfo memory proof = Util.paramToProof(proofParam, false);

        string memory withdrawerAddr = Util.generateAddress(WITHDRAWER_PUBKEY, Util.P2PKH_TESTNET);
        vm.warp(pegoutTimestamp);
        vm.startPrank(withdrawer);
        bridge.pegOut(withdrawerAddr, Outpoint(hex"1234", 0), 100000, OPERATOR_PUBKEY);
        vm.stopPrank();

        vm.prank(operator);
        bridge.burnEBTC(withdrawer, proof);
    }

    function testPegOut_pegOut_insufficientAccumulatedDifficulty() public {
        StorageSetupInfo memory initNormal = getPegOutSetupInfoNormal();
        ProofParam memory proofParam = getPegOutProofParamNormal();
        uint256 nextKeyBlockIndex = (proofParam.blockHeight - initNormal.height) / initNormal.step + 1;
        uint256 nextKeyBlockHeight = initNormal.step * nextKeyBlockIndex + initNormal.height;
        uint256 insufficientStorageLength = (nextKeyBlockHeight - initNormal.height) * Coder.BLOCK_HEADER_LENGTH;
        initNormal.headers = Util.slice(initNormal.headers, 0, insufficientStorageLength);
        StorageSetupResult memory fixture = buildStorage(initNormal);

        Bridge bridge = Bridge(fixture.bridge);
        address withdrawer = fixture.withdrawer;
        address operator = fixture.operator;
        ProofInfo memory proof = Util.paramToProof(proofParam, false);
        string memory json = vm.readFile("test/fixture/test-data.json");
        uint32 pegoutTimestamp = uint32(abi.decode(vm.parseJson(json, ".pegOut.pegOutTimestamp"), (uint256)));
        string memory withdrawerAddr = Util.generateAddress(WITHDRAWER_PUBKEY, Util.P2PKH_TESTNET);
        vm.warp(pegoutTimestamp);
        vm.startPrank(withdrawer);
        bridge.pegOut(withdrawerAddr, Outpoint(hex"1234", 0), 100000, OPERATOR_PUBKEY);
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IBridge.InsufficientAccumulatedDifficulty.selector));
        bridge.burnEBTC(withdrawer, proof);
    }
}
