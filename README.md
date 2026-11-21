# LayerEdge Staking — unbounded `stakerTierHistory` gas bomb (PoC)

Minimal, self-contained reproducer for finding **M-1** in the
`2025-05-layeredge` Sherlock audit contest:

> `stakerTierHistory` is an unbound array; `calculateUnclaimedInterest`
> iterates it in full on every claim/unstake/stake/compound, so a third party
> can inflate a victim's history with cheap stake/unstake churn until every
> state-changing path for that user reverts and their funds are locked.

## Run it

```bash
forge test -vv --mt gasBomb
```

`forge-std` is vendored under `lib/` (pinned to the upstream submodule commit
`77041d2`), so no `forge install` and no network access is needed.
Toolchain used: `forge 1.5.1`, `solc 0.8.23` (pinned in `foundry.toml`).

## Result (2026-11-19 run, reproduced 2026-11-21)

| cycles | victim history len | victim claim gas | control claim gas | marginal per entry |
|---|---|---|---|---|
| 150 | 302 | 2,146,635 | 88,920 | 6,813 |
| 300 | 602 | 4,197,183 | 88,920 | 6,824 |

Both curves grow linearly at ~6.8k gas per extra history entry, so a **30M
block gas limit is crossed at ~4,396 entries**. Past that point the victim's
`claimInterest` / `unstake` / `stake` all revert.

Attacker cost: each churn event is roughly one stake/unstake boundary tick
(~50k gas) ⇒ ~4,400 events ≈ 220M gas, i.e. ~0.01–0.02 ETH on a cheap chain —
far below a typical victim's staked principal.

## What is copied vs written

- **Verbatim upstream**: `src/LayerEdgeStaking.sol` (930 lines),
  `src/library/FenwickTree.sol` (52 lines), from
  `sherlock-audit/2025-05-layeredge` @ `edgen-staking/src/stake/`.
- **Written for this PoC**: `src/oz/**` minimal OpenZeppelin stubs
  (Initializable / UUPS / Ownable / Pausable / ReentrancyGuard / IERC20) —
  just enough to compile; they do **not** model proxy or upgrade behaviour.
- `test/PoC.t.sol` — the harness.

## Scope / limits

- Proves the **accounting and loop complexity**; it does not prove the OZ base
  classes, proxy wiring, or mainnet gas (local EVM gas is used, same cold-SLOAD
  pricing as mainnet, so the order of magnitude holds).
- Not a mainnet fork; no oracle/queue/hook path.

## License

PoC harness, stubs and this README: MIT.
Upstream contract files carry their own `SPDX-License-Identifier: MIT` headers
and are included solely to reproduce the published contest finding.

## 证明什么 / 不证明什么

两条命令：一条必须绿，一条必须红。

```bash
forge test -vv --mt gasBomb    # 必须 PASS
bash scripts/must_fail.sh      # 必须打印 MUTANT KILLED
```

**证明**

- 第三方对该地址做 stake/unstake churn 时，`stakerTierHistory` 按约 2 条/轮增长，无上界。
- `claimInterest` 的 gas 随历史长度线性增长，边际约 6.8k gas/条；外推到 4,396 条越过 30M，此后该用户的 claim/unstake/stake 全部 revert。
- 反向对照：给 `push` 加 8 条上限后，同一组测试立刻失败（`history did not grow: 8 <= 290`）。说明这个 PoC 测的是「无上界」本身，不是任意 gas 增长。

**不证明**

- 不证明有人真的会发起这次攻击。成本约 220M gas（约 0.01–0.02 ETH）是估算，不是链上实测。
- 不证明 30M 是所有链的上限。那是以太坊主网值，L2 与其它链不同。
- 不证明其它入口（transfer、withdraw 等）同样受影响，本次只测 claim/unstake/stake。
- 不证明严重级别。Medium / High 是评审的判断，PoC 只提供可复现事实。
