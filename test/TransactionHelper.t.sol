// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/libraries/TransactionHelper.sol";
import "../src/interfaces/IBridge.sol";

contract TransactionHelperTest is Test {
    function testTransactionHelper_parseVin() public pure {
        // Extract the rawVin part from tx3020
        bytes memory rawVin = (
            hex"01" // input count, compact size
            hex"5c98af97581ab788e7d4bda18f01e7b54d6fce601dc2ecdcbb0a38b0f82249e6" // txid
            hex"00000000" // vout
            hex"00" // scriptSig size
            hex"" // scriptSig
            hex"ffffffff"
        ); // sequence

        Input[] memory inputs = TransactionHelper.parseVin(rawVin);

        assertEq(inputs.length, 1);
        assertEq(inputs[0].prevTxID, 0x5c98af97581ab788e7d4bda18f01e7b54d6fce601dc2ecdcbb0a38b0f82249e6);
        assertEq(inputs[0].prevTxIndex, 0);
        assertEq(inputs[0].sequence, 0xffffffff);
    }

    function testTransactionHelper_parseVout() public pure {
        // Extract the rawVout part from tx3020
        bytes memory rawVout = (
            hex"01" // output count, compact size
            hex"a086010000000000" // output amount
            hex"22" // scriptPubKey size
            hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d"
        ); // scriptPubKey

        Output[] memory outputs = TransactionHelper.parseVout(rawVout);

        assertEq(outputs.length, 1);
        assertEq(outputs[0].value, 100000);
        assertEq(outputs[0].scriptPubKey, hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d");
    }
}
