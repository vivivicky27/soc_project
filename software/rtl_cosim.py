"""Exercise the full NTT and application with a persistent VCS RTL process."""

import argparse
import json
from pathlib import Path
import random
import subprocess
from time import perf_counter

from demo import run_demo
from ntt import forward_ntt


class VcsButterfly:
    def __init__(self, simulator):
        simulator = simulator.resolve()
        self.calls = 0
        self.process = subprocess.Popen(
            [str(simulator), "-no_save"], cwd=simulator.parent,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
        )
        try:
            self.read_response("COSIM_READY")
        except Exception:
            self.process.kill()
            self.process.communicate()
            raise

    def read_response(self, label):
        for line in self.process.stdout:
            fields = line.split()
            if fields and fields[0] == label:
                return fields[1:]
        raise RuntimeError(f"Simulator ended before sending {label}")

    def __call__(self, a, b, zeta):
        self.process.stdin.write(f"{a} {b} {zeta}\n")
        self.process.stdin.flush()
        u, v = map(int, self.read_response("COSIM_RESULT"))
        self.calls += 1
        return u, v

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        if exc_type:
            self.process.kill()
        try:
            self.process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.communicate()
            raise
        if not exc_type and self.process.returncode:
            raise RuntimeError(f"Simulator exited with {self.process.returncode}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("simulator", type=Path)
    args = parser.parse_args()
    rng = random.Random(9433)
    coefficients = [rng.randrange(3329) for _ in range(256)]
    expected = forward_ntt(coefficients)
    started = perf_counter()
    with VcsButterfly(args.simulator) as backend:
        actual = forward_ntt(coefficients, backend=backend)
        mismatches = [i for i, (a, b) in enumerate(zip(actual, expected)) if a != b]
        if mismatches or backend.calls != 896:
            raise RuntimeError(f"NTT mismatch at {mismatches}; calls={backend.calls}")
        print(f"PASS: 256 coefficients matched after {backend.calls} RTL calls", flush=True)
        result = run_demo(b"ECE 9433 RTL co-simulation", backend=backend)
        print(json.dumps(result, indent=2))
    print(f"Co-simulation wall time: {perf_counter() - started:.3f} s")


if __name__ == "__main__":
    main()
