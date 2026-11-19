"""Run the course TSMC16 Calibre decks against an Innovus output directory."""

import argparse
import os
from pathlib import Path
import subprocess


PDK = Path("/ip/tsmc/tsmc16adfp")
TECH = PDK / "source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech"
DRC = TECH / "DRC/N16ADFP_DRC_Calibre/LOGIC_TopMr_DRC/N16ADFP_DRC_Calibre_11M.11_1a.encrypt"
LVS = TECH / "LVS/N16ADFP_LVS_Calibre/MAIN_DECK/CCI_FLOW/N16ADFP_LVS_Calibre"
SPICE = PDK / "stdcell/SPICE/N16ADFP_StdCell_100b.spi"


def prepare_deck(source, dest, replacements):
    content = source.read_bytes()
    for old, new in replacements.items():
        if content.count(old) != 1:
            raise RuntimeError(f"Expected exactly one {old!r} in {source}")
        content = content.replace(old, new)
    dest.write_bytes(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("drc", "lvs"))
    parser.add_argument("build_dir", type=Path)
    parser.add_argument("top", choices=tuple(f"butterfly_e{i}_hy3281" for i in range(3)))
    args = parser.parse_args()
    work = args.build_dir.resolve()
    if not (work / "routed.gds").stat().st_size:
        raise RuntimeError("Routed GDS is empty")
    top = args.top.encode()
    deck = work / f"{args.mode}.svrf"
    with (work / f"calibre_{args.mode}.log").open("w") as log:
        if args.mode == "drc":
            prepare_deck(DRC, deck, {
                b'"GDSFILENAME"': b'"routed.gds"',
                b'"TOPCELLNAME"': b'"' + top + b'"',
            })
        else:
            subprocess.run(
                ["v2lvs", "-v", "routed_pg.v", "-s", str(SPICE), "-lsr", str(SPICE),
                 "-s0", "VSS", "-s1", "VDD", "-o", "source.cdl"],
                cwd=work, stdout=log, stderr=subprocess.STDOUT, check=True,
            )
            prepare_deck(LVS, deck, {
                b'LAYOUT PRIMARY "lvs_top"': b'LAYOUT PRIMARY "' + top + b'"',
                b'SOURCE PRIMARY "lvs_top"': b'SOURCE PRIMARY "' + top + b'"',
                b'"lvs_top.gds"': b'"routed.gds"',
                b'"lvs_top.cdl"': b'"source.cdl"',
                b'INCLUDE ./DFM/lod_measure.encrypt':
                    b'INCLUDE "' + str(LVS.parent / "DFM/lod_measure.encrypt").encode() + b'"',
            })
        # The ECS login shell can select a Calibre OA version for GUI use.
        # These decks read GDS and SPICE, so let Calibre use its bundled default.
        calibre_env = os.environ.copy()
        calibre_env.pop("MGC_FDI_OA_VERSION", None)
        subprocess.run(
            ["calibre", f"-{args.mode}", "-hier", str(deck)],
            cwd=work, env=calibre_env, stdout=log, stderr=subprocess.STDOUT, check=True,
        )
    report = work / ("DRC.rep" if args.mode == "drc" else "lvs.rep")
    if not report.stat().st_size:
        raise RuntimeError(f"Empty Calibre report: {report}")
    print(f"Inspect Calibre {args.mode.upper()} results in {report}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(
            f"{error.cmd[0]} exited with {error.returncode}. "
            "Inspect the corresponding calibre_drc.log or calibre_lvs.log "
            "and any report written in the build directory."
        ) from error
