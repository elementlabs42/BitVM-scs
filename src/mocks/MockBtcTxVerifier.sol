// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../BtcTxVerifier.sol";
import "./IMockBtcTxVerifier.sol";

contract MockBtcTxVerifier is IMockBtcTxVerifier, BtcTxVerifier {
    constructor(IBtcMirror _mirror) BtcTxVerifier(_mirror) {}

    function mockValidatePayment(
        bytes32 blockHash,
        BtcTxProof calldata txProof,
        uint256 txOutIx,
        bytes20 destScriptHash,
        uint256 satoshisExpected
    ) public pure returns (bool) {
        return false;
    }
}
