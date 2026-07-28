# openXC7 Virtex-7 device database (prjxray `database/virtex7`)

Canonical, version-controlled copy of the prjxray **virtex7** device database
(segbits / tilegrid / part data) used by the openXC7 flow for the VC707
(`xc7vx485tffg1761-2`).

Upstream prjxray **gitignores its `database/` tree** (it is fuzzer *output*),
so this data has historically lived only on the fuzzing machine. This repo
exists to make it a first-class, diffable, releasable artifact — the canonical
source of truth and the durable off-machine backup.

## What's here

The full `database/virtex7` tree, committed **raw** (no `.gitignore` hiding the
generated `.db`/`.json`):

* `segbits_*.db`   — feature → bit mappings (the fuzzed encoding)
* `tilegrid.json`, `tileconn.json`, `*.json` — geometry / connectivity
* `part.yaml`, `*.csv` — part metadata

These are text and `diff`/`blame` cleanly — every segbit change is reviewable.

## Derived artifacts (NOT stored here — regenerated, published as release assets)

These are also derivatives of licensed code, but the **build tooling that
produces them is kept in a separate repo** under its own licence (see
*Provenance & licensing* below) — it is not part of this database.

* **nextpnr chipdb** `xc7vx485t.bin` — built **from this DB** by nextpnr-xilinx
  `bbaexport.py --xray <this repo>` + `bbasm` (the xc7 / Project X-Ray path; no
  RapidWright). Its `.bba` binary format is tied to a specific nextpnr-xilinx
  commit, pinned in the tooling's `manifest.json`.
* **json2dcp wire oracle** `xc7vx485tffg1761-2.oracle.txt.gz` — built from
  RapidWright (`BuildWireOracle`); independent of these segbits.

Build recipes (`build-chipdb.sh`, `build-oracle.sh`, `cut-release.sh`) and the
release `manifest.json` live in **`v7-johnson-demo/device-db-tools/`**.

A release tag bundles this DB commit + the chipdb + the oracle + `SHA256SUMS`,
so the three can never drift out of sync (the previous failure mode, where the
chipdb and DB carried different dates from different repos).

## Reconciliation workflow

Fuzzing / hand-patching happens **in place in this directory** (it is the
prjxray build area). Because the DB is now tracked:

```
# after a fuzz/patch session that improves the DB:
git status        # shows exactly which segbits changed (invisible before)
git diff          # review the encoding deltas
git add -A && git commit -m "..."   # capture the local patches
git tag device-db-YYYY-MM-DD        # cut a release
```

Then run `device-db-tools/recipes/cut-release.sh` (in the demo repo) to build
the chipdb + oracle from this commit and stamp the manifest.

Pulling a newer upstream release is a `git merge` against this repo —
conflicts between local patches and the release surface explicitly instead of
one copy silently clobbering the other.

See `FIXES.md` for the substantive segbit corrections this DB carries over a
stock prjxray fuzz.

## Provenance & licensing

This database is **fuzzer output**: the bit↔feature correlations were derived
by Project X-Ray's fuzzers, which drive Vivado to generate and diff bitstreams.
It is distributed under the Project X-Ray licence (ISC) — see `LICENSE` — as a
mirror/extension of the upstream prjxray database, and contains no Xilinx
source or proprietary files.

This repo deliberately contains **only the database** (a derivative-of-licensed-
tools artifact). Original tooling that consumes or rebuilds it
(`device-db-tools/`, the SVS suite, json2dcp, the demo) lives in separate repos
under their own licences, to keep our original code cleanly separated from
derivatives of licensed code.
