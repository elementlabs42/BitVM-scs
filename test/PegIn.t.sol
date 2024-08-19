// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";
import "./mockup/BridgeTestnet.sol";
import "./Script.t.sol";

contract PegInTest is StorageFixture {
    function testPegIn_buildStorage() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        IStorage _storage = IStorage(fixture._storage);
        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, headers00.length / Coder.BLOCK_HEADER_LENGTH / step00 + 1);

        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(keyHash00, 0, keyTime00);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(height00 + step00);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testPegIn_pegIn_normal() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        ProofParam memory proofParam1 = getPegInProofParamNormal(1);
        ProofParam memory proofParam2 = getPegInProofParamNormal(2);

        ProofInfo memory proof1 = Util.paramToProof(proofParam1, false);
        ProofInfo memory proof2 = Util.paramToProof(proofParam2, false);

        Bridge bridge = Bridge(fixture.bridge);
        bridge.pegIn(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, DEPOSITOR_PUBKEY, proof1, proof2);
        assertEq(true, true);
    }

    function testPegIn_pegIn_file() public {
        if (!data.valid()) {
            console.log("Invalid Data file");
            return;
        }
        StorageSetupResult memory fixture = buildStorageFromDataFile(data._storage(data.pegInStorageKey()));

        ProofParam memory proofParam1 = data.proof(data.pegInProofKey("1"));
        ProofParam memory proofParam2 = data.proof(data.pegInProofKey("2"));

        ProofInfo memory proof1 = Util.paramToProof(proofParam1, false);
        ProofInfo memory proof2 = Util.paramToProof(proofParam2, false);

        Bridge bridge = Bridge(fixture.bridge);
        bridge.pegIn(data.depositor(), DEPOSITOR_PUBKEY, proof1, proof2);
        assertEq(true, true);
    }
}
