// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../test/mockup/EBTCTest.sol";
import "../test/mockup/StorageTestnet.sol";
import "../test/mockup/BridgeTestnet.sol";
import {Util} from "../test/utils/Util.sol";
import {TestData} from "../test/fixture/TestData.sol";
import {DeploymentsFile} from "./DeploymentsFile.sol";
import {StorageFixture, StorageSetupInfo} from "../test/fixture/StorageFixture.sol";
import {Outpoint, ProofInfo} from "../src/interfaces/IBridge.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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
        _deploy(false);
    }

    function runTestnet() public {
        _deploy(true);
    }

    function submit() public {
        StorageSetupInfo memory params = data._storage(data.pegOutStorageKey());
        (address storageAddress,,) = deployments.getLastRunDeployment();
        IStorage _storage = Storage(storageAddress);

        _submit(_storage, params);
    }

    function submitTestnet() public {
        StorageSetupInfo memory params = data._storage(data.pegOutStorageKey());
        (address storageAddress,,) = deployments.getLastRunDeployment();
        IStorage _storage = StorageTestnet(storageAddress);

        _submit(_storage, params);
    }

    function pegOut() public {
        uint256 withdrawerPrivateKey = vm.envUint("PRIVATE_KEY_1");
        (, address bridgeAddress, address ebtcAddress) = deployments.getLastRunDeployment();
        string memory withdrawerAddr = Util.generateAddress(data.withdrawerPubKey(), Util.P2PKH_TESTNET);

        vm.startBroadcast(withdrawerPrivateKey);
        IERC20(ebtcAddress).approve(bridgeAddress, type(uint256).max);
        IBridge(bridgeAddress).pegOut(
            withdrawerAddr, Outpoint(hex"1234", 0), data.pegOutAmount(), data.operatorPubKey()
        );
        vm.stopBroadcast();
    }

    function burnEBTC() public {
        uint256 operatorPrivateKey = vm.envUint("PRIVATE_KEY_0");
        uint256 withdrawerPrivateKey = vm.envUint("PRIVATE_KEY_1");
        (, address bridgeAddress,) = deployments.getLastRunDeployment();
        ProofInfo memory proof = Util.paramToProof(data.proof(data.pegOutProofKey()), false);

        vm.startBroadcast(operatorPrivateKey);
        IBridge(bridgeAddress).burnEBTC(vm.addr(withdrawerPrivateKey), proof);
        vm.stopBroadcast();
    }

    function resetStorage() public {
        uint256 operatorPrivateKey = vm.envUint("PRIVATE_KEY_0");
        (, address bridgeAddress,) = deployments.getLastRunDeployment();

        IStorage _storage = _deployStorage(true);

        vm.startBroadcast(operatorPrivateKey);
        BridgeTestnet(bridgeAddress).setBlockStorage(_storage);
        vm.stopBroadcast();
    }

    function _deploy(bool useTestnet) public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_0");

        IStorage _storage = _deployStorage(useTestnet);

        vm.startBroadcast(privateKey);

        EBTCTest ebtcTest = new EBTCTest(address(0));
        EBTC ebtc = EBTC(ebtcTest);
        IBridge bridge = useTestnet
            ? new BridgeTestnet(ebtc, _storage, data.nOfNPubKey(), data.pegInTimelock())
            : new Bridge(ebtc, _storage, data.nOfNPubKey());
        ebtc.setBridge(address(bridge));

        _mintForTesting(ebtcTest);

        vm.stopBroadcast();

        deployments.writeDeployment(address(_storage), address(bridge), address(ebtc));
    }

    function _deployStorage(bool useTestnet) public returns (IStorage) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_0");
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

        vm.stopBroadcast();

        _submit(_storage, params);

        return _storage;
    }

    function _mintForTesting(EBTCTest ebtc) public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_1");
        address withdrawer = vm.addr(privateKey);
        ebtc.mintForTest(withdrawer, 100 ** ebtc.decimals());
    }

    function _submit(IStorage _storage, StorageSetupInfo memory params) public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_0");
        vm.startBroadcast(privateKey);
        _storage.submit(params.headers, params.startHeight);
        vm.stopBroadcast();
    }
}
