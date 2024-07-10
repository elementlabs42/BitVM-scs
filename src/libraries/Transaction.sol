// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./SafeMath.sol";
import {TaprootHelper} from "./TaprootHelper.sol";
import {BtcTxProof} from "../interfaces/IBtcBridge.sol";
import "./Endian.sol";
import "../interfaces/IBtcBridge.sol";
import "./TypedMemView.sol";
import "./ViewBTC.sol";
library Transaction {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using ViewBTC for bytes29;

    struct BTCInput {
        bytes32 txid;
        uint32 vout;
        bytes scriptSig;
        uint32 sequence;
    }

    struct BTCOutput {
        uint64 value;
        bytes scriptPubKey;
    }

    struct BTCTransaction {
        bytes4 version;
        BTCInput[] vin;
        BTCOutput[] vout;
        bytes4 locktime;
        bytes flag; // Optional flag for SegWit transactions
        bytes witnessData; // Optional witness data for SegWit transactions
        bytes rawVin;
        bytes rawVout;
    }

    function parseBTCTransaction(bytes memory txBytes) public view returns (BTCTransaction memory) {
        BTCTransaction memory btcTx;

        // Parse version
        bytes29 txView = txBytes.ref(0);
        btcTx.version = txView.slice(0,4);
        uint256 offset = 4;

        // Check for SegWit marker and flag
        bool isSegWit = false;
        if (txView.indexUint(offset, 1) == 0x00 && txView.indexUint(offset + 1, 1) == 0x01) {
            isSegWit = true;
            btcTx.flag = txView.slice(offset, 2, uint40(ViewBTC.BTCTypes.Unknown)).clone();
            offset += 2;
        }

        // Parse inputs (vin)
        bytes29 vinView = txView.slice(offset, txView.len() - offset, uint40(ViewBTC.BTCTypes.Unknown));
        uint256 vinCount = vinView.indexCompactInt(0);
        offset += 1;

        btcTx.vin = new BTCInput[](vinCount);
        for (uint256 i = 0; i < vinCount; i++) {
            bytes29 inputView = vinView.slice(offset, vinView.len() - (offset - 4), uint40(ViewBTC.BTCTypes.TxIn));
            btcTx.vin[i].txid = inputView.txidLE();
            btcTx.vin[i].vout = inputView.outpointIdx();
            btcTx.vin[i].scriptSig = inputView.scriptSig().clone();
            btcTx.vin[i].sequence = inputView.sequence();
            offset += inputView.len();
        }

        // Parse outputs (vout)
        bytes29 voutView = txView.slice(offset, txView.len() - offset, uint40(ViewBTC.BTCTypes.Unknown));
        uint256 voutCount = voutView.indexCompactInt(0);
        offset += ViewBTC.compactIntLength(uint64(voutCount));

        btcTx.vout = new BTCOutput[](voutCount);
        for (uint256 i = 0; i < voutCount; i++) {
            bytes29 outputView = voutView.indexVout(i);



            // Check if the output is a P2TR (Taproot) output
            if (btcTx.vout[i].scriptPubKey.length == 34 && btcTx.vout[i].scriptPubKey[0] == 0x51) {
                // This is a Taproot output, the second byte should be 0x20 indicating a 32-byte public key
                require(btcTx.vout[i].scriptPubKey[1] == 0x20, "Invalid Taproot output");
                bytes memory taprootPubKey = new bytes(32);
                for (uint256 j = 0; j < 32; j++) {
                    taprootPubKey[j] = btcTx.vout[i].scriptPubKey[j + 2];
                }
                btcTx.vout[i].scriptPubKey = taprootPubKey;
            } else {
                btcTx.vout[i].value = outputView.value();
                btcTx.vout[i].scriptPubKey = outputView.scriptPubkey().clone();
            }

            offset += outputView.len();
        }

        // Parse witness data if SegWit transaction
        if (isSegWit) {
            // Note: Parsing witness data is more complex and involves additional steps.
            //       This example assumes witness data is concatenated after vout.
            //       You need to parse each witness field accordingly.
            bytes29 witnessView = txView.slice(offset, txView.len() - offset, uint40(ViewBTC.BTCTypes.Unknown));
            btcTx.witnessData = witnessView.clone();
            offset += witnessView.len();
        }

        // Parse locktime
        btcTx.locktime = txView.slice(txView.len() - 4, 4);

        return btcTx;
    }
}
