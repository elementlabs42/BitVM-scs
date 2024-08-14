// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";
import "./mockup/BridgeTestnet.sol";
import "./Script.t.sol";

contract PegInTest is StorageFixture {
    function testPegIn_buildStorage() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        StorageSetupResult memory fixture = buildStorage(initNormal);
        string memory json = vm.readFile("test/fixture/test-data.json");

        uint256 step = abi.decode(vm.parseJson(json, ".pegIn.storage.constrcutor.step"), (uint256));
        bytes memory headers = abi.decode(vm.parseJson(json, ".pegIn.storage.submit[0].headers"), (bytes));

        IStorage _storage = IStorage(fixture._storage);
        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, headers.length / Coder.BLOCK_HEADER_LENGTH / step + 1);
    }

    function testPegIn_pegIn_normal() public {
        StorageSetupInfo memory initNormal = getNormalSetupInfo();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        (ProofParam memory proofParam1, ProofParam memory proofParam2) = getPegInProofParamNormal();

        ProofInfo memory proof1 = Util.paramToProof(proofParam1, false);
        ProofInfo memory proof2 = Util.paramToProof(proofParam2, false);

        Bridge bridge = Bridge(fixture.bridge);
        bridge.pegIn(
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
            hex"edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b",
            proof1,
            proof2
        );
        assertEq(true, true);
    }
}
