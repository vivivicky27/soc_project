"""Functional reference for the forward CT butterfly (ordinary residues).

This models arithmetic only, not clocks, valid signals, or pipeline latency.
No Montgomery or K-reduction scaling is applied.
"""

import argparse
from itertools import product
from pathlib import Path
import random

Q = 3329


def butterfly(a: int, b: int, zeta: int) -> tuple[int, int]:
    """Return ((a + b*zeta) mod Q, (a - b*zeta) mod Q).

    Inputs must be ordinary Python integers in [0, Q-1], matching the RTL
    contract. Python's % already gives a nonnegative residue for negative sums.
    """
    for name, value in (("a", a), ("b", b), ("zeta", zeta)):
        if type(value) is not int:
            raise TypeError(f"{name} must be an integer")
        if not 0 <= value < Q:
            raise ValueError(f"{name} must be in [0, {Q - 1}], got {value}")
    t = (b * zeta) % Q
    return (a + t) % Q, (a - t) % Q


def generate_vectors(count: int = 10000, seed: int = 1):
    """Yield a,b,zeta,u,v rows: example, 64 boundary cases, random cases."""
    if count < 0:
        raise ValueError("random vector count must be nonnegative")
    rng = random.Random(seed)
    yield 10, 4, 3, *butterfly(10, 4, 3)
    for a, b, zeta in product((0, 1, Q - 2, Q - 1), repeat=3):
        yield a, b, zeta, *butterfly(a, b, zeta)
    for _ in range(count):
        a, b, zeta = (rng.randrange(Q) for _ in range(3))
        yield a, b, zeta, *butterfly(a, b, zeta)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    calc = commands.add_parser("calc", help="calculate one butterfly")
    for name in ("a", "b", "zeta"):
        calc.add_argument(name, type=int)
    vectors = commands.add_parser("vectors", help="write decimal a b zeta u v rows")
    vectors.add_argument("output", type=Path)
    vectors.add_argument("--count", type=int, default=10000, help="random cases (plus 65 fixed cases)")
    vectors.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    try:
        if args.command == "calc":
            u, v = butterfly(args.a, args.b, args.zeta)
            print(f"u={u}, v={v}")
        else:
            if args.count < 0:
                parser.error("--count must be nonnegative")
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with args.output.open("w", encoding="ascii") as stream:
                for row in generate_vectors(args.count, args.seed):
                    stream.write(" ".join(map(str, row)) + "\n")
            print(f"Wrote {args.count + 65} vectors to {args.output}")
    except (TypeError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
