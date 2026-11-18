"""Forward ML-KEM NTT with a replaceable, canonical-residue butterfly."""

Q = 3329
N = 256


def bit_reverse_7(value):
    return int(f"{value:07b}"[::-1], 2)


ZETAS = tuple(pow(17, bit_reverse_7(i), Q) for i in range(128))


def butterfly(a, b, zeta):
    """Same arithmetic contract as ../rtl/ntt_butterfly.sv."""
    for value in (a, b, zeta):
        if type(value) is not int:
            raise TypeError("butterfly inputs must be integers")
        if not 0 <= value < Q:
            raise ValueError("butterfly inputs must be in [0, 3328]")
    t = b * zeta % Q
    return (a + t) % Q, (a - t) % Q


class SoftwareButterfly:
    """Callable backend. A future RTL backend can implement the same call."""

    def __init__(self):
        self.calls = 0

    def __call__(self, a, b, zeta):
        result = butterfly(a, b, zeta)
        self.calls += 1
        return result


def forward_ntt(coefficients, backend=butterfly):
    """Return 256 ordinary residues in ML-KEM's NTT output order.

    Seven layers, 128 butterflies each. The input is not mutated.
    No Montgomery scaling or extra bit-reversal permutation is applied.
    """
    values = list(coefficients)
    if len(values) != N:
        raise ValueError("NTT requires exactly 256 coefficients")
    for value in values:
        if type(value) is not int:
            raise TypeError("NTT coefficients must be integers")
        if not 0 <= value < Q:
            raise ValueError("NTT coefficients must be in [0, 3328]")
    k = 1
    length = 128
    while length >= 2:
        for start in range(0, N, 2 * length):
            zeta = ZETAS[k]
            k += 1
            for j in range(start, start + length):
                u, v = backend(values[j], values[j + length], zeta)
                if type(u) is not int or type(v) is not int or not (0 <= u < Q and 0 <= v < Q):
                    raise ValueError("backend must return two integer residues in [0, 3328]")
                values[j], values[j + length] = u, v
        length //= 2
    return values
