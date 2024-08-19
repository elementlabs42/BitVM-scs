// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma experimental ABIEncoderV2;

import "../../src/interfaces/IBridge.sol";
import "../../src/libraries/Endian.sol";
import "../../src/libraries/ViewSPV.sol";
import "../../src/libraries/TypedMemView.sol";

library TransactionHelper {
    using ViewSPV for bytes4;
    using TypedMemView for bytes;
    using Endian for bytes32;

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

    function parseRawTx(bytes calldata rawTx)
        public
        pure
        returns (bytes4 version, bytes4 locktime, bytes memory rawVin, bytes memory rawVout)
    {
        version = bytes4(rawTx[0:4]);
        uint256 offset = 6;
        uint256 nInputs;
        uint256 prevOffset = offset;
        (nInputs, offset) = readVarInt(rawTx, offset);
        for (uint256 i; i < nInputs; ++i) {
            offset += 36;
            uint256 nInScriptBytes;
            (nInScriptBytes, offset) = readVarInt(rawTx, offset);
            offset += uint32(nInScriptBytes);
            offset += 4;
        }
        rawVin = rawTx[prevOffset:offset];

        prevOffset = offset;
        // Read transaction outputs
        uint256 nOutputs;
        (nOutputs, offset) = readVarInt(rawTx, offset);
        for (uint256 i; i < nOutputs; ++i) {
            offset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, offset) = readVarInt(rawTx, offset);
            offset += nOutScriptBytes;
        }
        rawVout = rawTx[prevOffset:offset];
        prevOffset = offset;

        // Read transaction witness if exists
        uint256 nWitnesses;
        (nWitnesses, offset) = readVarInt(rawTx, offset);
        for (uint256 i; i < nWitnesses; ++i) {
            uint256 nWitnessItemBytes;
            (nWitnessItemBytes, offset) = readVarInt(rawTx, offset);
            offset += nWitnessItemBytes;
        }

        locktime = bytes4(rawTx[offset:offset + 4]);
    }
}
