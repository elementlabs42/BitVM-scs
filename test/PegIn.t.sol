// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";

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
}
