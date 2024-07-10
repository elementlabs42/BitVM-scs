// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/libraries/Transaction.sol";
import "./fixture/ConstantsFixture.sol";

contract TransactionTest is Test, ConstantsFixture {
    function testTransactionParse() public view {
        Transaction.BTCTransaction memory btcTx = Transaction.parseBTCTransaction(tx3020);
        // Check version
        assertEq(btcTx.version, 2);

        // Check flag
        assertEq(btcTx.flag, hex"0001");

        // Check input count
        assertEq(btcTx.vin.length, 1);

        // Check first input
        assertEq(btcTx.vin[0].txid, hex"5c98af97581ab788e7d4bda18f01e7b54d6fce601dc2ecdcbb0a38b0f82249e6");
        assertEq(btcTx.vin[0].vout, 0);
        assertEq(btcTx.vin[0].scriptSig.length, 0);
        assertEq(btcTx.vin[0].sequence, 0xffffffff);

        // Check output count
        assertEq(btcTx.vout.length, 1);

        // Check first output
        assertEq(btcTx.vout[0].value, 100000);
        assertEq(btcTx.vout[0].scriptPubKey, hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d");

        // Check if it's a Taproot output
        bytes memory expectedTaprootPubKey = hex"be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d";
        assertEq(btcTx.vout[0].scriptPubKey, expectedTaprootPubKey);

        // Check witness data
        assertEq(btcTx.witnessData.length, 0);

        // Check locktime
        assertEq(btcTx.locktime, 0);
    }
}
