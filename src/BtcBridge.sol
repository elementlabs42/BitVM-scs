// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./EBTC.sol";
import "./BtcTxVerifier.sol";

contract BtcBridge {
    event VerifyPeginDone();

    EBTC ebtc;
    BtcTxVerifier btcTxVerifier;

    constructor(EBTC _ebtc, BtcTxVerifier _btcTxVerifier) {
        ebtc = _ebtc;
        btcTxVerifier = _btcTxVerifier;
    }

    function verifyPegin(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata proof,
        uint256 txOutIx,
        bytes20 destScriptHash,
        uint256 amountSats
    ) external {
        btcTxVerifier.verifyPayment(minConfirmations, blockNum, proof, txOutIx, destScriptHash, amountSats);

        // TODO: extract addresss from proof and sent the amount to the address
        // ebtc.mint(extractAddress(proof), amountSats);

        emit VerifyPeginDone();
    }

    // TODO: implement this function to extract address from proof
    // function extractAddress(BtcTxProof calldata proof) internal returns (address) {
    // }
}
