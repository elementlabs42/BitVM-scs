// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Outpoint} from "../src/interfaces/IBtcBridge.sol";
import "../src/BtcMirror.sol";
import "../src/mocks/MockBtcTxVerifier.sol";
import "../src/mocks/IMockBtcTxVerifier.sol";
import "./fixture/ConstantsFixture.sol";

contract BtcTxVerifierTest is Test, ConstantsFixture {
    BtcMirror immutable mirror;
    IMockBtcTxVerifier immutable btcTxVerifier;

    constructor() {
        mirror = new BtcMirror(
            736000, // start at block #736000
            0x00000000000000000002d52d9816a419b45f1f0efe9a9df4f7b64161e508323d,
            0,
            0x0,
            false
        );

        assertEq(mirror.getLatestBlockHeight(), 736000);

        btcTxVerifier = new MockBtcTxVerifier(mirror);
    }

    function testVerifyTx() public {
        bytes32 txId736 = 0x3667d5beede7d89e41b0ec456f99c93d6cc5e5caff4c4a5f993caea477b4b9b9;

        bytes20 destSH = hex"ae2f3d4b06579b62574d6178c10c882b91503740";

        BtcTxProof memory txP = BtcTxProof(header736000, Outpoint(txId736, 1), txProof736, tx736);

        assertTrue(btcTxVerifier.verifyPayment(1, 736000, txP, 0, destSH, 25200000));

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotEnoughBlockConfirmations()"))));
        assertTrue(!btcTxVerifier.verifyPayment(2, 736000, txP, 0, destSH, 25200000));

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AmountMismatch()"))));
        assertTrue(!btcTxVerifier.verifyPayment(1, 736000, txP, 0, destSH, 25200001));

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ScriptHashMismatch()"))));
        assertTrue(!btcTxVerifier.verifyPayment(1, 736000, txP, 1, destSH, 25200000));

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("BlockHashMismatch()"))));
        assertTrue(!btcTxVerifier.verifyPayment(1, 700000, txP, 0, destSH, 25200000));
    }

    // Counting down from the chain of Bitcoin block hashes, to a specific txo.
    // 5. verify that we can hash a block header correctly
    function testGetBlockHash() public {
        // Block 717695
        assertEq(btcTxVerifier.getBlockHash(headerGood), blockHash717695);

        // Block 736000
        assertEq(btcTxVerifier.getBlockHash(header736000), blockHash736000);
    }

    // 4. verify that we can get the transaction merkle root from a block header
    function testGetBlockTxMerkleRoot() public {
        bytes32 expectedRoot = 0xf8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca;
        assertEq(btcTxVerifier.getBlockTxMerkleRoot(headerGood), expectedRoot);

        assertEq(
            btcTxVerifier.getBlockTxMerkleRoot(header736000),
            0x31b669b35884e22c31b286ed8949007609db6cb50afe8b6e6e649e62cc24e19c
        );
    }

    // 3. verify that we can recreate the same merkle root from a merkle proof
    function testGetTxMerkleRoot() public {
        // block 100000 has just 4 txs, short proof
        assertEq(
            btcTxVerifier.getTxMerkleRoot(
                0xfff2525b8931402dd09222c50775608f75787bd2b87e56995a7bdd30f79702c4,
                1,
                hex"8c14f0db3df150123e6f3dbbf30f8b955a8249b62ac1d1ff16284aefa3d06d87"
                hex"8e30899078ca1813be036a073bbf80b86cdddde1c96e9e9c99e9e3782df4ae49"
            ),
            0x6657a9252aacd5c0b2940996ecff952228c3067cc38d4885efb5a4ac4247e9f3
        );

        // block 736000, long proof
        bytes32 txId = 0x3667d5beede7d89e41b0ec456f99c93d6cc5e5caff4c4a5f993caea477b4b9b9;
        uint256 txIndex = 1;
        bytes32 expectedRoot = 0x31b669b35884e22c31b286ed8949007609db6cb50afe8b6e6e649e62cc24e19c;
        assertEq(btcTxVerifier.getTxMerkleRoot(txId, txIndex, txProof736), expectedRoot);
    }

    // 2. verify that we can get hash a raw tx to get the txid (merkle leaf)
    function testGetTxID() public {
        bytes32 expectedID = 0x3667d5beede7d89e41b0ec456f99c93d6cc5e5caff4c4a5f993caea477b4b9b9;
        assertEq(btcTxVerifier.getTxID(tx736), expectedID);
    }

    // 1a. to parse a raw transaction, we must understand Bitcoin's
    //     wire format. verify that we can deserialize varints.
    bytes constant buf63_offset = hex"00003f";
    bytes constant buf255 = hex"fdff00";
    bytes constant buf2to16 = hex"fe00000100";
    bytes constant buf2to32 = hex"ff0000000001000000";

    function testReadVarInt() public {
        uint256 val;
        uint256 newOffset;
        (val, newOffset) = btcTxVerifier.readVarInt(buf63_offset, 0);
        assertEq(val, 0);
        assertEq(newOffset, 1);

        (val, newOffset) = btcTxVerifier.readVarInt(buf63_offset, 2);
        assertEq(val, 63);
        assertEq(newOffset, 3);

        (val, newOffset) = btcTxVerifier.readVarInt(buf255, 0);
        assertEq(val, 255);
        assertEq(newOffset, 3);

        (val, newOffset) = btcTxVerifier.readVarInt(buf2to16, 0);
        assertEq(val, 2 ** 16);
        assertEq(newOffset, 5);

        (val, newOffset) = btcTxVerifier.readVarInt(buf2to32, 0);
        assertEq(val, 2 ** 32);
        assertEq(newOffset, 9);
    }

    // 1b. verify that we can parse a raw Bitcoin transaction
    function testParseTx() public {
        BitcoinTx memory t = btcTxVerifier.parseBitcoinTx(tx736);
        assertTrue(t.validFormat);

        assertEq(t.version, 2); // BIP68

        assertEq(t.inputs.length, 1);
        assertEq(t.inputs[0].prevTxID, 0x8b2664a2aa57fe683c21b42ee48df2e40cd0dce27f53b2f482765c5bfa5d18bb);
        assertEq(t.inputs[0].prevTxIndex, 1);
        assertEq(t.inputs[0].scriptLen, 23);
        assertEq(t.inputs[0].script, bytes(hex"16001407bf360a5fc365d23da4889952bcb59121088ee1"));
        assertEq(t.inputs[0].seqNo, 4294967294);

        assertEq(t.outputs.length, 2);
        assertEq(t.outputs[0].valueSats, 25200000);
        assertEq(t.outputs[0].scriptLen, 23);
        assertEq(t.outputs[0].script, bytes(hex"a914ae2f3d4b06579b62574d6178c10c882b9150374087"));

        assertEq(t.locktime, 0);
    }

    // 1b-2. verify that we can parse a raw Bitcoin transaction contains witness field
    function testParseSegwitTx() public {
        BitcoinTx memory t = btcTxVerifier.parseSegwitTx(tx3020);
        assertTrue(t.validFormat);

        assertEq(t.version, 2); // BIP68
        assertEq(t.marker, 0);
        assertTrue(t.flag >= 1);

        assertEq(t.inputs.length, 1);
        assertEq(t.inputs[0].prevTxID, 0xe64922f8b0380abbdcecc21d60ce6f4db5e7018fa1bdd4e788b71a5897af985c); // reversed byte order, found in explorer
        assertEq(t.inputs[0].prevTxIndex, 0);
        assertEq(t.inputs[0].scriptLen, 0);
        assertEq(t.inputs[0].script, bytes(hex""));
        assertEq(t.inputs[0].seqNo, 0xffffffff);

        assertEq(t.outputs.length, 1);
        assertEq(t.outputs[0].valueSats, 100000);
        assertEq(t.outputs[0].scriptLen, 34);
        assertEq(t.outputs[0].script, bytes(hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d"));

        assertEq(t.witnesses.length, 4);
        assertEq(t.witnesses[0].itemSize, 65);
        assertEq(
            t.witnesses[0].item,
            bytes(
                hex"5fdb8c34a666fb7ba2fe6ca94572cdec9c2b16afa5b54f9a40a9d0335b55a103efbe8bd66422a950b2c81e062e7bc5afc3780b50caf428d4681ee77e07a5419001"
            )
        );
        assertEq(t.witnesses[1].itemSize, 65);
        assertEq(
            t.witnesses[1].item,
            bytes(
                hex"08f1d98c099d586945b6c7376ba552767ab723a46d9bc4b74668dec290aa35710b329dd9fa47706841ad3de3da0697d4b19816c49dc26bc50e0aa65ce10cf26f01"
            )
        );
        assertEq(t.witnesses[2].itemSize, 114);
        assertEq(
            t.witnesses[2].item,
            bytes(
                hex"0063036f72645118746578742f706c61696e3b636861727365743d7574662d38000b65766d20616464726573736820d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4ad20edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac"
            )
        );
        assertEq(t.witnesses[3].itemSize, 65);
        assertEq(
            t.witnesses[3].item,
            bytes(
                hex"c1edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b1f73b1ad437defef81d6cec08008a0d4c243230ebc4d349c5f35149f7674cd0f"
            )
        );

        assertEq(t.locktime, 0);
    }

    // 1c. finally, verify the recipient of a transaction *output*
    bytes constant b0 = hex"0000000000000000000000000000000000000000";

    function testGetP2SH() public view {
        bytes32 validP2SH = hex"a914ae2f3d4b06579b62574d6178c10c882b9150374087";
        bytes32 invalidP2SH1 = hex"a914ae2f3d4b06579b62574d6178c10c882b9150374086";
        bytes32 invalidP2SH2 = hex"a900ae2f3d4b06579b62574d6178c10c882b9150374087";

        assertEq(uint160(btcTxVerifier.getP2SH(23, validP2SH)), 0x00ae2f3d4b06579b62574d6178c10c882b91503740);

        assertEq(uint160(btcTxVerifier.getP2SH(22, validP2SH)), 0);
        assertEq(uint160(btcTxVerifier.getP2SH(24, validP2SH)), 0);
        assertEq(uint160(btcTxVerifier.getP2SH(23, invalidP2SH1)), 0);
        assertEq(uint160(btcTxVerifier.getP2SH(23, invalidP2SH2)), 0);
    }

    // 1,2,3,4,5. putting it all together, verify a payment.
    function testValidatePayment() public {
        bytes32 txId736 = 0x3667d5beede7d89e41b0ec456f99c93d6cc5e5caff4c4a5f993caea477b4b9b9;
        bytes20 destScriptHash = hex"ae2f3d4b06579b62574d6178c10c882b91503740";

        // Should succeed
        btcTxVerifier.mockValidatePayment(
            blockHash736000,
            BtcTxProof(header736000, Outpoint(txId736, 1), txProof736, tx736),
            0,
            destScriptHash,
            25200000
        );

        // Make each argument invalid, one at a time.
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("BlockHashMismatch()"))));
        btcTxVerifier.mockValidatePayment(
            blockHash717695,
            BtcTxProof(header736000, Outpoint(txId736, 1), txProof736, tx736),
            0,
            destScriptHash,
            25200000
        );

        // - Bad tx proof (doesn't match root)
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("TxMerkleRootMismatch()"))));
        btcTxVerifier.mockValidatePayment(
            blockHash717695,
            BtcTxProof(headerGood, Outpoint(txId736, 1), txProof736, tx736),
            0,
            destScriptHash,
            25200000
        );

        // - Wrong tx index
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("TxMerkleRootMismatch()"))));
        btcTxVerifier.mockValidatePayment(
            blockHash736000,
            BtcTxProof(header736000, Outpoint(txId736, 2), txProof736, tx736),
            0,
            destScriptHash,
            25200000
        );

        // - Wrong tx output index
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ScriptHashMismatch()"))));
        btcTxVerifier.mockValidatePayment(
            blockHash736000,
            BtcTxProof(header736000, Outpoint(txId736, 1), txProof736, tx736),
            1,
            destScriptHash,
            25200000
        );

        // - Wrong dest script hash
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ScriptHashMismatch()"))));
        btcTxVerifier.mockValidatePayment(
            blockHash736000,
            BtcTxProof(header736000, Outpoint(txId736, 1), txProof736, tx736),
            0,
            bytes20(hex"abcd"),
            25200000
        );

        // - Wrong amount, off by one satoshi
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AmountMismatch()"))));
        btcTxVerifier.mockValidatePayment(
            blockHash736000,
            BtcTxProof(header736000, Outpoint(txId736, 1), txProof736, tx736),
            0,
            destScriptHash,
            25200001
        );
    }
}
