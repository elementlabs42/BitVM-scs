// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";
import "../src/Bridge.sol";
import "../src/libraries/TransactionHelper.sol";
import "./Script.t.sol";

contract PegOutTest is StorageFixture {
    function testPegOut_buildStorage() public {
        StorageSetupInfo memory initNormal = getPegOutSetupInfoNormal();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        IStorage _storage = IStorage(fixture._storage);
        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, headers01.length / Coder.BLOCK_HEADER_LENGTH / step01 + 1);

        bytes4 expectedBits = bytes4(Endian.reverse32(bits01));
        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(keyHash01, 0, expectedBits, keyTime01);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(keyHeight01);
        IStorage.KeyBlock memory actualKeyBlock2 = _storage.getKeyBlock(keyHeight01 + step01 - 1);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock2.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock2.timestamp);
    }

    function testPegOut_pegOut_normal() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        Bridge bridge = Bridge(fixture.bridge);
        // bridge.pegOut(destinationBitcoinAddress, sourceOutpoint, amount, operatorPubkey);
    }
}
