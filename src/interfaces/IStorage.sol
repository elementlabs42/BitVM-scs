// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStorage {
    struct KeyBlock {
        bytes32 blockHash;
        uint256 accumulatedDifficulty;
        bytes4 bits;
        uint32 timestamp;
    }

    struct CheckBlockContext {
        uint256 accumulatedDifficulty;
        bytes32 previousHash;
        uint256 possibleRetargetCount;
        uint256 currentPeriodTarget;
    }

    event KeyBlocksSubmitted(uint256 tip, uint256 total, uint256 reorg);

    error BlockStepDistanceInvalid(uint256 inputDistance);
    error BlockCountInvalid(uint256 inputLength);
    error BlockHeightTooLow(uint256 inputHeight);
    error BlockHeightInvalid(uint256 inputHeight);
    error BlockHeightTooHigh(uint256 inputHeight, uint256 tipIndex);
    error BlockHashMismatch(bytes32 expected, bytes32 actual);
    error ChainWorkNotEnough();
    error NoGivenBlockHeaders();
    error RetargetTooFrequent();
    error HashNotBelowTarget(bytes32 hash, bytes32 target);

    function submit(bytes calldata data, uint256 blockHeight) external;
    function getKeyBlock(uint256 blockHeight) external view returns (KeyBlock memory _block);
    function getKeyBlockCount() external view returns (uint256);
}
