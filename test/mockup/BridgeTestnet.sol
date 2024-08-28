// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IBridge} from "../../src/interfaces/IBridge.sol";
import {Bridge} from "../../src/Bridge.sol";
import {EBTC} from "../../src/EBTC.sol";
import {IStorage} from "../../src/interfaces/IStorage.sol";

/**
 * @dev ignore retargeting for test net
 */
contract BridgeTestnet is Bridge {
    constructor(EBTC _ebtc, IStorage _blockStorage, bytes memory _nOfNPubKey, uint32 _timelock)
        Bridge(_ebtc, _blockStorage, _nOfNPubKey)
    {
        difficultyThreshold = 2270;
        pegInTimelock = _timelock;
    }
}
