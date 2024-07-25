// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";
import "../src/EBTC.sol";
import "../src/Bridge.sol";
import "../src/libraries/TransactionHelper.sol";
import "./Script.t.sol";

contract PegInTest is StorageFixture {
    function testPegIn_buildStorage() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        IStorage _storage = IStorage(buildStorage(initNormal));
        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, headers00.length / Coder.BLOCK_HEADER_LENGTH / step00 + 1);

        bytes4 expectedBits = bytes4(Endian.reverse32(bits00));
        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(keyHash00, 0, expectedBits, keyTime00);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(height00 + step00);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testPegIn_pegIn_normal() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        IStorage _storage = IStorage(buildStorage(initNormal));

        ProofInfo memory proof1 = TransactionHelper.paramToProof(getPegInProofParamNormal(1));
        ProofInfo memory proof2 = TransactionHelper.paramToProof(getPegInProofParamNormal(2));

        EBTC ebtc = new EBTC(address(0));
        bytes32 nOfNPubKey = hex"d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4";
        Bridge bridge = new Bridge(ebtc, _storage, Coder.toTarget(bytes4(bits00)), nOfNPubKey);
        ebtc.setBridge(address(bridge));

        bridge.pegIn(
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
            hex"edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b",
            proof1,
            proof2
        );
        assertEq(true, true);
    }
}
