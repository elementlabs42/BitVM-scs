// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../src/Storage.sol";

/**
 * @dev ignore retargeting for test net
 */
contract StorageTestnet is Storage {
    constructor(uint256 distance, uint256 blockHeight, KeyBlock memory initialBlock, Epoch memory initialEpoch)
        Storage(distance, blockHeight, initialBlock, initialEpoch)
    {}

    function retargetIfNeeded(uint32 timestamp, uint256 height, CheckBlockContext memory ctx) internal override {
        if (height % Coder.EPOCH_BLOCK_COUNT == 0) {
            bytes4 newBits = ctx.prevEpoch.bits;
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
}
