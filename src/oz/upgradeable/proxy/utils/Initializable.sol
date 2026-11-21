// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
abstract contract Initializable {
    bool private _init;
    modifier initializer() { require(!_init, "already init"); _init = true; _; }
    function _disableInitializers() internal {}
}