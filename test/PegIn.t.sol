// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBridge.sol";
import "../src/libraries/Coder.sol";
import "./fixture/ConstantsFixture.sol";
import "../src/Storage.sol";
import "./Util.sol";

contract PegInTest is Test, ConstantsFixture {
    function testPegIn_constructor_zeroDistance() public {
        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockStepDistanceInvalid.selector, 0));
        new Storage(0, 0, hex"", 0, 0);
    }
}
