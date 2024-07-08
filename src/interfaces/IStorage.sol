// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStorage {
    struct KeyBlock {
        bytes32 blockHash;
        uint256 accumulatedDifficulty;
        uint256 timestamp;
    }

    event KeyBlocksSubmitted(uint256 tip, uint256 total, uint256 reorg);

    error BlockCountInvalid(uint256 inputLength);
    error BlockHeightTooLow(uint256 inputHeight);
    error BlockHeightInvalid(uint256 inputHeight);
    error BlockHeightTooHigh(uint256 inputHeight, uint256 tipIndex);
    error BlockHashMismatch(bytes32 expected, bytes32 actual);
    error NoGivenBlockHeaders();
    error HashNotBelowTarget(bytes32 hash, bytes32 target);

    function submit(bytes calldata data, uint256 blockHeight) external;
    function getKeyBlock(uint256 blockHeight) external view returns (KeyBlock memory _block);
    function getKeyBlockCount() external view returns (uint256);

    function getFirstKeyBlock() external view returns (KeyBlock memory _block);
}
