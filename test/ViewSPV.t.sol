// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBridge.sol";
import "../src/libraries/ViewSPV.sol";
import "../src/libraries/Endian.sol";
import "./fixture/ConstantsFixture.sol";
import "./utils/Util.sol";

contract ViewSPVTest is Test, ConstantsFixture {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // function testViewSPV_prove_emptyParameters() public {
    //     bytes32 txid;
    //     bytes32 merkleRoot;
    //     bytes29 merkleProof;
    //     uint256 index;
    //     vm.expectRevert(abi.encodeWithSelector(ViewSPV.EmptyMemView.selector));
    //     ViewSPV.prove(txid, merkleRoot, merkleProof, index);
    // }

    function testViewSPV_prove_emptyBlock() public view {
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
        bytes memory reversedProof = Endian.reverse256Array(proof800);
        bytes29 merkleProof = reversedProof.ref(uint40(ViewBTC.BTCTypes.MerkleArray));
        bytes32 txId = bytes32(Endian.reverse256(uint256(txId800)));
        bytes32 merkleRoot = bytes32(Endian.reverse256(uint256(root800)));

        bool result = ViewSPV.prove(txId, merkleRoot, merkleProof, index800);
        assertEq(result, true);
    }
}
