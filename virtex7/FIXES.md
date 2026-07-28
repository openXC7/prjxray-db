# Segbit fixes carried in this database

Substantive corrections this virtex7 DB carries over a stock prjxray fuzz.
These are what make the fully-open VC707 flow produce correct bitstreams.
(Commit hashes refer to the prjxray fuzzer-code repo that produced them.)

## CLB OUTMUX.O5 duplicate → incomplete encoding  (`6fd1d26`)
The "telegraph bug." Duplicate `OUTMUX.O5` segbit definitions; last-wins
picked the incomplete one (missing the shared xMUX-enable bit) → output muxes
encoded as `0x55`. Fix: dedupe keeping the **complete** definition. This was
the root cause of long-chased open-flow output corruption.

## IOB18 OLOGIC SING-row segbits  (`afb49cc`, fuzzer `036-iob18-ologic-sing`)
SING-row IOB18 sites had no OLOGIC segbits. Added via a dedicated sub-fuzzer.

## LIOI / RIOI OLOGIC inversion segbits  (local fuzz, superset)
`segbits_lioi*.db` / `segbits_rioi_sing.db` gained the `OLOGIC_Y*.IS_*_INVERTED`
features (`IS_CLKDIV_INVERTED`, `IS_D1..D4_INVERTED`, etc.) — +88 lines per
file over the last release (216 vs 128). Plus `mask_lioi*.db` and
`tileconn.json`. This is why the build-area copy is a strict superset of the
released DB.

## LIOB18 / RIOB18 IOB_Y1 IN_ONLY  (`09588f3`)
Dropped spurious bits `!38_32 !38_34` from the Y1 (slave-site) input-only
encoding, fixing left-HP single-ended LVCMOS inputs.

## Tilegrid SING propagation for HP-only LIOB18 / LIOI columns  (`1c63972`, `1574e9c`)
Propagated SING-row bits and added the `iob18_sing` sub-fuzzer so HP-only
columns get correct SING-row geometry.

## Top-SING tile alias start_offset (OLOGIC/IOB "invalid word address")
`tilegrid.json`: the **top** SING-row tiles (`LIOI_SING`/`RIOI_SING`/`LIOB18_SING`/
`RIOB18_SING` at `bits.CLB_IO_CLK.offset == 99`) had alias `start_offset: 0`,
but it must be **2** (matching the bottom SING tiles at `offset 0`). With
`start_offset 0` the aliased regular OLOGIC_Y0 / IOB features (regular words
2–3) mapped to absolute frame words 101–102, which don't exist — fasm2frames
emitted `invalid word address` and silently dropped them (e.g. VC707 counter
LED on `LIOI_SING_X82Y51.OLOGIC_Y0.OMUX.D1`). With `start_offset 2` the
effective offset becomes `99-2=97`, so regular word 3 → abs 100, word 2 → abs
99 — landing in the tile's real 2-word window.

Confirmed empirically: fuzzer `036-iob18-ologic-sing` (re-run at N=50) places
`OLOGIC_Y0.OMUX.D1` at abs word 100, exactly what `start_offset 2` produces.
28 tiles fixed (7 each of LIOI/RIOI/LIOB18/RIOB18_SING). (The dedicated
`segbits_*_sing.db` are NOT consulted for aliased tiles, so this is a tilegrid
fix, not a segbits one.) Follow-up: fix the generator (`fuzzers/005-tilegrid`)
so a regenerated tilegrid doesn't reintroduce `start_offset 0`.

## Known remaining gap (worked around downstream, not yet fixed in DB)
LVCMOS18 single-ended **input** on certain HP-bank sites (e.g. AU33) is missing
segbit `bit_0042101c_063_18` and sets a spurious `IBUF_HP_BANK_GLUE` — the
rx-distortion bug. Currently patched at the frame level in the demo
(`uartram/patch_rx_iob.py`); a proper fix belongs here as a segbit correction.

## 2026-06-10: SING-tile OLOGIC route-thru features are bit-free (ppips)

`ppips_{l,r}ioi_sing.db`: added `*IOI_SING.OLOGIC_Y{0,1}.{OQUSED, OMUX.D1,
OSERDES.DATA_RATE_TQ.BUF} always`.  The SING tilegrid entries alias into the
regular LIOI/RIOI segbits with start_offset 2, so these route-thru features
resolved to WRONG physical bits and poisoned the pad output path (HW symptom:
led[4]/AR35 = IO_0_VRN_13 on LIOI_SING_X82Y51 stuck high in every open-flow
VC707 build, confirmed in both picosoc and johnson).  Raw-frame diff against
a HW-working Vivado golden shows Vivado sets NO OLOGIC config bits in the
SING window — the D1->OQ pass-through is bit-free there — while on regular
LIOI tiles it sets the same OQUSED/OMUX.D1 bits we do.  Declaring the
features as pseudo-pips makes fasm2frames emit no bits for them
(TileSegbitsAlias.feature_to_bits short-circuits on the tile's own ppips).
RIOI_SING entries added by symmetry (same alias structure), not HW-verified.
Suspected same misalias issue for SING ILOGIC input features (not yet seen).

## 2026-06-11: targeted solve of 3 HCLK_CMT_L CK_IN <- MUX_CLK segbits

Added to `segbits_hclk_cmt_l.db` (3 bits each):
  CK_IN1  <- MUX_CLK_8: 28_183 29_152 29_155
  CK_IN0  <- MUX_CLK_7: 26_152 26_154 29_182
  CK_IN10 <- MUX_CLK_5: 29_181 29_203 29_206
Method: one Vivado specimen per pip (pipsolve/ in v7-johnson-demo) with
FIXED_ROUTE forced through the pip; residual = raw window bits minus the
bit2fasm->fasm2frames re-encoding.  KEY: these "MUX_CLK_<n>" wires are the
GT MGT clock spine (node of HCLK_CMT_L_X305Y26/MUX_CLK_8 is
GTX_COMMON_X394Y23/GTXE2_COMMON_MGT_CLK4; MUX_CLK_7=MGT_CLK3<-TXOUTCLK_1,
MUX_CLK_5=MGT_CLK1<-RXOUTCLK_1) - which is why the 045 fuzzer (no GT in
specimens) could never solve them.  Each entry's 3rd bit (~_181..183) looks
like a per-lane spine-tap enable shared with other consumers of the same
MUX_CLK lane; included in the pip entry since lanes are single-consumer in
practice.  Remaining family members (other CK_IN x MUX_CLK combos) still
unsolved - a proper fuzz needs GT-driven specimens.

## 2026-06-11: BRAM_L_X114Y0 tilegrid entry was empty

`xc7vx485t/tilegrid.json`: BRAM_L_X114Y0 had `bits: {}` (tilegrid fuzzer
gap at the column bottom), silently dropping every feature for any BRAM
placed there.  Filled from the column pattern (same baseaddrs as
BRAM_L_X114Y5/Y10, offset 0): BLOCK_RAM 0x00C20500/128f/10w,
CLB_IO_CLK 0x00423900/28f/10w.  Found by the dcp2fasm bit-equivalence
campaign (ethsoc Vivado DCP -> fasm -> frames vs golden bit).

## 2026-06-11: SING IOB tiles - prefer own segbits db over broken alias

`prjxray/grid.py get_tile_segbits_at_tilename()`: tiles whose tilegrid
bits carry an `alias` (LIOB18_SING etc.) were ALWAYS resolved through
TileSegbitsAlias, but the virtex7 SING alias metadata is wrong (sites
map names IOB33_* on an IOB18 part; start_offset arithmetic places the
LIOB18-db Y1 bits 2 words below the SING window) -- features for e.g.
led[4]'s LIOB18_SING_X81Y51 silently CORRUPTED the neighbouring
LIOB18_X81Y49 frames (6 stray bits, found by the bit-equivalence
ledger).  Fix: when the tile type has its own segbits db
(segbits_liob18_sing.db exists), use it directly; alias only as
fallback.  Applied to deps/prjxray and $HOME/prjxray.

## 2026-06-17: kintex7 transplant removal — IOI ILOGIC + ISERDES re-fuzzed

The LIOI/RIOI segbits carried features whose origin_info recorded fuzzers
that CANNOT run on this HP-only part (IOB33/HR-targeted), i.e. kintex7
transplants.  Audited via the per-bit `origin:` provenance; retired so far:

- `035-iob-ilogic` (114 bits): replaced by new fuzzer fuzzers/035-iob18-ilogic
  (IOB18 sites, L+R, tag-grouped enums).  Real ILOGIC/IFF config measured on
  both sides.  IMPORTANT: `ILOGIC_Y{0,1}.ZINV_D` has NO virtex7 frame bit
  (exhaustive frame search = zero correlation; kintex7/artix7 don't carry it
  as a bit either) — the transplant was wrong, not just incomplete.  Now
  declared bit-free via `<tile>.ILOGIC_Y{0,1}.ZINV_D always` in the IOI ppips.
- `035b-iob-iserdes` (156 bits): replaced by fuzzers/035b-iob18-iserdes
  (IOB18 ISERDESE2, L+R).  Real ISERDES taxonomy
  (MEMORY/NETWORKING/OVERSAMPLE x rate x width, MODE, DYN_*, IN_USE).

Method: utils/strip_transplant.py drops bits by origin from both the .db and
.origin_info.db, then the new fuzzer's `make pushdb` merges real L+R data
(segmaker's IOI. prefix -> mergedb rewrites per side).  Validated by rebuilding
the open-flow picosoc: ILOGIC/ISERDES warnings gone, bit configures on VC707.

Still transplanted (to do): `f4pga` (768 bits, lioi left-side IOI pips — needs
037-iob18-pips driven to cover the left column) and `hand-copied-from-LIOB18`
(5 bits, LIOB18_SING IOB_Y1 DRIVE/SLEW/PULLTYPE/STEPDOWN + OBUF_HP_BANK_GLUE).

## 2026-06-18: SING IOB18 — hand-copied transplant replaced by validated mirror

LIOB18_SING / RIOB18_SING IOB18 carried 5 hand-copied (origin
hand-copied-from-LIOB18), partly mis-addressed entries.  Built
fuzzers/030-iob18-sing (OBUF/IBUF/unused mix on the ~28 SING IOB18 sites) and
confirmed by real measurement that the SING IOB18 DRIVE/SLEW/PULLTYPE/IN bits
are BIT-IDENTICAL to the regular LIOB18 (e.g. Y1 DRIVE 38_32/38_34/39_23/39_55).

Finding: nextpnr emits the regular LIOB18 feature *names* for SING tiles, and
the ~28 rare SING sites cannot make segmatch resolve the multi-bit DRIVE enum
(OUT stays <N candidates> at any N).  So the SING IOB db must mirror LIOB18's
names exactly; it cannot be independently fuzzed into a nextpnr-consumable form.
Resolution: replaced the hand-copy with a COMPLETE, correct mirror of every
LIOB18/RIOB18 IOB_Y0/Y1 feature (origin liob18-arch-mirror), excluding STEPDOWN
whose !00_127 (frame 0) bit overflows the SING tilegrid word window (word 102)
and corrupts neighbours -- left as a tolerated "not found" rather than the
corrupting "invalid word address".  picosoc now builds with only that one
benign STEPDOWN warning.  This is a same-part architectural mirror, NOT a
kintex7 transplant.

## SLICEM DOUTMUX.MC31 spurious A5FFMUX bit  (2026-07-02)
`CLBLM_{L,R}.SLICEM_X0.DOUTMUX.MC31` carried a spurious `30_10` — that bit is
`A5FFMUX.IN_B` (fuzzer-specimen contamination).  A real Vivado SRL cascade
(SRLC32E chain crossing a slice: A-LUT MC31 -> DMUX -> fabric -> next slice's
DI pin) sets only `{30_52, 30_57}` in the DOUTMUX group, so bit2fasm decoded NO
DOUTMUX feature and the cascade link was silently dropped.  Fix: remove `30_10`;
the remaining `!30_51 30_52 !30_56 30_57` is distinct from every other DOUTMUX
leg.  Found via the bit2verilog srl differential test (160-deep SRL, d3 diverged
at cycle 129 = the first value needing the cross-slice hop).
