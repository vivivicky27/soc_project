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

## Reproduction

See the [project README](README.md) for the VCS, Design Compiler, Innovus
and Calibre commands. The ECS run directory is
`/home/hy3281/soc_project_hy3281_check_01a1f4`.
