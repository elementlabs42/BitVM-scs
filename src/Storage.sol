// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IStorage.sol";
import "./libraries/Endian.sol";
import "./libraries/Coder.sol";

/**
 * @dev Contract that stores key Bitcoin blocks for SPV validation
 */
contract Storage is IStorage {
    uint256 public immutable blockStepDistance;
    uint256 public immutable initialBlockHeight;
    KeyBlock[] private storedBlocks;

    /**
     * @param distance block height distance for every key blocks
     * @param blockHeight initial block height of the storage
     * @param blockHash initial block hash
     * @param timestamp timestamp of the initial block
     */
    constructor(uint256 distance, uint256 blockHeight, bytes32 blockHash, uint256 timestamp) {
        blockStepDistance = distance;
        initialBlockHeight = blockHeight;
        storedBlocks.push(KeyBlock(blockHash, 0, timestamp));
    }

    /**
     * @param data concatenated and continuous block headers as seen in explorer,
     *             the length should be multiple of Coder.BLOCK_HEADER_LENGTH * blockStepDistance
     * @param blockHeight first block height in @param data,
     *                    the value should be latest storedBlock height + 1
     */
    function submit(bytes calldata data, uint256 blockHeight) external override {
        if (blockHeight <= initialBlockHeight) {
            revert BlockHeightTooLow(blockHeight);
        }
        if ((blockHeight - initialBlockHeight - 1) % blockStepDistance != 0) {
            revert BlockHeightInvalid(blockHeight);
        }
        uint256 index = (blockHeight - initialBlockHeight - 1) / blockStepDistance;
        uint256 storageSize = storedBlocks.length;
        if (storageSize <= index) {
            revert BlockHeightTooHigh(blockHeight, storageSize);
        }

        bytes32 previousHash = storedBlocks[index].blockHash;
        uint256 accumulatedDifficulty = storedBlocks[storageSize - 1].accumulatedDifficulty;
        uint256 accumulatedDifficultyNew = storedBlocks[index].accumulatedDifficulty;

        uint256 headerCount = data.length / Coder.BLOCK_HEADER_LENGTH;
        if (data.length == 0) {
            revert NoGivenBlockHeaders();
        }
        if (data.length != headerCount * Coder.BLOCK_HEADER_LENGTH) {
            revert Coder.BlockHeaderLengthInvalid(data.length);
        }
        if (headerCount % blockStepDistance != 0) {
            revert BlockCountInvalid(headerCount);
        }
        for (uint256 i = 0; i < headerCount; i++) {
            bytes memory header = data[Coder.BLOCK_HEADER_LENGTH * i:Coder.BLOCK_HEADER_LENGTH * (i + 1)];
            Block memory _block = Coder.decodeBlockPartial(header);
            if (previousHash != _block.previousBlockHash) {
                revert BlockHashMismatch(previousHash, _block.previousBlockHash);
            }
            bytes32 _hash = Coder.toHash(header);
            uint256 target = Coder.toTarget(_block.bits);
            if (uint256(_hash) >= target) {
                revert HashNotBelowTarget(_hash, bytes32(target));
            }
            accumulatedDifficultyNew += Coder.toDifficulty(target);
            previousHash = _hash;

            if (i % blockStepDistance == 0) {
                KeyBlock memory keyBlock = KeyBlock(_hash, accumulatedDifficultyNew, _block.timestamp);
                if (storageSize > index) {
                    storedBlocks[index] = keyBlock;
                } else {
                    storedBlocks.push(keyBlock);
                }
                ++index;
            }
        }

        if (accumulatedDifficultyNew <= accumulatedDifficulty) {
            revert BlockCountInvalid(headerCount);
        }
    }

    function getKeyBlock(uint256 blockHeight) external view override returns (KeyBlock memory _block) {
        if (blockHeight <= initialBlockHeight) {
            revert BlockHeightTooLow(blockHeight);
        }
        if ((blockHeight - initialBlockHeight - 1) % blockStepDistance != 0) {
            revert BlockHeightInvalid(blockHeight);
        }
        uint256 index = (blockHeight - initialBlockHeight - 1) / blockStepDistance;
        if (storedBlocks.length <= index) {
            revert BlockHeightTooHigh(blockHeight, storedBlocks.length);
        }
        _block = storedBlocks[index];
    }

    function getKeyBlockCount() external view override returns (uint256) {
        return storedBlocks.length;
    }
}
