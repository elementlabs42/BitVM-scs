// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBridge.sol";
import "../src/libraries/Coder.sol";
import "./fixture/ConstantsFixture.sol";

contract CoderTest is Test, ConstantsFixture {
    function testCoder_DecodeBlock() public pure {
        Block memory _block = Coder.decodeBlockPartial(header736000);
        assertEq(_block.previousBlockHash, hex"00000000000000000003e7e6eac5237bb17cf21a9ef317e1d2ebeee69c0f28d8");
        assertEq(_block.timestamp, 1652319653);
        assertEq(Endian.reverse32(uint32(_block.bits)), 0x170901ba);

        _block = Coder.decodeBlock(header736000);
        assertEq(_block.version, 0x20000004);
        assertEq(_block.merkleRoot, hex"9ce124cc629e646e6e8bfe0ab56cdb0976004989ed86b2312ce28458b369b631");
        assertEq(_block.nonce, 0x6598d036);
    }

    function testCoder_EncodeBlock() public pure {
        Block memory _block = Block(
            0x20000004,
            1652319653,
            bytes4(Endian.reverse32(0x170901ba)),
            0x6598d036,
            hex"00000000000000000003e7e6eac5237bb17cf21a9ef317e1d2ebeee69c0f28d8",
            hex"9ce124cc629e646e6e8bfe0ab56cdb0976004989ed86b2312ce28458b369b631"
        );
        bytes memory header = Coder.encodeBlock(_block);
        assertEq(header.length, 80);
        assertEq(header, header736000);
    }

    function testCoder_Target() public pure {
        Block memory _block = Coder.decodeBlock(header736000);
        bytes32 _hash = Coder.toHash(header736000);
        uint256 target = Coder.toTarget(_block.bits);
        assertTrue(uint256(_hash) < target);

        uint256 difficulty = Coder.toDifficulty(target);
        assertEq(difficulty, 31251101365711121697);
    }

    function testCoder_Bits() public pure {
        Block memory _block = Coder.decodeBlock(header736000);
        uint256 target = Coder.toTarget(_block.bits);
        assertEq(Coder.toBits(target), bytes4(Endian.reverse32(uint32(_block.bits))));

        assertEq(Coder.toBits(0x00000000000000005d859a000000000000000000000000000000000000000000), bytes4(0x185d859a));
        assertEq(Coder.toBits(0x0000000000000113370000000000000000000000000000000000000000000000), bytes4(0x1a011337)); // height 239,904
        assertEq(Coder.toBits(0x00000000000000000262df000000000000000000000000000000000000000000), bytes4(0x180262df)); // height 455,616
        assertEq(Coder.toBits(0x00000000001e7eca000000000000000000000000000000000000000000000000), bytes4(0x1b1e7eca)); // height 86,688
    }
}
