// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import "../src/libraries/Endian.sol";

contract EndianTest is Test {
    function testEndian_reverse32() public pure {
        uint32 input = 0x12345678;
        assertEq(Endian.reverse32(input), 0x78563412);
    }

    function testEndian_reverse256() public pure {
        uint256 input = 0x00112233445566778899aabbccddeeff00000000000000000123456789abcdef;
        assertEq(Endian.reverse256(input), 0xefcdab89674523010000000000000000ffeeddccbbaa99887766554433221100);
    }

    function testEndian_reverse256Array() public pure {
        bytes memory input = (
            hex"00112233445566778899aabbccddeeff00000000000000000123456789abcdef"
            hex"00112233445566778899aabbccddeeff00000000000000000123456789abcdef"
        );
        bytes memory output = Endian.reverse256Array(input);
        assertEq(
            output,
            (
                hex"efcdab89674523010000000000000000ffeeddccbbaa99887766554433221100"
                hex"efcdab89674523010000000000000000ffeeddccbbaa99887766554433221100"
            )
        );
    }
}
