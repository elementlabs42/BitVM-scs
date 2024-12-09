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

        vm.startBroadcast(ownerPrivateKey);
        IStorage _storage = _deployStorage(params);
        EBTCTest ebtcTest = _deployEbtc();
        (IBridge bridge, EBTC ebtc) = _deployBridge(_storage, ebtcTest);

        _mintForTesting(withdrawer, ebtcTest);
        vm.stopBroadcast();

        deployments.writeDeployment(address(_storage), address(bridge), address(ebtc));
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

    function _deployBridge(IStorage _storage, EBTCTest ebtcTest) public returns (IBridge bridge, EBTC ebtc) {
        ebtc = EBTC(ebtcTest);
        bridge = new BridgeTestnet(ebtc, _storage, data.nOfNPubKey(), data.pegInTimelock());
        ebtc.setBridge(address(bridge));
    }

    function _deployEbtc() public returns (EBTCTest ebtcTest) {
        ebtcTest = new EBTCTest(address(0));
    }

    function _mintForTesting(address receipient, EBTCTest ebtcTest) public {
        ebtcTest.mintForTest(receipient, 100 ** ebtcTest.decimals());
    }

    function _submit(IStorage _storage, StorageSetupInfo memory params) public {
        _storage.submit(params.headers, params.startHeight);
    }
}
