// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/libraries/Base58.sol";
import "../src/libraries/TaprootHelper.sol";
import "../src/libraries/TransactionHelper.sol";
import "../src/interfaces/IBridge.sol";

library Util {
    using ViewSPV for bytes4;
    using TypedMemView for bytes;

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

    function reverseProofParams(ProofParam memory _proof) public pure returns (ProofParam memory) {
        _proof.merkleProof = Endian.reverse256Array(_proof.merkleProof);
        return _proof;
    }

    function paramToProof(ProofParam calldata _proofParam, bool reverse) public view returns (ProofInfo memory) {
        ProofParam memory proofParam = reverse ? reverseProofParams(_proofParam) : _proofParam;
        (bytes4 version, bytes4 locktime, bytes memory rawVin, bytes memory rawVout) =
            TransactionHelper.parseRawTx(proofParam.rawTx);

        ProofInfo memory proofInfo = ProofInfo({
            version: version,
            locktime: locktime,
            txId: version.calculateTxId(
                rawVin.ref(uint40(ViewBTC.BTCTypes.Vin)), rawVout.ref(uint40(ViewBTC.BTCTypes.Vout)), locktime
            ),
            merkleProof: proofParam.merkleProof,
            index: proofParam.index,
            header: proofParam.blockHeader,
            parents: proofParam.parents,
            children: proofParam.children,
            blockHeight: proofParam.blockHeight,
            rawVin: rawVin,
            rawVout: rawVout
        });

        return proofInfo;
    }

    bytes1 constant P2PKH_MAINNET = 0x00;
    bytes1 constant P2SH_MAINNET = 0x05;
    bytes1 constant P2PKH_TESTNET = 0x6f;
    bytes1 constant P2SH_TESTNET = 0xc4;

    function generateAddress(bytes memory pubKey, bytes1 network) public pure returns (string memory addr) {
        bytes20 _hash160 = TaprootHelper.hash160(pubKey);
        // Mainnet: p2pkh 0x00, p2sh 0x05, Testnet: p2pkh 0x6f, p2sh 0xc4
        bytes memory pubKeyWithNetwork = abi.encodePacked(network, _hash160);
        bytes4 checksum = bytes4(sha256(abi.encodePacked(sha256(pubKeyWithNetwork))));
        bytes memory addrBytes = Base58.encode(abi.encodePacked(network, _hash160, checksum));
        addr = toString(addrBytes);
    }

    function toString(bytes memory byteCode) public pure returns (string memory stringData) {
        uint256 blank = 0; //blank 32 byte value
        uint256 length = byteCode.length;

        uint256 cycles = byteCode.length / 0x20;
        uint256 requiredAlloc = length;

        if (
            length % 0x20 > 0 //optimise copying the final part of the bytes - to avoid looping with single byte writes
        ) {
            cycles++;
            requiredAlloc += 0x20; //expand memory to allow end blank, so we don't smack the next stack entry
        }

        stringData = new string(requiredAlloc);

        //copy data in 32 byte blocks
        assembly {
            let cycle := 0

            for {
                let mc := add(stringData, 0x20) //pointer into bytes we're writing to
                let cc := add(byteCode, 0x20) //pointer to where we're reading from
            } lt(cycle, cycles) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
                cycle := add(cycle, 0x01)
            } { mstore(mc, mload(cc)) }
        }

        //finally blank final bytes and shrink size (part of the optimisation to avoid looping adding blank bytes1)
        if (length % 0x20 > 0) {
            uint256 offsetStart = 0x20 + length;
            assembly {
                let mc := add(stringData, offsetStart)
                mstore(mc, mload(add(blank, 0x20)))
                //now shrink the memory back so the returned object is the correct size
                mstore(stringData, length)
            }
        }
    }
}
