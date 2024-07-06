// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IKeyBlocksStorage.sol";
import "./libraries/Endian.sol";
import "./libraries/Decoder.sol";

/**
 * @dev Contract that stores key Bitcoin blocks for SPV validation
 */
contract KeyBlocksStorage is IKeyBlocksStorage {
    uint256 public immutable blockStepDistance;
    uint256 public immutable initialBlockHeight;
    KeyBlock[] private storedBlocks;

    /**
     * @param distance block height distance for every key blocks
     * @param blockHeight starting block height, should be latest storedBlock height + 1
     * @param blockHash starting block hash
     * @param timestamp timestamp of the block
     */
    constructor(uint256 distance, uint256 blockHeight, bytes32 blockHash, uint256 timestamp) {
        blockStepDistance = distance;
        initialBlockHeight = blockHeight;
        storedBlocks.push(KeyBlock(blockHash, 0, timestamp));
    }

    function submit(Block[] calldata data, uint256 blockHeight) external view {
        if (data.length % blockStepDistance != 0) {
            revert BlockCountInvalid(data.length);
        }
        if (blockHeight <= initialBlockHeight) {
            revert BlockHeightTooLow(blockHeight);
        }
        if ((blockHeight - initialBlockHeight - 1) % blockStepDistance != 0) {
            revert BlockHeightInvalid(blockHeight);
        }
        uint256 index = (blockHeight - initialBlockHeight - 1) / blockStepDistance;
        uint256 storedLength = storedBlocks.length;
        // TODO: should we consider reorg?
        if (storedLength <= index) {
            revert BlockHeightNotContinuous(blockHeight, storedLength);
        }
        bytes32 previousHash = storedBlocks[index].blockHash;
        uint256 accumulatedDifficulty = storedBlocks[storedLength - 1].accumulatedDifficulty;
        uint256 accumulatedDifficultyNew = storedBlocks[index].accumulatedDifficulty;

        for (uint256 i = 0; i < data.length; i++) {
            if (previousHash != data[i].previousBlockHash) {
                revert BlockHashMismatch(previousHash, data[i].previousBlockHash);
            }
            if (i % blockStepDistance == 0) {}
        }
    }

    function parseBlocks(bytes calldata data) external pure returns (Block[] memory blocks) {
        if (data.length == 0) {
            revert NoGivenBlockHeaders();
        }
        uint256 numHeaders = data.length / Decoder.BLOCK_HEADER_LENGTH;
        if (data.length != numHeaders * Decoder.BLOCK_HEADER_LENGTH) {
            revert Decoder.WrongBlockHeaderLength(data.length);
        }

        blocks = new Block[](numHeaders);
        for (uint256 i = 0; i < numHeaders; i++) {
            blocks[i] = Decoder.parseBlock(data[Decoder.BLOCK_HEADER_LENGTH * i:Decoder.BLOCK_HEADER_LENGTH * (i + 1)]);
        }
        return blocks;
    }
}
