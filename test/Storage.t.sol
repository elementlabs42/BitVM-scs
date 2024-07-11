// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBtcBridge.sol";
import "../src/libraries/Coder.sol";
import "./fixture/ConstantsFixture.sol";
import "../src/Storage.sol";
import "./Util.sol";

contract StorageTest is Test, ConstantsFixture {
    function testStorage_constructor_zeroDistance() public {
        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockStepDistanceInvalid.selector, 0));
        new Storage(0, 0, hex"", 0);
    }

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

    function testStorage_Submit_zeroInput() public {
        IStorage _storage = new Storage(17, 841107, blockHash841107, 1073676288);

        vm.expectRevert(abi.encodeWithSelector(IStorage.NoGivenBlockHeaders.selector));
        _storage.submit(hex"", 841108);

        vm.expectRevert(abi.encodeWithSelector(IStorage.NoGivenBlockHeaders.selector));
        _storage.submit(block841108to841209, 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.NoGivenBlockHeaders.selector));
        _storage.submit(hex"", 0);
    }

    function testStorage_Submit_lowHeight() public {
        uint256 initialHeight = 201;
        uint256 lowHeight = 201;
        IStorage _storage = new Storage(1, initialHeight, hex"", 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightTooLow.selector, lowHeight - 1));
        _storage.submit(hex"ff", lowHeight);
    }

    function testStorage_Submit_notOnPace() public {
        uint256 height = 34;
        IStorage _storage = new Storage(17, 0, hex"", 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightInvalid.selector, height));
        _storage.submit(hex"ff", height);
    }

    function testStorage_Submit_highHeight() public {
        uint256 initialHeight = 201;
        uint256 legitHeight = initialHeight + 1;
        uint256 highHeight = legitHeight + 1;
        IStorage _storage = new Storage(1, initialHeight, hex"", 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightTooHigh.selector, highHeight, 0));
        _storage.submit(hex"ff", highHeight);

        uint256 step = 10;
        initialHeight = 832000;
        _storage = new Storage(step, initialHeight, blockHash832000, 1708879379);
        _storage.submit(block832001to832050, 832001);

        legitHeight = initialHeight + (_storage.getKeyBlockCount() - 1) * step + 1;
        highHeight = legitHeight + step;
        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightTooHigh.selector, highHeight, 5));
        _storage.submit(block832001to832050, highHeight);
    }

    function testStorage_Submit_invalidLength() public {
        IStorage _storage = new Storage(10, 832000, blockHash832000, 1708879379);
        uint256 newLength = block832001to832050.length - 2;
        bytes memory corruptedData = Util.slice(block832001to832050, 0, newLength);

        vm.expectRevert(abi.encodeWithSelector(Coder.BlockHeaderLengthInvalid.selector, newLength));
        _storage.submit(corruptedData, 832001);
    }
}
