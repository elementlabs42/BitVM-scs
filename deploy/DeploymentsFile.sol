// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./File.sol";

contract DeploymentsFile is FileBase {
    using stdJson for string;

    string public constant DEPLOYMENTS_PATH = "deploy/Deployments.json";
    string private constant ROOT_KEY = "deployments";

    constructor() {
        reload(DEPLOYMENTS_PATH);
        if (!valid) {
            vm.writeJson("{}", path);
            reload(DEPLOYMENTS_PATH);
        }
    }

    function writeDeployment(address _storageAddress, address _bridgeAddress) public {
        string memory chainId = vm.toString(block.chainid);
        string memory timestamp = vm.toString(block.timestamp);
        string memory oldContent = content;
        string[] memory oldChainIds = vm.parseJsonKeys(oldContent, ".");
        for (uint256 i; i < oldChainIds.length; ++i) {
            string[] memory oldTimestamps = vm.parseJsonKeys(oldContent, string.concat(".", oldChainIds[i]));
            for (uint256 j; j < oldTimestamps.length; ++j) {
                string memory oldKey = string.concat(".", oldChainIds[i], ".", oldTimestamps[j]);
                string memory oldStorageAddress = oldContent.readString(string.concat(oldKey, ".storage"));
                string memory oldBridgeAddress = oldContent.readString(string.concat(oldKey, ".bridge"));
                oldTimestamps[j].serialize("storage", oldStorageAddress);
                content = oldTimestamps[j].serialize("bridge", oldBridgeAddress);
                content = oldChainIds[i].serialize(oldTimestamps[j], content);
            }
        }

        string memory storageAddress = vm.toString(_storageAddress);
        string memory bridgeAddress = vm.toString(_bridgeAddress);
        timestamp.serialize("storage", storageAddress);
        content = timestamp.serialize("bridge", bridgeAddress);
        content = chainId.serialize(timestamp, content);
        content = ROOT_KEY.serialize(chainId, content);
        vm.writeJson(content, path);
    }
}
