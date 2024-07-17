// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma experimental ABIEncoderV2;

import "./Endian.sol";
import "../interfaces/IBtcBridge.sol";

library TransactionHelper {
    error ScriptBytesTooLong();

    function readVarInt(bytes calldata buf, uint256 offset) public pure returns (uint256 val, uint256 newOffset) {
        uint8 pivot = uint8(buf[offset]);
        if (pivot < 0xfd) {
            val = pivot;
            newOffset = offset + 1;
        } else if (pivot == 0xfd) {
            val = Endian.reverse16(uint16(bytes2(buf[offset + 1:offset + 3])));
            newOffset = offset + 3;
        } else if (pivot == 0xfe) {
            val = Endian.reverse32(uint32(bytes4(buf[offset + 1:offset + 5])));
            newOffset = offset + 5;
        } else {
            val = Endian.reverse64(uint64(bytes8(buf[offset + 1:offset + 9])));
            newOffset = offset + 9;
        }
    }

    function parseVin(bytes calldata rawVin) public pure returns (InputPoint[] memory inputs) {
        (uint256 nInputs, uint256 newOffset) = readVarInt(rawVin, 0);
        inputs = new InputPoint[](nInputs);
        for (uint256 i; i < nInputs; ++i) {
            InputPoint memory txIn;
            txIn.prevTxID = bytes32(rawVin[newOffset:newOffset + 32]);
            newOffset += 32;
            txIn.prevTxIndex = bytes4(rawVin[newOffset:newOffset + 4]);
            newOffset += 4;
            uint256 nInScriptBytes;
            (nInScriptBytes, newOffset) = readVarInt(rawVin, newOffset);

            if (nInScriptBytes > 32) {
                revert ScriptBytesTooLong();
            }

            txIn.scriptSig = rawVin[newOffset:newOffset + nInScriptBytes];
            newOffset += nInScriptBytes;
            txIn.sequence = Endian.reverse32(uint32(bytes4(rawVin[newOffset:newOffset + 4])));
            newOffset += 4;
            inputs[i] = txIn;
        }
    }

    function parseVout(bytes calldata rawVout) public pure returns (OutputPoint[] memory outputs) {
        (uint256 nOutputs, uint256 newOffset) = readVarInt(rawVout, 0);
        outputs = new OutputPoint[](nOutputs);
        for (uint256 i; i < nOutputs; ++i) {
            OutputPoint memory txOut;
            txOut.value = Endian.reverse64(uint64(bytes8(rawVout[newOffset:newOffset + 8])));
            newOffset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, newOffset) = readVarInt(rawVout, newOffset);

            txOut.scriptPubKey = rawVout[newOffset:newOffset + nOutScriptBytes];
            newOffset += nOutScriptBytes;
            outputs[i] = txOut;
        }
    }
}
