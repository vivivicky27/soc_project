# ECE 9433 NTT Butterfly Implementation Results

## Scope

E0 computes the transform in one combinational path with registered outputs.
E1 uses four register stages. E2 keeps that pipeline and uses a fixed-modulus
Barrett reduction. The coefficient memory, twiddle selection and seven-layer
NTT schedule run in Python. VCS executes the Butterfly calls in co-simulation.

## Functional results on ecs03.poly.edu

| Check | Result |
|---|---|
| Original RTL simulation | 10,068 transactions passed |
| Original RTL and mapped-netlist comparison | 10,065 Python reference vectors passed in each simulation |
| E0 and E1 standalone VCS | Passed |
| E2 standalone VCS | Passed. It completed all 822 accepted requests across 1,013 checked cycles |
| Full NTT with E1 in VCS | All 256 output coefficients matched after 896 RTL transactions |
| Full NTT with E2 in VCS | All 256 output coefficients matched after 896 RTL transactions |
| ML-KEM-768 and AES-GCM with E1 or E2 | 15 transforms and 13,440 RTL transactions per demonstration. Shared secrets matched, plaintext recovered, and the modified tag was rejected |

One measured run took 0.895 s for E1 and 0.677 s for E2, including the standalone
NTT, application demonstration, and simulator process overhead. The serial
driver waits for each response, so these times do not measure ASIC throughput.
E1 and E2 produce a result three rising edges after acceptance and both have
an initiation interval of one clock cycle.

## Logical synthesis

Design Compiler used a 10 ns clock, the TSMC 16 nm TT 0.8 V / 25 C library,
and the same I/O timing assumptions for all three designs.

| Version | Mapped cell area (µm²) | Worst reported setup slack (ns) |
|---|---:|---:|
| E0 | 507.51 | +4.17 |
| E1 | 755.62 | +7.10 |
| E2 | 878.12 | +7.63 |

E2 used 16.2% more mapped area than E1 and improved setup slack by 0.53 ns
under those constraints. The measurements precede placement and routing.

## Routed implementations

Innovus exported DEF, GDS and physical Verilog for all three variants. The
timing view uses TT cell timing and the course worst-RC Quantus model. E1 used
floorplan-mode placement followed by separate legalization after the default
timing-driven placement repeatedly hit the host memory limit. E1's physical
results therefore use different placement settings from E0 and E2.

| Version | Post-route cell area (µm²) | Setup WNS (ns) | Hold WNS (ns) | Violating paths |
|---|---:|---:|---:|---:|
| E0 | 507.514 | +4.407 | +0.011 | 0 |
| E1 (recovery placement) | 758.212 | +7.339 | +0.021 | 0 |
| E2 | 880.917 | +7.633 | +0.020 | 0 |

| Physical check | Result |
|---|---|
| Innovus full-design DRC | Each version reached the 1,000-marker report limit. The listed E0 markers were M5 minimum-step violations on power routing |
| Innovus connectivity | 356 disconnected terminals, 6 special-route opens, 10 regular-route opens, and 28 dangling wires |
| Calibre DRC | E0 had 57,745 results (208,873 counting occurrences), E1 had 61,026 (249,612), and E2 had 71,988 (275,672) |
| Calibre LVS | All three returned NOT COMPARED. The E0 extraction recognized top-level pins but produced zero devices and reported `Nothing in layout` |

The Calibre DRC totals are from the course PDK deck with its default switches.
The Calibre LVS deck also returned `Nothing in layout` for the standalone
`INVD12BWP16P90` supplied in the PDK standard-cell GDS. Pegasus was
unavailable for a second comparison because its LVS license checkout failed.
This reproduces the extraction failure outside the Butterfly layout. A
working cell-level extraction setup is needed before interpreting Butterfly
LVS differences. Routed designs are in `build/physical_e0/`,
`build/physical_e1_recovery/` and `build/physical_e2/`. E0's first completed
Calibre logs and reports are in `build/calibre_e0_preview/`.

An E0 power-grid experiment snapped stripes to the routing grid, adjusted the
M5 stripe geometry and restricted special routing jogs. Innovus reported 20
DRC markers (16 spacing, two shorts and two minimum-cut). The 356 disconnected
terminals remained, and special-route opens increased from six to seven.
The experiment is isolated under `build/pg_e0_probe/` and is reproducible with
`make probe-pg-e0-hy3281`.

## Reproduction

See the [project README](README.md) for the VCS, Design Compiler, Innovus
and Calibre commands. The ECS run directory is
`/home/hy3281/soc_project_hy3281_check_01a1f4`.
