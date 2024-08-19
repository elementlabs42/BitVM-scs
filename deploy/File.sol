// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Base.sol";
import "forge-std/stdJson.sol";

abstract contract FileBase is CommonBase {
    error InvalidContent();

    string public path;
    bool public valid;
    string content;

    modifier validated() {
        if (!valid) {
            revert InvalidContent();
        }
        _;
    }

    function reload(string memory _path) public {
        path = _path;
        try vm.readFile(_path) returns (string memory _content) {
            content = _content;
            valid = true;
        } catch {
            valid = false;
        }
    }
}
