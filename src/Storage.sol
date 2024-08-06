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
    uint256 public immutable initialEpochNumber;

    KeyBlock[] private storedBlocks;
    /**
     * @dev index of the last stored block, to represent length of storedBlocks
     *      stored separately since chain can be shorter when reorg
     */
    uint256 private tipIndex;
    Epoch[] storedEpochs;
    /**
     * @dev index of last stored epoch, to represent length of storedEpochs
     *      it is also the number of times that chain has been retargeted up to the tip of storedBlocks
     *      stored separately since storedEpochs can be shorter when reorg
     */
    uint256 tipEpochIndex;

    /**
     * @param distance block height distance for every key blocks
     * @param initialBlock initial key block
     * @param initialEpoch initial epoch
     */
    constructor(uint256 distance, uint256 blockHeight, KeyBlock memory initialBlock, Epoch memory initialEpoch) {
        if (distance == 0) {
            revert BlockStepDistanceInvalid(distance);
        }
        blockStepDistance = distance;
        initialBlockHeight = blockHeight;
        initialEpochNumber = blockHeight / Coder.EPOCH_BLOCK_COUNT;
        storedBlocks.push(initialBlock);
        storedEpochs.push(initialEpoch);
    }

    /**
     * @param data concatenated and continuous block headers as seen in explorer,
     *             the length should be multiple of Coder.BLOCK_HEADER_LENGTH * blockStepDistance
     * @param blockHeight first block height in @param data,
     *                    the value should be any storedBlock height + 1
     */
    function submit(bytes calldata data, uint256 blockHeight) external override {
        if (data.length == 0 || blockHeight == 0) {
            revert NoGivenBlockHeaders();
        }

        uint256 previousHeight = blockHeight - 1;
        uint256 index = heightToIndex(previousHeight);
        if ((previousHeight - initialBlockHeight) % blockStepDistance != 0) {
            revert BlockHeightInvalid(blockHeight);
        }
        if (tipIndex < index) {
            revert BlockHeightTooHigh(blockHeight);
        }

        uint256 headerCount = data.length / Coder.BLOCK_HEADER_LENGTH;
        if (data.length != headerCount * Coder.BLOCK_HEADER_LENGTH) {
            revert Coder.BlockHeaderLengthInvalid(data.length);
        }
        if (headerCount % blockStepDistance != 0) {
            revert BlockCountInvalid(headerCount);
        }

        uint256 epochIndex = previousHeight / Coder.EPOCH_BLOCK_COUNT - initialEpochNumber;
        Epoch memory epoch = storedEpochs[epochIndex];
        KeyBlock memory previousKeyBlock = storedBlocks[index];
        // to prevent stack too deep, using a context variable in function checkBlock
        CheckBlockContext memory ctx = CheckBlockContext(
            previousKeyBlock.accumulatedDifficulty,
            previousKeyBlock.blockHash,
            previousKeyBlock.timestamp,
            epoch,
            epochIndex
        );
        uint256 accumulatedDifficulty = storedBlocks[tipIndex].accumulatedDifficulty;
        uint256 reorgCount = tipIndex - index;
        for (uint256 i; i < headerCount; ++i) {
            uint256 height = blockHeight + i;
            bytes calldata header = data[Coder.BLOCK_HEADER_LENGTH * i:Coder.BLOCK_HEADER_LENGTH * (i + 1)];
            uint32 timestamp = checkBlock(height, header, ctx);
            ctx.prevBlockTimestamp = timestamp;

            if (height % blockStepDistance == initialBlockHeight % blockStepDistance) {
                ++index;
                KeyBlock memory keyBlock = KeyBlock(ctx.prevHash, ctx.accumulatedDifficulty, timestamp);
                if (tipIndex >= index) {
                    storedBlocks[index] = keyBlock;
                } else {
                    storedBlocks.push(keyBlock);
                }
            }
        }

        if (ctx.accumulatedDifficulty <= accumulatedDifficulty) {
            revert ChainWorkNotEnough();
        }

        emit KeyBlocksSubmitted(indexToHeight(index), headerCount, reorgCount);
        tipIndex = index;
    }

    function checkBlock(uint256 height, bytes memory header, CheckBlockContext memory ctx) internal returns (uint32) {
        Block memory _block = Coder.decodeBlockPartial(header);
        if (ctx.prevHash != _block.previousBlockHash) {
            revert BlockHashMismatch(ctx.prevHash, _block.previousBlockHash);
        }
        uint256 target = Coder.toTarget(_block.bits);
        retargetIfNeeded(_block.timestamp, height, ctx);
        if (ctx.prevEpoch.bits != _block.bits) {
            revert BlockBitsMismatch(ctx.prevEpoch.bits, _block.bits);
        }

        bytes32 _hash = Coder.toHash(header);
        if (uint256(_hash) >= target) {
            revert HashNotBelowTarget(_hash, bytes32(target));
        }
        ctx.accumulatedDifficulty += Coder.toDifficulty(target);
        ctx.prevHash = _hash;
        return _block.timestamp;
    }

    function retargetIfNeeded(uint32 timestamp, uint256 height, CheckBlockContext memory ctx) internal virtual {
        if (height % Coder.EPOCH_BLOCK_COUNT == 0) {
            bytes4 newBits = Coder.retargetWithBits(ctx.prevEpoch.bits, ctx.prevEpoch.timestamp, ctx.prevBlockTimestamp);
            ctx.prevEpoch.bits = newBits;
            ctx.prevEpoch.timestamp = timestamp;

            ++ctx.prevEpochIndex;
            Epoch memory newEpoch = Epoch(newBits, timestamp);
            if (tipEpochIndex >= ctx.prevEpochIndex) {
                storedEpochs[ctx.prevEpochIndex] = newEpoch;
                emit ChainRetargeted(ctx.prevEpochIndex, height, newBits, timestamp, true);
            } else {
                storedEpochs.push(newEpoch);
                emit ChainRetargeted(ctx.prevEpochIndex, height, newBits, timestamp, false);
            }
            tipEpochIndex = ctx.prevEpochIndex;
        }
    }

    function getKeyBlock(uint256 blockHeight) external view override returns (KeyBlock memory _block) {
        uint256 index = heightToIndex(blockHeight);
        if (tipIndex < index) {
            revert BlockHeightTooHigh(blockHeight);
        }
        _block = storedBlocks[index];
    }

    function getNextKeyBlock(uint256 blockHeight) external view override returns (KeyBlock memory _block) {
        uint256 index = heightToIndex(blockHeight);
        uint256 nextIndex = index + 1;
        if (tipIndex < nextIndex) {
            revert BlockHeightTooHigh(blockHeight);
        }
        _block = storedBlocks[nextIndex];
    }

    function getKeyBlockCount() external view override returns (uint256) {
        return tipIndex + 1;
    }

    function getEpoch(uint256 blockHeight) external view override returns (Epoch memory _epoch) {
        if (blockHeight < initialBlockHeight) {
            revert BlockHeightTooLow(blockHeight);
        }
        uint256 epochIndex;
        unchecked {
            epochIndex = blockHeight / Coder.EPOCH_BLOCK_COUNT - initialEpochNumber;
        }

        if (tipEpochIndex < epochIndex) {
            revert BlockHeightTooHigh(blockHeight);
        }
        _epoch = storedEpochs[epochIndex];
    }

    function getEpochCount() external view override returns (uint256) {
        return tipEpochIndex + 1;
    }

    function getFirstKeyBlock() external view returns (KeyBlock memory _block) {
        return storedBlocks[0];
    }

    function getLastKeyBlock() external view returns (KeyBlock memory _block) {
        return storedBlocks[tipIndex];
    }

    function getFirstEpoch() external view override returns (Epoch memory _epoch) {
        return storedEpochs[0];
    }

    function indexToHeight(uint256 index) internal view returns (uint256) {
        return initialBlockHeight + index * blockStepDistance;
    }

    function heightToIndex(uint256 blockHeight) internal view returns (uint256) {
        if (blockHeight < initialBlockHeight) {
            revert BlockHeightTooLow(blockHeight);
        }

        unchecked {
            return (blockHeight - initialBlockHeight) / blockStepDistance;
        }
    }
}
