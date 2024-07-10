// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBtcBridge.sol";
import "../src/libraries/Coder.sol";
import "./fixture/ConstantsFixture.sol";
import "../src/Storage.sol";

contract StorageTest is Test, ConstantsFixture {
    function testStorage_Submit() public {
        IStorage _storage = new Storage(10, 832000, blockHash832000, 1708879379);
        _storage.submit(block832001to832050, 832001);

        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, 6);

        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(blockHash832010, 0, 1708882338);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(832010);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testStorage_Submit_initialBlock() public {
        IStorage _storage = new Storage(10, 842562, blockHash842562, 1715179752);
        _storage.submit(block842563to842612, 842563);

        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, 6);

        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(blockHash842592, 0, 1715194279);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(842592);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testStorage_Submit_step() public {
        IStorage _storage = new Storage(17, 841107, blockHash841107, 1073676288);
        _storage.submit(block841108to841209, 841108);

        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, 7);

        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(blockHash841157, 0, 1714277734);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(841192);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }
}
