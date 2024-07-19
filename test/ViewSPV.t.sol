// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBridge.sol";
import "../src/libraries/ViewSPV.sol";
import "./fixture/ConstantsFixture.sol";
import "./Util.sol";

contract ViewSPVTest is Test, ConstantsFixture {
    using TypedMemView for bytes;

    function testViewSPV_prove_emptyParameters() public {
        bytes32 txid;
        bytes32 merkleRoot;
        bytes29 merkleProof;
        uint256 index;
        vm.expectRevert(abi.encodeWithSelector(ViewSPV.EmptyMemView.selector));
        ViewSPV.prove(txid, merkleRoot, merkleProof, index);
    }

    function testViewSPV_prove_emptyBlock() public pure {
        uint8 SHIFT_TO_TYPE = 96 + 96 + 24;

        bytes32 txid;
        bytes32 merkleRoot;
        ViewBTC.BTCTypes _type = ViewBTC.BTCTypes.MerkleArray;
        bytes29 merkleProof;
        assembly {
            // solium-disable-previous-line security/no-inline-assembly
            merkleProof := shl(SHIFT_TO_TYPE, _type) // append lower 27 bytes
        }
        uint256 index;
        bool result = ViewSPV.prove(txid, merkleRoot, merkleProof, index);
        assertEq(result, true);
    }

    function testViewSPV_prove_block() public view {
        uint8 SHIFT_TO_TYPE = 96 + 96 + 24;

        bytes memory _tx = tx736;
        bytes32 _txid = Util.getTxID(_tx);
        (uint256 a, uint256 b) = Util.encodeHex(uint256(_txid));
        console.log("testProveBlock() _txid", string(abi.encodePacked("0x", a, b)));

        bytes memory _merkleProof = txProof736;

        bytes32 _merkleRoot = txRoot736;
        uint256 _index = txIndex736;

        ViewBTC.BTCTypes _type = ViewBTC.BTCTypes.MerkleArray;
        bytes29 merkleProof;
        assembly {
            // solium-disable-previous-line security/no-inline-assembly
            merkleProof := shl(SHIFT_TO_TYPE, _type) // append lower 27 bytes
        }
        bool result = ViewSPV.prove(_txid, _merkleRoot, _merkleProof.ref(0), _index);
        assertEq(result, true);
    }
}
