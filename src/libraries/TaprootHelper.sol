pragma solidity >=0.5.10;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "forge-std/console.sol";
import "./EllipticCurve.sol";

library TaprootHelper {
    using SafeMath for uint256;
    using EllipticCurve for uint256;

    uint256 constant private SECP256K1_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 constant private SECP256K1_A = 0;
    uint256 constant private SECP256K1_B = 7;

    function taggedHash(string memory tag, bytes memory m) internal pure returns (bytes32) {
        bytes32 tagHash = sha256(abi.encodePacked(tag));
        return sha256(abi.encodePacked(tagHash, tagHash, m));
    }

    function hash160(bytes memory data) internal pure returns (bytes20) {
        return ripemd160(abi.encodePacked(sha256(data)));
    }

    function createTaprootAddress(bytes32 n_of_n_pubkey, bytes[] memory scripts) public view returns (bytes32) {
        bytes32 internalKey = n_of_n_pubkey;

        bytes32 merkleRootHash = merkleRoot(scripts);


        bytes32 tweak = taggedHash("TapTweak", abi.encodePacked(internalKey, merkleRootHash));
        uint256 tweakInt = uint256(tweak);

        // Convert internalKey to elliptic curve point
        (uint256 x1, uint256 y1) = publicKeyToPoint(internalKey);

        // Convert tweak to elliptic curve point
        (uint256 x2, uint256 y2) = publicKeyToPoint(bytes32(tweakInt));

        // Add the points on the elliptic curve
        (uint256 x3, uint256 y3) = EllipticCurve.ecAdd(x1, y1, x2, y2, SECP256K1_A, SECP256K1_P);
        console.logUint(x3);
        console.logUint(y3);

        // Convert the resulting point back to bytes32
        bytes32 outputKey = pointToPublicKey(x3, y3);
        return outputKey;

    }

    function publicKeyToPoint(bytes32 pubKey) internal pure returns (uint256, uint256) {
        uint256 x = uint256(pubKey);
        uint8 prefix = (uint8(pubKey[31]) % 2 == 0) ? 0x02 : 0x03; // Determine parity for y-coordinate
        uint256 y = EllipticCurve.deriveY(prefix, x, SECP256K1_A, SECP256K1_B, SECP256K1_P);
        return (x, y);
    }

    function pointToPublicKey(uint256 x, uint256 y) internal pure returns (bytes32) {
        // Convert elliptic curve point (x, y) to compressed public key format
        bytes memory publicKey = new bytes(33);
        publicKey[0] = y % 2 == 0 ? bytes1(0x02) : bytes1(0x03);
        for (uint i = 0; i < 32; i++) {
            publicKey[32 - i] = bytes1(uint8(x >> (8 * i)));
        }
        return bytesToBytes32(publicKey);
    }


    function merkleRoot(bytes[] memory leaves) internal view returns (bytes32) {
        if (leaves.length == 0) {
            return bytes32(0);
        }
        while (leaves.length > 1) {
            if (leaves.length % 2 != 0) {
                bytes[] memory temp = new bytes[](leaves.length + 1);
                for (uint i = 0; i < leaves.length; i++) {
                    temp[i] = leaves[i];
                }
                temp[leaves.length] = leaves[leaves.length - 1];
                leaves = temp;
            }
            uint256 newLength = leaves.length / 2;
            bytes[] memory newLeaves = new bytes[](newLength);
            for (uint i = 0; i < newLength; i++) {
                newLeaves[i] = abi.encodePacked(taggedHash("TapBranch", abi.encodePacked(leaves[2 * i], leaves[2 * i + 1])));
            }
            leaves = newLeaves;
        }
        return bytesToBytes32(leaves[0]);
    }

    function toBech32(bytes20 data) internal pure returns (bytes memory) {
        bytes memory hrp = "bc";
        bytes memory combined = new bytes(data.length + 6);
        for (uint i = 0; i < data.length; i++) {
            combined[i] = data[i];
        }
        bytes32 polymod = bech32Polymod(hrpExpand(hrp), combined);
        for (uint i = 0; i < 6; i++) {
            combined[data.length + i] = bytes1(uint8(polymod[i] & 0x1F));
        }
        return abi.encodePacked(hrp, combined);
    }

    function bech32Polymod(bytes memory values1, bytes memory values2) internal pure returns (bytes32) {
        uint32[5] memory GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
        uint chk = 1;
        for (uint i = 0; i < values1.length; i++) {
            uint b = (chk >> 25);
            chk = (chk & 0x1ffffff) << 5 ^ uint8(values1[i]);
            for (uint j = 0; j < 5; j++) {
                chk ^= ((b >> j) & 1) != 0 ? GEN[j] : 0;
            }
        }
        for (uint i = 0; i < values2.length; i++) {
            uint b = (chk >> 25);
            chk = (chk & 0x1ffffff) << 5 ^ uint8(values2[i]);
            for (uint j = 0; j < 5; j++) {
                chk ^= ((b >> j) & 1) != 0 ? GEN[j] : 0;
            }
        }
        return bytes32(chk ^ 1);
    }

    function hrpExpand(bytes memory hrp) internal pure returns (bytes memory) {
        bytes memory expanded = new bytes(hrp.length * 2 + 1);
        for (uint i = 0; i < hrp.length; i++) {
            expanded[i] = bytes1(uint8(hrp[i]) >> 5);
            expanded[i + hrp.length + 1] = bytes1(uint8(hrp[i]) & 0x1F);
        }
        expanded[hrp.length] = bytes1(0);
        return expanded;
    }

    function bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        if (source.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }
}
