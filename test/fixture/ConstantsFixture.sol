// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract ConstantsFixture {
    // correct header for bitcoin block #717695
    // all bitcoin header values are little-endian:
    bytes constant bVer = hex"04002020";
    bytes constant bParent = hex"edae5e1bd8a0e007e529fe33d099ebb7a82a06d6d63d0b000000000000000000";
    bytes constant bTxRoot = hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca";
    bytes constant bTime = hex"0b40d961";
    bytes constant bBits = hex"ab980b17";
    bytes constant bNonce = hex"3dcc4d5a";
    bytes constant headerGood = (
        hex"04002020" hex"edae5e1bd8a0e007e529fe33d099ebb7a82a06d6d63d0b000000000000000000"
        hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca" hex"0b40d961" hex"ab980b17" hex"3dcc4d5a"
    );
    bytes32 constant blockHash717695 = 0x00000000000000000000135a8473d7d3a3b091c928246c65ce2a396dd2a5ca9a;

    // correct header for bitcoin block #717696
    // in order, all little-endian:
    // - version
    // - parent hash
    // - tx merkle root
    // - timestamp
    // - difficulty bits
    // - nonce
    bytes constant header717696 = (
        hex"00004020" hex"9acaa5d26d392ace656c2428c991b0a3d3d773845a1300000000000000000000"
        hex"aa8e225b1f3ea6c4b7afd5aa1cecf691a8beaa7fa1e579ce240e4a62b5ac8ecc" hex"2141d961" hex"8b8c0b17" hex"0d5c05bb"
    );

    bytes constant header717697 = (
        hex"0400c020" hex"bf559a5b0479c2a73627af40cef1835d44de7b32dd3503000000000000000000"
        hex"fe7be65b41f6cf522eac2a63f9dde1f7a6f61eee93c648c74b79cfc242dd1a94" hex"f241d9618b8c0b17ac09604c"
    );

    // header for bitcoin block #736000
    bytes constant header736000 = (
        hex"04000020" hex"d8280f9ce6eeebd2e117f39e1af27cb17b23c5eae6e703000000000000000000"
        hex"31b669b35884e22c31b286ed8949007609db6cb50afe8b6e6e649e62cc24e19c" hex"a5657c62" hex"ba010917" hex"36d09865"
    );

    bytes32 constant blockHash736000 = hex"00000000000000000002d52d9816a419b45f1f0efe9a9df4f7b64161e508323d";

    // a Bitcoin P2SH (pay to script hash) transaction.
    // https://blockstream.info/api/tx/3667d5beede7d89e41b0ec456f99c93d6cc5e5caff4c4a5f993caea477b4b9b9/hex
    // in order, all little-endian:
    // - version
    // - flags
    // - tx inputs
    // - tx outputs
    // - witnesses
    // - locktime
    // bytes constant tx736000_2 = (
    //     hex"02000000"
    //     hex"0001"
    //     hex"01"
    //     hex"bb185dfa5b5c7682f4b2537fe2dcd00ce4f28de42eb4213c68fe57aaa264268b"
    //     hex"01000000"
    //     hex"17"
    //     hex"16001407bf360a5fc365d23da4889952bcb59121088ee1"
    //     hex"feffffff"
    //     hex"02"
    //     hex"8085800100000000"
    //     hex"17"
    //     hex"a914ae2f3d4b06579b62574d6178c10c882b9150374087"
    //     hex"1c20590500000000"
    //     hex"17"
    //     hex"a91415ecf89e95eb07fbc351b3f7f4c54406f7ee5c1087"
    //     hex"0247"
    //     hex"3044022025ace11487fbd2fb222ef00b14f0be6dc38cf0d028d8fc67476f4e2bb844d301022061d5a922d87186688d86d36507b1633a94d180a4f7f2b36f0f5c004e440ae57801"
    //     hex"21"
    //     hex"028401531bb6226b1068f4482ae50f94cc78f64a1dd5cf7e1e41c8eceb1dcc0be3"
    //     hex"00000000"
    // );

    // the same transaction, excluding flags and witnesses
    // the txid is a hash of this serialization
    bytes constant tx736 = (
        hex"02000000" hex"01" hex"bb185dfa5b5c7682f4b2537fe2dcd00ce4f28de42eb4213c68fe57aaa264268b" hex"01000000"
        hex"17" hex"16001407bf360a5fc365d23da4889952bcb59121088ee1" hex"feffffff" hex"02" hex"8085800100000000" hex"17"
        hex"a914ae2f3d4b06579b62574d6178c10c882b9150374087" hex"1c20590500000000" hex"17"
        hex"a91415ecf89e95eb07fbc351b3f7f4c54406f7ee5c1087" hex"00000000"
    );

    // merkle proof that transaction above is in block 736000
    bytes constant txProof736 = (
        hex"d298f062a08ccb73abb327f01d2e2c6109a363ac0973abc497eec663e08a6a13"
        hex"2e64222ee84f7b90b3c37ed29e4576c41868c7dcf73b1183c1c84a73c3bb0451"
        hex"ea4cc81f31578f895bd3c14fcfdd9273173e754bddca44252f261e28ba814b8a"
        hex"d3199dac99561c60e9ea390d15633534de8864c7eb37512c6a6efa1e248e91e5"
        hex"fb0f53df4e177151d7b0a41d7a49d42f4dcf5984f6198b223112d20cf6ae41ed"
        hex"b0914821bd72a12b518dc94e140d651b7a93e5bb7671b3c8821480b0838740ab"
        hex"19d90729a753c500c9dc22cc7fec9a36f9f42597edbf15ccd1d68847cf76da67"
        hex"bc09b6091ec5863f23a2f4739e4c6ba28bb7ba9bcf2266527647194e0fccd94a"
        hex"e6925c8491e0ff7e5a7db9d35c5c15f1cccc49b082fc31b1cc0a364ca1ecc358"
        hex"d7ff70aa2af09f007a0aba4e1df6e850906d22a4c3cc23cd3b87ba0cb3a57e33"
        hex"fb1f9877e50b5cbb8b88b2db234687ea108ac91a232b2472f96f08f136a5eba4"
        hex"0b2be0cdd7773b1ddd2b847c14887d9005daf04da6188f9beeccab698dcc26b9"
    );

    // correct header for bitcoin block #717695
    // all bitcoin header values are little-endian:
    bytes constant b717695 = (
        hex"04002020" hex"edae5e1bd8a0e007e529fe33d099ebb7a82a06d6d63d0b000000000000000000"
        hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca" hex"0b40d961" hex"ab980b17" hex"3dcc4d5a"
    );

    // block 1213020 in mutinynet.com, peg_in_confirm tx
    // forgefmt: disable-start
    bytes constant tx3020 = (
      hex"02000000"         // version, 4 bytes
      hex"0001"             // marker & flag, 1 byte each
      hex"01"               // input count, compact size (fc: 1, fd: 2, fe: 4, ff: 8)
      // reverse(rpc) byte order: "e64922f8b0380abbdcecc21d60ce6f4db5e7018fa1bdd4e788b71a5897af985c"
      hex"5c98af97581ab788e7d4bda18f01e7b54d6fce601dc2ecdcbb0a38b0f82249e6"     // txid, 32 bytes
      hex"00000000"         // vout, 4 bytes
      hex"00"               // scriptSig size, compact size, use 00 to put unlocking code in witness field for p2wpkh or p2wsh locking script
      hex""                 // scriptSig, variable length, empty here due to 00 in scriptSig size
      hex"ffffffff"         // sequence, 4 bytes
      // continues for more inputs if any
      hex"01"               // output count, compact size
      hex"a086010000000000" // output amount, 8 bytes
      hex"22"               // scriptPubKey size, compact size, 34(0x22) bytes
      hex"0020be87e5c1a6f9957f1adc7d4296635b6b3f0da03a3a7819f919a827feff19501d" // scriptPubKey
      // continues for more outputs if any
      hex"04"               // witness stack item count, compact size
      hex"41"               // item 0 size, compact size, 65(0x41)
      hex"5fdb8c34a666fb7ba2fe6ca94572cdec9c2b16afa5b54f9a40a9d0335b55a103efbe8bd66422a950b2c81e062e7bc5afc3780b50caf428d4681ee77e07a5419001" // item 0
      hex"41"               // item 1 size, compact size, 65(0x41)
      hex"08f1d98c099d586945b6c7376ba552767ab723a46d9bc4b74668dec290aa35710b329dd9fa47706841ad3de3da0697d4b19816c49dc26bc50e0aa65ce10cf26f01" // item 1
      hex"72"               // item 2 size, compact size, 114(0x72)
      hex"0063036f72645118746578742f706c61696e3b636861727365743d7574662d38000b65766d20616464726573736820d0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4ad20edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac" // item 2
      hex"41"               // item 3 size, compact size, 65(0x41)
      hex"c1edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b1f73b1ad437defef81d6cec08008a0d4c243230ebc4d349c5f35149f7674cd0f" // item 3
      hex"00000000"         // lock time, 4 bytes
    );
    // forgefmt: disable-end
}
