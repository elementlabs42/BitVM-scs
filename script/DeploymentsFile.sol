// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./File.sol";
import "forge-std/StdChains.sol";

contract DeploymentsFile is FileBase, StdChains {
    using stdJson for string;

    string public constant DEPLOYMENTS_PATH = "script/Deployments.json";
    string private constant ROOT_KEY = "deployments";

    constructor() {
        reload(DEPLOYMENTS_PATH);
        if (!valid) {
            vm.writeJson("{}", path);
            reload(DEPLOYMENTS_PATH);
        }
    }

    function writeDeployment(address _storageAddress, address _bridgeAddress, address ebtcAddress) public {
        string memory chain = getChain(block.chainid).name;
        string memory timestamp = vm.toString(block.timestamp);
        string memory oldContent = content;
        loadOldContent(oldContent);

        string memory storageAddress = vm.toString(_storageAddress);
        string memory bridgeAddress = vm.toString(_bridgeAddress);
        timestamp.serialize("storage", storageAddress);
        content = timestamp.serialize("bridge", bridgeAddress);
        content = timestamp.serialize("ebtc", ebtcAddress);
        content = chain.serialize(timestamp, content);
        content = ROOT_KEY.serialize(chain, content);
        vm.writeJson(content, path);
    }

    function getLastRunDeployment() public returns (address _storage, address bridge, address ebtc) {
        reload(DEPLOYMENTS_PATH);
        string memory chain = getChain(block.chainid).name;
        string memory timestamp = getLatestDeploymentTimestamp();
        string memory keyPrefix = string.concat(".", chain, ".", timestamp);
        bridge = abi.decode(node(string.concat(keyPrefix, ".bridge")), (address));
        _storage = abi.decode(node(string.concat(keyPrefix, ".storage")), (address));
        ebtc = abi.decode(node(string.concat(keyPrefix, ".ebtc")), (address));
    }

    function getLatestDeploymentTimestamp() public returns (string memory) {
        reload(DEPLOYMENTS_PATH);
        string memory chain = getChain(block.chainid).name;
        string[] memory chains = vm.parseJsonKeys(content, ".");
        require(indexOf(chains, chain) != -1, "Storage has not been deployed yet for current chain");
        string[] memory timestamps = vm.parseJsonKeys(content, string.concat(".", chain));
        return timestamps[timestamps.length - 1];
    }

    /**
     * @dev reload content with json parser format as a workaround,
     *      the parser in 'vm.parseJson*' seems not understand the 'pretty' format,
     *      which is the output of the 'vm.writeJson'
     */
    function loadOldContent(string memory oldContent) public {
        string[] memory oldChains = vm.parseJsonKeys(oldContent, ".");
        for (uint256 i; i < oldChains.length; ++i) {
            string[] memory oldTimestamps = vm.parseJsonKeys(oldContent, string.concat(".", oldChains[i]));
            for (uint256 j; j < oldTimestamps.length; ++j) {
                string[] memory oldDeploymentItems =
                    vm.parseJsonKeys(oldContent, string.concat(".", oldChains[i], ".", oldTimestamps[j]));
                string memory oldKeyPrefix = string.concat(".", oldChains[i], ".", oldTimestamps[j]);
                for (uint256 k; k < oldDeploymentItems.length; ++k) {
                    string memory item = oldContent.readString(string.concat(oldKeyPrefix, ".", oldDeploymentItems[k]));
                    content = oldTimestamps[j].serialize(oldDeploymentItems[k], item);
                }
                content = oldChains[i].serialize(oldTimestamps[j], content);
            }
            content = ROOT_KEY.serialize(oldChains[i], content);
        }
    }

    function indexOf(string[] memory stack, string memory needle) public pure returns (int256 index) {
        if (stack.length == 0) {
            return -1;
        }
        for (uint256 i; i < stack.length; ++i) {
            if (bytes(stack[i]).length != bytes(needle).length) {
                continue;
            }
            if (keccak256(abi.encodePacked(stack[i])) == keccak256(abi.encodePacked(needle))) {
                return int256(i);
            }
        }
        return -1;
    }
}
