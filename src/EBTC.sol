// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract EBTC is ERC20 {
    error AdminOnly();
    error BridgeOnly();

    event TokenMinted(address to, uint256 amount);
    event TokenBurnt(address from, uint256 amount);

    address admin;
    address bridge;

    constructor(address _bridge) ERC20("eBTC", "ebtc") {
        admin = msg.sender;
        bridge = _bridge;
    }

    function setBridge(address _bridge) external {
        if (msg.sender != admin) {
            revert AdminOnly();
        }

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

    function burn(address from, uint256 amount) external {
        if (msg.sender != bridge) {
            revert BridgeOnly();
        }

        _burn(from, amount);

        emit TokenBurnt(from, amount);
    }
}
