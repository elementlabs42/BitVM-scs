// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";
import "../src/Bridge.sol";
import "../src/libraries/TransactionHelper.sol";
import "./Script.t.sol";

contract PegInTest is StorageFixture {
    function testPegIn_buildStorage() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        IStorage _storage = IStorage(fixture._storage);
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
        StorageSetupResult memory fixture = buildStorage(initNormal);

        ProofParam memory proof1 = getPegInProofParamNormal(1);
        ProofParam memory proof2 = getPegInProofParamNormal(2);

        Bridge bridge = Bridge(fixture.bridge);
        bridge.pegIn(
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
            hex"edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b",
            proof1,
            proof2
        );
        assertEq(true, true);
    }
}
