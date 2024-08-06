// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/libraries/TaprootHelper.sol";

contract TaprootTest is Test {
    function testTaprootHelper_createTaprootAddress() public pure {
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = hex"2013f523102815e9fbbe132ffb8329b0fef5a9e4836d216dce1824633287b0abc6ac";
        scripts[1] = hex"20e808f1396f12a253cf00efdf841e01c8376b616fb785c39595285c30f2817e71ac";
        assertEq(
            TaprootHelper.createTaprootAddress(
                0x1036a7ed8d24eac9057e114f22342ebf20c16d37f0d25cfd2c900bf401ec09c9, scripts
            ),
            0x6e45f10a20f5b5622e6673ffac5bdc080625d86a59a948c7bcd10e0b06f6f280
        );
    }
}
