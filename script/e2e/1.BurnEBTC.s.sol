// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../../test/mockup/EBTCTest.sol";
import "../../test/mockup/StorageTestnet.sol";
import "../../test/mockup/BridgeTestnet.sol";
import {Util} from "../../test/utils/Util.sol";
import {TestData} from "../../test/fixture/TestData.sol";
import {DeploymentsFile} from "../DeploymentsFile.sol";
import {StorageFixture, StorageSetupInfo} from "../../test/fixture/StorageFixture.sol";
import {Outpoint, ProofInfo} from "../../src/interfaces/IBridge.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract End2End is Script {
    TestData data;
    DeploymentsFile deployments;
    Chain[] customChains;

    function setUp() public {
        customChains.push(
            Chain({name: "Anvil-For-UI", chainId: 831337, chainAlias: "anvil4ui", rpcUrl: "http://localhost:8545"})
        );
        for (uint256 i = 0; i < customChains.length; i++) {
            setChain(customChains[i].chainAlias, customChains[i]);
        }

        data = new TestData();
        if (!data.valid()) {
            revert("Invalid Data file");
        }

        deployments = new DeploymentsFile(customChains);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY_0");
        address withdrawer = vm.addr(vm.envUint("PRIVATE_KEY_1"));
        StorageSetupInfo memory params = data._storage(data.pegOutStorageKey());
        (, address bridgeAddress, address ebtc) = deployments.getLastRunDeployment();
        ProofInfo memory proof = Util.paramToProof(data.proof(data.pegOutProofKey()), false);

        vm.startBroadcast(ownerPrivateKey);
        // deploy new and reset storage for testing purpose
        IStorage _storage = _deployStorage(params);
        BridgeTestnet(bridgeAddress).setBlockStorage(_storage);

        IBridge(bridgeAddress).burnEBTC(withdrawer, proof);
        vm.stopBroadcast();

        deployments.writeDeployment(address(_storage), address(bridgeAddress), address(ebtc));
    }

    function _deployStorage(StorageSetupInfo memory params) public returns (IStorage _storage) {
        _storage = new StorageTestnet(
            params.step,
            params.height,
            IStorage.KeyBlock(params.blockHash, 0, params.timestamp),
            IStorage.Epoch(bytes4(Endian.reverse32(params.bits)), params.epochTimestamp)
        );
        _submit(_storage, params);
    }

    function _submit(IStorage _storage, StorageSetupInfo memory params) public {
        _storage.submit(params.headers, params.startHeight);
    }
}
