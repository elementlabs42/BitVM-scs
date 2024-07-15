// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Util {
    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory ret = new bytes(length);
        for (uint256 i = start; i < length;) {
            ret[i - start] = data[i];
            unchecked {
                ++i;
            }
        }
        return ret;
    }
}
