# Silicon delay calibration, xc7vx485t-2

`xc7vx485t-2.cal.json`: path delays measured on silicon, fitted as corrections to nextpnr-himbaechel's xilinx delay model.
These are typical delays of **one part** (one VC707), not worst case. They are for steering placement and routing and for ranking
layouts. They are not for setting a clock limit: sign-off timing still needs the speed-grade data (the SDFs in `../`) and margin.

## What was measured
- Board: VC707, xc7vx485t-2 (ffg1761). Regions X1Y5 and X1Y1. Die 37-48 C, VCCINT 1.004-1.011 V.
- Method: an open-flow partial reconfiguration window loaded by ICAP. Each path is launch flop -> route -> capture flop, with a
  reference flop on the launch net. The capture clock phase is swept with an MMCM's DRP over several VCO frequencies, and each edge is
  fitted as a Gaussian CDF. C-R is the capture time less the reference time, rise and fall separately.
- Fit set: hand-routed windows q1 l1 s1 q2 l2 (X1Y5). Held out: xq1 xl1 xs1 (X1Y1), with nothing refitted.

## Contents (`units`: ps)
- `classes.<c>.{rise,fall}`: factor on nextpnr's own delay of pips driving wires of class `c` (sgl, dbl, quad, hex, lvb, lv, lh).
- `per_use.{fan,byp}`: fixed cost per use of a fan or bypass pip; nextpnr prices these near 0 ps.
- `lut_pin.A<j>`: cost of a LUT stage entered on **physical** pin j, beyond its IMUX pip. A1/A2 cost about 215-240 ps, A6 0-16 ps.
- `lut_stage_overhead`: what nextpnr already charges per stage outside the LUT arc (20 ps site exit stub + 21 ps), subtracted from
  `lut_pin` when the costs go into a chipdb.
- Wire classes are defined in nextpnr's `xilinx_gen.py` (`cal_wire_class`).

## Accuracy (rms of C-R, rise / fall)
| | nextpnr stock | calibrated |
|---|---|---|
| held-out region X1Y1 (hand routes) | 468 / 344 | 38 / 39 |
| a nextpnr-routed window, 56 paths, nothing fitted on it | 508 / 612 | 201 / 223 |
| per-path change between two layouts of one netlist (50 paths) | 493 / 491 | 181 / 176 |

Within paths of equal LUT depth, the rank correlation with measurement is 0.77-0.86, against 0.30-0.36 for stock nextpnr. The stock
figures include a nextpnr bug, since fixed, in which permuted LUT inputs fell back to placement estimates.

## Known gaps
- Not modelled: LUT route-throughs (price them as a stage on the pin entered), the O5 output (about +30 ps), fanout loading (the fit's
  nets have fanout 1-2), and the temperature coefficient (150-540 ppm/C within one session).
- nextpnr has one delay per pip, so a chipdb built from this file uses the fall values.
- One part. Other parts, and other speed grades, have not been measured.

## Use
`python3 xilinx_gen.py --xray <prjxray-db>/artix7 --device xc7vx485t --bba chipdb.bba --timing-cal xc7vx485t-2.cal.json`. This needs the
`--timing-cal` option of nextpnr (jrrk2/nextpnr branch `routethru`; the option is not pushed yet). Without the option the generator's output is unchanged.
