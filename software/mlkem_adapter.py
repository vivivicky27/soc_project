"""Use unchanged kyber-py 1.2.0, overriding only forward polynomial NTT."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "vendor"))

from kyber_py.ml_kem.default_parameters import DEFAULT_PARAMETERS
from kyber_py.ml_kem.ml_kem import ML_KEM
from kyber_py.polynomials.polynomials import Polynomial, PolynomialNTT

from ntt import SoftwareButterfly, forward_ntt

PARAMETERS = (512, 768, 1024)


class BackendPolynomial(Polynomial):
    def to_ntt(self):
        # Other vendor operations can produce signed/unreduced intermediates.
        # Normalize at our boundary to meet the hardware's unsigned contract.
        values = [int(c) % 3329 for c in self.coeffs]
        transformed = forward_ntt(values, self.parent.butterfly_backend)
        self.coeffs = transformed
        return self.parent(transformed, is_ntt=True)


class BackendPolynomialNTT(PolynomialNTT, BackendPolynomial):
    """Preserve vendor's NTT arithmetic and its polynomial type relationship."""


def make_mlkem(parameter=768, use_backend=True, backend=None):
    if parameter not in PARAMETERS:
        raise ValueError("parameter must be 512, 768 or 1024")
    kem = ML_KEM(DEFAULT_PARAMETERS[f"ML{parameter}"])
    if use_backend:
        kem.R.butterfly_backend = backend if backend is not None else SoftwareButterfly()
        kem.R.element = BackendPolynomial
        kem.R.element_ntt = BackendPolynomialNTT
    return kem
