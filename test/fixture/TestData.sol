// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../../src/interfaces/IBridge.sol";
import {StorageSetupInfo} from "./StorageFixture.sol";

contract TestData is Script {
    error InvalidContent();

    bool public valid;
    string public constant JSON_PATH = "test/fixture/test-data.json";
    string private jsonContent;

    modifier validated() {
        if (!valid) {
            revert InvalidContent();
        }
        _;
    }

    constructor() {
        reload();
    }

    function reload() public {
        try vm.readFile(JSON_PATH) returns (string memory _jsonContent) {
            jsonContent = _jsonContent;
            valid = true;
        } catch {
            valid = false;
        }
    }

    function depositor() public view validated returns (address) {
        return abi.decode(vm.parseJson(jsonContent, ".pegIn.depositor"), (address));
    }

    function withdrawer() public view validated returns (address) {
        return abi.decode(vm.parseJson(jsonContent, ".pegOut.withdrawer"), (address));
    }

    function pegOutTimestamp() public view validated returns (uint256) {
        return abi.decode(vm.parseJson(jsonContent, ".pegOut.pegOutTimestamp"), (uint256));
    }

    function pegOutAmount() public view validated returns (uint256) {
        return abi.decode(vm.parseJson(jsonContent, ".pegOut.amount"), (uint256));
    }

    function _storage(string memory keyPrefix) public view validated returns (StorageSetupInfo memory) {
        uint256 step = abi.decode(node(string.concat(keyPrefix, ".constrcutor.step")), (uint256));
        uint256 height = abi.decode(node(string.concat(keyPrefix, ".constrcutor.height")), (uint256));
        bytes32 blockHash = bytes32(abi.decode(node(string.concat(keyPrefix, ".constrcutor.hash")), (bytes32)));
        uint32 timestamp = uint32(abi.decode(node(string.concat(keyPrefix, ".constrcutor.timestamp")), (uint256)));
        uint32 bits = uint32(abi.decode(node(string.concat(keyPrefix, ".constrcutor.bits")), (uint256)));
        uint32 epochTimestamp =
            uint32(abi.decode(node(string.concat(keyPrefix, ".constrcutor.epochTimestamp")), (uint256)));
        bytes memory headers = abi.decode(node(string.concat(keyPrefix, ".submit[0].headers")), (bytes));
        return StorageSetupInfo(step, height, blockHash, bits, timestamp, epochTimestamp, height + 1, headers);
    }

    function proof(string memory keyPrefix) public view validated returns (ProofParam memory) {
        bytes memory merkleProof = abi.decode(node(string.concat(keyPrefix, ".merkleProof")), (bytes));
        bytes memory parents = abi.decode(node(string.concat(keyPrefix, ".parents")), (bytes));
        bytes memory children = abi.decode(node(string.concat(keyPrefix, ".children")), (bytes));
        bytes memory rawTx = abi.decode(node(string.concat(keyPrefix, ".rawTx")), (bytes));
        uint256 index = abi.decode(node(string.concat(keyPrefix, ".index")), (uint256));
        uint256 blockHeight = abi.decode(node(string.concat(keyPrefix, ".blockHeight")), (uint256));
        bytes memory blockHeader = abi.decode(node(string.concat(keyPrefix, ".blockHeader")), (bytes));

        return ProofParam({
            merkleProof: merkleProof,
            parents: parents,
            children: children,
            rawTx: rawTx,
            index: index,
            blockHeight: blockHeight,
            blockHeader: blockHeader
        });
    }

    function node(string memory key) public view validated returns (bytes memory) {
        return vm.parseJson(jsonContent, key);
    }

    function pegInStorageKey() public pure returns (string memory) {
        return ".pegIn.storage";
    }

    function pegOutStorageKey() public pure returns (string memory) {
        return ".pegOut.storage";
    }

    function pegInProofKey(string memory index) public pure returns (string memory) {
        return string.concat(".pegIn.verification.proof", index);
    }

    function pegOutProofKey() public pure returns (string memory) {
        return ".pegOut.verification.proof";
    }
}
