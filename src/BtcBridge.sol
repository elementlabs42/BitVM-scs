// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./EBTC.sol";
import "./BtcTxVerifier.sol";

contract BtcBridge {
    event VerifyPegInDone();
    event VerifyPegOutDone();
    event BureEBTCDone();

    EBTC ebtc;
    BtcTxVerifier btcTxVerifier;

    constructor(EBTC _ebtc, BtcTxVerifier _btcTxVerifier) {
        ebtc = _ebtc;
        btcTxVerifier = _btcTxVerifier;
    }

    // verifies 2 bitcoin transactions have happened with enough mined difficulty:
    // 1. tx1:
    //   a) the output is a taproot with 2 tapleafs:
    //     i. leaf[0] is TimeLock script that the depositor can spend after
    //       timelock, if leaf[1] has not been spent
    //     ii. leaf[1] is spendable by a multisig of depositor and OPK and VPK[1…N]
    // b) the transaction script contains an [evm_address] (inscription data)
    //   which is the destination ethereum address to receive the bridged
    //   token $eBTC (of amount V).
    // 2. tx2: uses the above tx1 as input and spend to an output of a multisig of OPK and VPK[1…N]
    //   Once a user is able to provide the above SPV proof, the $eBTC minting contract
    //   on ethereum will mint an amount of V $eBTC to [evm_address].
    function verifyPegIn(
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

        emit VerifyPegInDone();
    }

    // TODO: implement this function to extract address from proof
    // function extractAddress(BtcTxProof calldata proof) internal returns (address) {
    // }

    // SC also contains the following “Pegout(destinationBitcoinAddress,
    // sourceBitcoinAddress, amount)”method, where destinationBitcoinAddress is the
    // address that a pegout user would like the received bitcoin to go to (e.g. his
    // own bitcoin address), and sourceBitcoinAddress is a particular UTXO that is
    // under custody of the operator+verifiers which the user would like to redeem $BTC
    // from.
    function pegOut(bytes calldata /* destinationBitcoinAddress */, bytes calldata /* sourceBitcoinAddress */, uint /* amount */) external {
        // TODO: implement peg out flow
        emit VerifyPegOutDone();
    }

    // SC also contains the method “BurnEBTC(withdrawal_proof)” where
    // withdrawal_proof is a SPV proof that a bitcoin transaction that pays V $BTC to
    // destinationBitcoinAddress has occurred and been mined with the required level
    // of cumulative difficulty. Anyone (permissionlessly) who can provide such a proof
    // can call this method to burn the V $eBTC locked in the vault. Otherwise if this
    // method is not called within a time window (e.g. 8 weeks), user can claim V $eBTC
    // back from the vault (in the case that destinationBitcoinAddress is not paid).
    function burnEBTC(BtcTxProof calldata /* withdrawal_proof */) external {
      // TODO: implement bure eBTC flow
      emit BureEBTCDone();
    }


}
