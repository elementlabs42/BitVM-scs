// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Util {
    function slice(bytes memory data, uint256 start, uint256 length) public pure returns (bytes memory) {
        bytes memory ret = new bytes(length);
        for (uint256 i = start; i < length;) {
            ret[i - start] = data[i];
            unchecked {
                ++i;
            }
        }
        return ret;
    }

    function fill(uint256 length, bytes calldata chunk) public pure returns (bytes memory ret) {
        require(chunk.length > 0, "chunk length must be > 0");
        require(length % chunk.length == 0, "length must be a multiple of chunk length");

        for (uint256 i; i < length / chunk.length; ++i) {
            ret = abi.encodePacked(ret, chunk);
        }

        require(ret.length == length, "ret length must be == length");
    }

    function splitInto32(bytes memory data) public pure returns (bytes32[] memory) {
        require(data.length > 0, "data length must be > 0");
        require(data.length % 32 == 0, "data length must be a multiple of 32");
        bytes32[] memory ret = new bytes32[](data.length / 32);
        for (uint256 i; i < data.length / 32; ++i) {
            ret[i] = bytes32(slice(data, i * 32, 32));
        }
        return ret;
    }
}
