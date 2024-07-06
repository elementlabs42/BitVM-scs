// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IKeyBlocksStorage {
    struct KeyBlock {
        bytes32 blockHash;
        uint256 accumulatedDifficulty;
        uint256 timestamp;
    }

    error BlockCountInvalid(uint256 inputLength);
    error BlockHeightTooLow(uint256 inputHeight);
    error BlockHeightInvalid(uint256 inputHeight);
    error BlockHeightNotContinuous(uint256 inputHeight, uint256 storedLength);
    error BlockHashMismatch(bytes32 expected, bytes32 actual);
    error NoGivenBlockHeaders();
}
