#!/usr/bin/env bash
# MUT-GATE: the PoC must go RED when the bug is fixed.
# If this script exits 1, the PoC is not measuring what its README claims.
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -a "$SRC/src" "$SRC/test" "$SRC/foundry.toml" "$TMP/"
ln -s "$SRC/lib" "$TMP/lib"

python3 - "$TMP/src/LayerEdgeStaking.sol" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
needle = 'stakerTierHistory[user].push(TierEvent({from: old, to: newTier, timestamp: currentTime}));'
assert s.count(needle) == 1, 'expected exactly one push site, found %d' % s.count(needle)
patch = ('if (stakerTierHistory[user].length < 8) { ' + needle + ' }')
s = s.replace(needle, patch, 1)
open(p, 'w').write(s)
print('mutation applied: tier history capped at 8 entries')
PY

cd "$TMP" || exit 1
echo '--- running the same test against the capped source ---'
if forge test --mt gasBomb > /tmp/must_fail.log 2>&1; then
  echo 'MUTANT SURVIVED: test passed on capped source'
  echo '=> the PoC does not measure what it claims; do not trust the README table.'
  exit 1
else
  echo 'MUTANT KILLED: test failed on capped source (expected)'
  grep -E 'FAIL|Suite result' /tmp/must_fail.log | head -5
  exit 0
fi