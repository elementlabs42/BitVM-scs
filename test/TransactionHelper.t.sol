// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/libraries/TransactionHelper.sol";
import "../src/interfaces/IBridge.sol";

contract TransactionHelperTest is Test {
    function testTransactionHelper_parseVin() public pure {
        // Extract the rawVin part from tx3020
        bytes memory rawVin = (
            hex"01" // input count, compact size
            hex"5c98af97581ab788e7d4bda18f01e7b54d6fce601dc2ecdcbb0a38b0f82249e6" // txid
            hex"00000000" // vout
            hex"00" // scriptSig size
            hex"" // scriptSig
            hex"ffffffff"
        ); // sequence

        Input[] memory inputs = TransactionHelper.parseVin(rawVin);

        assertEq(inputs.length, 1);
        assertEq(inputs[0].prevTxID, 0x5c98af97581ab788e7d4bda18f01e7b54d6fce601dc2ecdcbb0a38b0f82249e6);
        assertEq(inputs[0].prevTxIndex, 0);
        assertEq(inputs[0].sequence, 0xffffffff);
    }

    function testTransactionHelper_parseVout() public pure {
        // Extract the rawVout part from tx3020
        bytes memory rawVout = (
            hex"01" // output count, compact size
            hex"a086010000000000" // output amount
            hex"22" // scriptPubKey size
            hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d"
        ); // scriptPubKey

        Output[] memory outputs = TransactionHelper.parseVout(rawVout);

        assertEq(outputs.length, 1);
        assertEq(outputs[0].value, 100000);
        assertEq(outputs[0].scriptPubKey, hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d");
    }

    function testTransactionHelper_convertParam() public pure {
        ProofParam memory proofParam = ProofParam({
            merkleProof: new bytes32[](2),
            parents: new bytes32[](5),
            children: new bytes32[](5),
            rawTx: hex"020000000001016a2abbd075ce272dda9aa6c6b718ac778eed0cfbef567ff3ec5d794c18fc84ad0000000000ffffffff01888a0100000000002251206eda572bf2622327e74f1c450f51a4893741a5c7c712fa04bad7e805e6c5f45f02473044022035d96f53c3a0755ef6d38949eb401702e78edcedc68d3c056f417426ea94c2bb02207952f27fece7b1a318f9e935314ca301411f208ca6f777de76c0ec32e26a43ae01232102edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac00000000",
            index: 1,
            blockHeight: 1279748,
            blockHeader: hex"000001a8fae47b2bf036659c70c4054b01a2d4aa6836c756794b70b82eca1f0b"
        });

        proofParam.merkleProof[0] = hex"dc5f40b69d529e430c338aeb80d0df79103719e8547850bc617258ed6386d5d2";
        proofParam.merkleProof[1] = hex"bc25149cb3a825c28182bd87022a75864764c0c31e93e36b3c707470104a9684";

        // Populate parents
        proofParam.parents[0] = hex"0000021eb7729da63ad9afc62fa0c5a5e870b3bf04456759dad15e37b8fe3559";
        proofParam.parents[1] = hex"0000025a3f0bc9a7218f032348cd94845d00bbb5002b709ef798f48cc27b60ed";
        proofParam.parents[2] = hex"0000030a323ebdccb2c220870a6dd6b7b084e539d73e2ffc17dff6fd65410e3b";
        proofParam.parents[3] = hex"00000126b789c84a4a0f88802a30184de2f3cf4c811a29983984a4c13434fddb";
        proofParam.parents[4] = hex"000002565b900f476fd43b00b8bde46b89126e8e6d4a4a18abf524f645ac8540";

        // Populate children
        proofParam.children[0] = hex"00000256cd978c543bf8f0270657cf6c436d65c3925de9190bd01e1ffb819c09";
        proofParam.children[1] = hex"000002e4f470797cdd1ef098ccec7201aa4b0b71ec0e569d84680d8336f5690c";
        proofParam.children[2] = hex"0000034f49ef6c97bb3e4742636caf7d0b53df6b53fbff25433a8e7a1a752b8d";
        proofParam.children[3] = hex"00000356ea47b0d018d8cf2909f0d7f0db3139ad796c6728cfa9c9bad6037d08";
        proofParam.children[4] = hex"00000356ea47b0d018d8cf2909f0d7f0db3139ad796c6728cfa9c9bad6037d08";

        ProofInfo memory proofInfo = TransactionHelper.paramToProof(proofParam);

        // Verify the results
        assertEq(proofInfo.version, hex"02000000");
        assertEq(
            proofInfo.rawVin, hex"016a2abbd075ce272dda9aa6c6b718ac778eed0cfbef567ff3ec5d794c18fc84ad0000000000ffffffff"
        );
        assertEq(
            proofInfo.rawVout,
            hex"01888a0100000000002251206eda572bf2622327e74f1c450f51a4893741a5c7c712fa04bad7e805e6c5f45f"
        );
    }

    function bytesToHex(bytes memory buffer) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(2 + buffer.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < buffer.length; i++) {
            str[2 + i * 2] = hexChars[uint8(buffer[i] >> 4)];
            str[3 + i * 2] = hexChars[uint8(buffer[i] & 0x0f)];
        }
        return string(str);
    }
}
