pragma solidity >=0.5.10;
import "./SafeMath.sol";
import {TaprootHelper} from "./TaprootHelper.sol";

library  PeginHelper {
    using SafeMath for uint256;
    using TaprootHelper for bytes32;

    function generatePreSignScript(bytes32 nOfNPubkey) internal pure returns (bytes memory) {
        return abi.encodePacked(nOfNPubkey, " CHECKSIG");
    }

    function generateTimelockLeaf(bytes32 pubkey, uint256 blocks) internal pure returns (bytes memory) {
        return abi.encodePacked(blocks, " OP_CHECKSEQUENCEVERIFY OP_DROP ", pubkey, " OP_CHECKSIG");
    }

    function generateDepositScript(bytes32 nOfNPubkey, address evmAddress) internal pure returns (bytes memory) {
        return abi.encodePacked(generatePreSignScript(nOfNPubkey), " OP_TRUE OP_FALSE OP_IF ", evmAddress, " OP_ENDIF");
    }

    function generatePayScript(bytes32 dstAddress) internal pure returns (bytes memory) {
        return abi.encodePacked("OP_DUP OP_RIPEMD160 ", dstAddress, " CHECKSIG OP_EQUALVERIFY OP_CHECKSIG");
    }

    function generateDepositTaproot(bytes32 nOfNPubkey , address evmAddress, bytes32 userPk, uint256 lockDuration) internal view returns (bytes32) {
        bytes memory depositScript = generateDepositScript(nOfNPubkey, evmAddress);
        bytes memory timelockScript = generateTimelockLeaf(userPk, lockDuration);
        bytes[] memory scripts = new bytes[](2);
        scripts[0] = depositScript;
        scripts[1] = timelockScript;
        return nOfNPubkey.createTaprootAddress(scripts);
    }

    function validatePeginProof(bytes32 nOfNPubkey, address evmAddress, BtcTxProof memory proof1, BtcTxProof memory proof2) internal pure returns (bool) {
        // todo: do all proof verification logic here
        return true;
    }
}
