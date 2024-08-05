// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Block} from "../interfaces/IBridge.sol";
import "./Endian.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @dev Encodes and Decodes Bitcoin Entities
 */
library Coder {
    error BlockHeaderLengthInvalid(uint256 length);

    uint256 public constant BLOCK_HEADER_LENGTH = 80;
    uint256 public constant MAX_TARGET = 0x00000000FFFF0000000000000000000000000000000000000000000000000000;
    uint256 public constant DIFFICULTY_PRECISION = 10 ** 6;
    uint32 public constant EPOCH_BLOCK_COUNT = 2016;
    uint32 public constant EPOCH_TARGET_TIMESPAN = 10 * 60 * EPOCH_BLOCK_COUNT;

    function decodeBlock(bytes calldata header) external pure returns (Block memory _block) {
        _block = decodeBlockPartial(header);
        _block.version = Endian.reverse32(uint32(bytes4(header[0:4])));
        _block.merkleRoot = bytes32(Endian.reverse256(uint256(bytes32(header[36:68]))));
        _block.nonce = Endian.reverse32(uint32(bytes4(header[76:80])));
    }

    function decodeBlockPartial(bytes calldata header) public pure returns (Block memory _block) {
        if (header.length != BLOCK_HEADER_LENGTH) {
            revert BlockHeaderLengthInvalid(header.length);
        }
        _block.previousBlockHash = bytes32(Endian.reverse256(uint256(bytes32(header[4:36]))));
        _block.timestamp = Endian.reverse32(uint32(bytes4(header[68:72])));
        _block.bits = bytes4(header[72:76]);
    }

    function encodeBlock(Block calldata _block) external pure returns (bytes memory) {
        return abi.encodePacked(
            bytes4(Endian.reverse32(_block.version)),
            bytes32(Endian.reverse256(uint256(_block.previousBlockHash))),
            bytes32(Endian.reverse256(uint256(_block.merkleRoot))),
            bytes4(Endian.reverse32(_block.timestamp)),
            _block.bits,
            bytes4(Endian.reverse32(_block.nonce))
        );
    }

    function toHash(bytes calldata header) external pure returns (bytes32 _hash) {
        if (header.length != BLOCK_HEADER_LENGTH) {
            revert BlockHeaderLengthInvalid(header.length);
        }

        bytes32 ret = sha256(abi.encodePacked(sha256(header)));
        _hash = bytes32(Endian.reverse256(uint256(ret)));
    }

    function toDifficulty(uint256 target) internal pure returns (uint256) {
        return MAX_TARGET * DIFFICULTY_PRECISION / target;
    }

    function bitToDifficulty(bytes32 bits) internal pure returns (uint256) {
        return toDifficulty(toTarget(bits));
    }

    /**
     * @dev @param bits is in reversed order as seen in a block header
     */
    function toTarget(bytes32 bits) internal pure returns (uint256) {
        // Bitcoin represents difficulty using a custom floating-point big int
        // representation. the "difficulty bits" consist of an 8-bit exponent
        // and a 24-bit mantissa, which combine to generate a u256 target. the
        // block hash must be below the target.
        uint256 exp = uint8(bits[3]);
        uint256 mantissa = uint8(bits[2]);
        mantissa = (mantissa << 8) | uint8(bits[1]);
        mantissa = (mantissa << 8) | uint8(bits[0]);
        uint256 target = mantissa << (8 * (exp - 3));
        return target;
    }

    function toBits(uint256 target) internal pure returns (bytes4) {
        uint256 exp = (Math.log256(target) + 1);
        uint256 mantissa = target >> (8 * (exp - 3));
        return bytes4(uint32(exp * 0x1000000 + mantissa));
    }

    /**
     * @notice                performs the bitcoin difficulty retarget
     * @dev                   implements the Bitcoin algorithm precisely
     * @param prevTarget      the target of the previous period
     * @param firstTimestamp  the timestamp of the first block in the difficulty period
     * @param lastTimestamp   the timestamp of the last (2015th) block in the difficulty period
     * @return                the new period's target threshold
     */
    function retarget(uint256 prevTarget, uint256 firstTimestamp, uint256 lastTimestamp)
        internal
        pure
        returns (uint256)
    {
        uint256 elapsedTime = lastTimestamp - firstTimestamp;

        // Normalize ratio to factor of 4 if very long or very short
        if (elapsedTime < EPOCH_TARGET_TIMESPAN / 4) {
            elapsedTime = EPOCH_TARGET_TIMESPAN / 4;
        }
        if (elapsedTime > EPOCH_TARGET_TIMESPAN * 4) {
            elapsedTime = EPOCH_TARGET_TIMESPAN * 4;
        }

        /*
            NB: high targets e.g. ffff0020 can cause overflows here
                so we divide it by 256**2, then multiply by 256**2 later
                we know the target is evenly divisible by 256**2, so this isn't an issue
        */
        uint256 adjusted = prevTarget / 65536 * elapsedTime;
        adjusted = adjusted * 65536 / EPOCH_TARGET_TIMESPAN;
        return adjusted > MAX_TARGET ? MAX_TARGET : adjusted;
    }

    function retargetWithBits(bytes4 prevBits, uint256 firstTimestamp, uint256 lastTimestamp)
        internal
        pure
        returns (bytes4)
    {
        uint256 prevTarget = toTarget(prevBits);
        uint256 newTarget = retarget(prevTarget, firstTimestamp, lastTimestamp);
        return bytes4(Endian.reverse32(uint32(toBits(newTarget))));
    }
}
