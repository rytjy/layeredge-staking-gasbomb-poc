// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
abstract contract ReentrancyGuardUpgradeable {
    uint256 private _st;
    function __ReentrancyGuard_init() internal { _st = 1; }
    modifier nonReentrant() { require(_st != 2, "reentrant"); _st = 2; _; _st = 1; }
}