// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
abstract contract OwnableUpgradeable {
    address private _owner;
    function __Ownable_init(address o) internal { _owner = o; }
    function owner() public view returns (address) { return _owner; }
    modifier onlyOwner() { require(msg.sender == _owner, "not owner"); _; }
}