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
     * @dev index of the last stored block, to represent length of storedBlocks
     *      stored separately since chain can be shorter when reorg
     */
    uint256 private tipIndex;

    /**
     * @param distance block height distance for every key blocks
     * @param blockHeight initial block height of the storage
     * @param blockHash initial block hash
     * @param timestamp timestamp of the initial block
     */
    constructor(uint256 distance, uint256 blockHeight, bytes32 blockHash, uint256 timestamp) {
        if (distance == 0) {
            revert BlockStepDistanceInvalid(distance);
        }
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
        if (data.length == 0 || blockHeight == 0) {
            revert NoGivenBlockHeaders();
        }

        uint256 index = heightToIndex(blockHeight - 1);
        if ((blockHeight - initialBlockHeight - 1) % blockStepDistance != 0) {
            revert BlockHeightInvalid(blockHeight);
        }
        if (tipIndex < index) {
            revert BlockHeightTooHigh(blockHeight, tipIndex);
        }

        uint256 reorgCount;
        bytes32 previousHash = storedBlocks[index].blockHash;
        uint256 accumulatedDifficulty = storedBlocks[tipIndex].accumulatedDifficulty;
        uint256 accumulatedDifficultyNew = storedBlocks[index].accumulatedDifficulty;

        uint256 headerCount = data.length / Coder.BLOCK_HEADER_LENGTH;
        if (data.length != headerCount * Coder.BLOCK_HEADER_LENGTH) {
            revert Coder.BlockHeaderLengthInvalid(data.length);
        }
        if (headerCount % blockStepDistance != 0) {
            revert BlockCountInvalid(headerCount);
        }
        for (uint256 i; i < headerCount; ++i) {
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

            if ((blockHeight + i) % blockStepDistance == initialBlockHeight % blockStepDistance) {
                ++index;
                KeyBlock memory keyBlock = KeyBlock(_hash, accumulatedDifficultyNew, _block.timestamp);
                if (tipIndex >= index) {
                    storedBlocks[index] = keyBlock;
                    ++reorgCount;
                } else {
                    storedBlocks.push(keyBlock);
                }
            }
        }

        if (accumulatedDifficultyNew <= accumulatedDifficulty) {
            revert BlockCountInvalid(headerCount);
        }

        emit KeyBlocksSubmitted(indexToHeight(index), headerCount, reorgCount);
        tipIndex = index;
    }

    function getKeyBlock(uint256 blockHeight) external view override returns (KeyBlock memory _block) {
        uint256 index = heightToIndex(blockHeight);
        if ((blockHeight - initialBlockHeight) % blockStepDistance != 0) {
            revert BlockHeightInvalid(blockHeight);
        }
        if (tipIndex < index) {
            revert BlockHeightTooHigh(blockHeight, tipIndex);
        }
        _block = storedBlocks[index];
    }

    function getKeyBlockCount() external view override returns (uint256) {
        return tipIndex + 1;
    }

    function indexToHeight(uint256 index) internal view returns (uint256) {
        return initialBlockHeight + index * blockStepDistance;
    }

    function heightToIndex(uint256 blockHeight) internal view returns (uint256) {
        if (blockHeight < initialBlockHeight) {
            revert BlockHeightTooLow(blockHeight);
        }
        return (blockHeight - initialBlockHeight) / blockStepDistance;
    }
}
