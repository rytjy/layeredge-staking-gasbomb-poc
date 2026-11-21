// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
abstract contract PausableUpgradeable {
    bool private _paused;
    function __Pausable_init() internal {}
    modifier whenNotPaused() { require(!_paused, "paused"); _; }
    function _pause() internal { _paused = true; }
    function _unpause() internal { _paused = false; }
}