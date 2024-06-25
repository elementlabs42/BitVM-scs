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
}
