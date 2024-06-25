// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import "../src/BtcMirror.sol";
import "./fixture/ConstantsFixture.sol";

contract BtcMirrorTest is Test, ConstantsFixture {
    function testGetTarget() public {
        BtcMirror mirror = createBtcMirror();
        uint256 expectedTarget;
        expectedTarget = 0x0000000000000000000B8C8B0000000000000000000000000000000000000000;
        assertEq(mirror.getTarget(hex"8b8c0b17"), expectedTarget);
        expectedTarget = 0x00000000000404CB000000000000000000000000000000000000000000000000;
        assertEq(mirror.getTarget(hex"cb04041b"), expectedTarget);
        expectedTarget = 0x000000000000000000096A200000000000000000000000000000000000000000;
        assertEq(mirror.getTarget(hex"206a0917"), expectedTarget);
    }

    function testSubmitError() public {
        bytes memory headerWrongParentHash = bytes.concat(bVer, bTxRoot, bTxRoot, bTime, bBits, bNonce);
        bytes memory headerWrongLength = bytes.concat(bVer, bParent, bTxRoot, bTime, bBits, bNonce, hex"00");
        bytes memory headerHashTooEasy = bytes.concat(bVer, bParent, bTxRoot, bTime, bBits, hex"41b360c0");

        BtcMirror mirror = createBtcMirror();
        assertEq(mirror.getLatestBlockHeight(), 717694);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("BadParent()"))));
        mirror.submit(717695, headerWrongParentHash);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("WrongBlockHeaderLength()"))));
        mirror.submit(717695, headerWrongLength);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("BlockHashAboveTarget()"))));
        mirror.submit(717695, headerHashTooEasy);
    }

    // function testSubmitErrorFuzz1(bytes calldata x) public {
    //     vm.expectRevert("");
    //     mirror.submit(718115, x);
    //     assert(mirror.getLatestBlockHeight() == 718115);
    // }

    // function testSubmitErrorFuzz2(uint256 height, bytes calldata x) public {
    //     vm.expectRevert("");
    //     mirror.submit(height, x);
    //     assert(mirror.getLatestBlockHeight() == 718115);
    // }

    event NewTip(uint256 blockHeight, uint256 blockTime, bytes32 blockHash);
    event NewTotalDifficultySinceRetarget(uint256 blockHeight, uint256 totalDifficulty, uint32 newDifficultyBits);

    function createBtcMirror() internal returns (BtcMirror mirror) {
        mirror = new BtcMirror(
            717694, // start at block #717694, two  blocks before retarget
            0x0000000000000000000b3dd6d6062aa8b7eb99d033fe29e507e0a0d81b5eaeed,
            1641627092,
            0x0000000000000000000B98AB0000000000000000000000000000000000000000,
            false
        );
    }

    function testSubmit() public {
        BtcMirror mirror = createBtcMirror();
        assertEq(mirror.getLatestBlockHeight(), 717694);
        vm.expectEmit(true, true, true, true);
        emit NewTip(717695, 1641627659, 0x00000000000000000000135a8473d7d3a3b091c928246c65ce2a396dd2a5ca9a);
        mirror.submit(717695, headerGood);
        assertEq(mirror.getLatestBlockHeight(), 717695);
        assertEq(mirror.getLatestBlockTime(), 1641627659);
        assertEq(mirror.getBlockHash(717695), 0x00000000000000000000135a8473d7d3a3b091c928246c65ce2a396dd2a5ca9a);
    }

    function testSubmitError2() public {
        BtcMirror mirror = createBtcMirror();
        mirror.submit(717695, headerGood);
        assertEq(mirror.getLatestBlockHeight(), 717695);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NoGivenBlockHeaders()"))));
        mirror.submit(717696, hex"");
        assertEq(mirror.getLatestBlockHeight(), 717695);
    }

    function testRetarget() public {
        BtcMirror mirror = createBtcMirror();
        mirror.submit(717695, headerGood);
        assertEq(mirror.getLatestBlockHeight(), 717695);

        vm.expectEmit(true, true, true, true);
        emit NewTotalDifficultySinceRetarget(
            717696,
            104678001670374021593451, // = (2^256 - 1) / (new target)
            386632843
        );
        vm.expectEmit(true, true, true, true);
        emit NewTip(717696, 1641627937, 0x0000000000000000000335dd327bde445d83f1ce40af2736a7c279045b9a55bf);
        mirror.submit(717696, header717696);
        assertEq(mirror.getLatestBlockHeight(), 717696);
        assertEq(mirror.getLatestBlockTime(), 1641627937);
        assertEq(mirror.getBlockHash(717696), 0x0000000000000000000335dd327bde445d83f1ce40af2736a7c279045b9a55bf);
    }

    function testRetargetLonger() public {
        BtcMirror mirror = createBtcMirror();
        mirror.submit(717695, headerGood);
        assertEq(mirror.getLatestBlockHeight(), 717695);

        vm.expectEmit(true, true, true, true);
        emit NewTotalDifficultySinceRetarget(717697, 209356003340748043186902, 386632843);
        vm.expectEmit(true, true, true, true);
        emit NewTip(717697, 1641628146, 0x00000000000000000000794d6f4f6ee1c09e69a81469d7456e67be3d724223fb);
        vm.recordLogs();
        mirror.submit(717695, bytes.concat(headerGood, header717696, header717697));
        assertEq(mirror.getLatestBlockHeight(), 717697);
        assertEq(vm.getRecordedLogs().length, 2);
    }
}
