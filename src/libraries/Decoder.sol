// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Block} from "../interfaces/IBtcBridge.sol";
import "./Endian.sol";

/**
 * @dev Decodes Bitcoin entities
 */
library Decoder {
    error WrongBlockHeaderLength(uint256 length);

    uint256 public constant BLOCK_HEADER_LENGTH = 80;
    uint256 public constant MAX_TARGET = 0x00000000FFFF0000000000000000000000000000000000000000000000000000;

    function parseBlock(bytes calldata header) external pure returns (Block memory _block) {
        if (header.length != BLOCK_HEADER_LENGTH) {
            revert WrongBlockHeaderLength(header.length);
        }

        _block.version = Endian.reverse32(uint32(bytes4(header[0:4])));
        _block.previousBlockHash = bytes32(Endian.reverse256(uint256(bytes32(header[4:36]))));
        _block.merkleRoot = bytes32(Endian.reverse256(uint256(bytes32(header[36:68]))));
        _block.timestamp = Endian.reverse32(uint32(bytes4(header[68:72])));
        _block.bits = Endian.reverse32(uint32(bytes4(header[72:76])));
        _block.nonce = Endian.reverse32(uint32(bytes4(header[76:80])));
    }

    function toDifficulty(uint32 bits) internal pure returns (uint256) {
        return MAX_TARGET / bits;
    }
}
