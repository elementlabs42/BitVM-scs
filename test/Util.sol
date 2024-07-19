// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/libraries/Endian.sol";

library Util {
    bytes private constant NIBBLE_LOOKUP = "0123456789abcdef";
    
    function slice(bytes memory data, uint256 start, uint256 length) external pure returns (bytes memory) {
        bytes memory ret = new bytes(length);
        for (uint256 i = start; i < length;) {
            ret[i - start] = data[i];
            unchecked {
                ++i;
            }
        }
        return ret;
    }

    function fill(uint256 length, bytes calldata chunk) external pure returns (bytes memory ret) {
        require(chunk.length > 0, "chunk length must be > 0");
        require(length % chunk.length == 0, "length must be a multiple of chunk length");

        for (uint256 i; i < length / chunk.length; ++i) {
            ret = abi.encodePacked(ret, chunk);
        }

        require(ret.length == length, "ret length must be == length");
    }

    /**
     * @dev Recomputes the transaction ID for a raw transaction.
     */
    function getTxID(bytes memory rawTransaction)
        public
        pure
        returns (bytes32)
    {
        bytes32 ret = doubleSha(rawTransaction);
        return bytes32(Endian.reverse256(uint256(ret)));
    }

        /**
     * @dev Computes the ubiquitious Bitcoin SHA256(SHA256(x))
     */
    function doubleSha(bytes memory buf) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(buf)));
    }

    function encodeHex(uint256 _b) internal pure returns (uint256 first, uint256 second) {
        for (uint8 i = 31; i > 15; i -= 1) {
            uint8 _byte = uint8(_b >> (i * 8));
            first |= byteHex(_byte);
            if (i != 16) {
                first <<= 16;
            }
        }

        unchecked {
            // abusing underflow here =_=
            for (uint8 i = 15; i < 255; i -= 1) {
                uint8 _byte = uint8(_b >> (i * 8));
                second |= byteHex(_byte);
                if (i != 0) {
                    second <<= 16;
                }
            }
        }
    }

    function byteHex(uint8 _b) internal pure returns (uint16 encoded) {
        encoded |= nibbleHex(_b >> 4); // top 4 bits
        encoded <<= 8;
        encoded |= nibbleHex(_b); // lower 4 bits
    }

    function nibbleHex(uint8 _byte) internal pure returns (uint8 _char) {
        uint8 _nibble = _byte & 0x0f; // keep bottom 4, 0 top 4
        _char = uint8(NIBBLE_LOOKUP[_nibble]);
    }
}
