// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IBtcTxVerifier.sol";

interface IMockBtcTxVerifier is IBtcTxVerifier {
    function mockValidatePayment(
        bytes32 blockHash,
        BtcTxProof calldata txProof,
        uint256 txOutIx,
        bytes20 destScriptHash,
        uint256 satoshisExpected
    ) external returns (bool);
}