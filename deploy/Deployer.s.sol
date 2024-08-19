// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/EBTC.sol";
import "../test/mockup/StorageTestnet.sol";
import "../test/mockup/BridgeTestnet.sol";
import {TestData} from "../test/fixture/TestData.sol";
import {DeploymentsFile} from "./DeploymentsFile.sol";
import {StorageFixture, StorageSetupInfo} from "../test/fixture/StorageFixture.sol";

contract Deployer is Script {
    TestData data;
    DeploymentsFile deployments;

    function setUp() public {
        data = new TestData();
        if (!data.valid()) {
            revert("Invalid Data file");
        }
        deployments = new DeploymentsFile();
    }

    function run() public {
        _run(false);
    }

    function testnet() public {
        _run(true);
    }

    function _run(bool useTestnet) public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        StorageSetupInfo memory params = data._storage(data.pegOutStorageKey());

        vm.startBroadcast(privateKey);

        IStorage _storage = useTestnet
            ? new StorageTestnet(
                params.step,
                params.height,
                IStorage.KeyBlock(params.blockHash, 0, params.timestamp),
                IStorage.Epoch(bytes4(Endian.reverse32(params.bits)), params.epochTimestamp)
            )
            : new Storage(
                params.step,
                params.height,
                IStorage.KeyBlock(params.blockHash, 0, params.timestamp),
                IStorage.Epoch(bytes4(Endian.reverse32(params.bits)), params.epochTimestamp)
            );

        EBTC ebtc = new EBTC(address(0));
        Bridge bridge = useTestnet
            ? new BridgeTestnet(ebtc, _storage, data.nOfNPubKey())
            : new Bridge(ebtc, _storage, data.nOfNPubKey());
        ebtc.setBridge(address(bridge));

        vm.stopBroadcast();

        deployments.writeDeployment(address(_storage), address(bridge));
    }
}
