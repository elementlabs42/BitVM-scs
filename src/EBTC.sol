// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract EBTC is ERC20 {
    error BridgeOnly();

    event TokenMinted(address to, uint amount);

    address bridge;

    constructor(address _bridge) ERC20("eBTC", "ebtc") {
        bridge = _bridge;
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != bridge) {
            revert BridgeOnly();
        }

        _mint(to, amount);

        emit TokenMinted(to, amount);
    }
}
