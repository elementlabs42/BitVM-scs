// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBtcBridge.sol";
import "../src/libraries/Decoder.sol";
import "./fixture/ConstantsFixture.sol";

contract DecoderTest is Test, ConstantsFixture {
    function testBlock() public pure {
        Block memory _block = Decoder.parseBlock(header736000_2);
        assertEq(_block.version, 0x20000004);
        assertEq(_block.previousBlockHash, hex"00000000000000000003e7e6eac5237bb17cf21a9ef317e1d2ebeee69c0f28d8");
        assertEq(_block.merkleRoot, hex"9ce124cc629e646e6e8bfe0ab56cdb0976004989ed86b2312ce28458b369b631");
        assertEq(_block.timestamp, 1652319653);
        assertEq(_block.bits, 0x170901ba);
        assertEq(_block.nonce, 0x6598d036);
    }
}
