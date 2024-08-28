// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Bridge} from "../../src/Bridge.sol";
import {EBTC} from "../../src/EBTC.sol";
import {IStorage} from "../../src/interfaces/IStorage.sol";

/**
 * @dev ignore retargeting for test net
 */
contract BridgeTestnet is Bridge {
    constructor(EBTC _ebtc, IStorage _blockStorage, bytes32 _nOfNPubKey, uint32 _pegInTimelock)
        Bridge(_ebtc, _blockStorage, _nOfNPubKey, _pegInTimelock)
    {
        difficultyThreshold = 2270;
    }
}
