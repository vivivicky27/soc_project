import random
import unittest

from demo import run_demo
from mlkem_adapter import PARAMETERS, make_mlkem
from ntt import Q, SoftwareButterfly, butterfly, forward_ntt, bit_reverse_7


class SoftwareTests(unittest.TestCase):
    def test_butterfly_and_validation(self):
        self.assertEqual(butterfly(10, 4, 3), (22, 3327))
        for args in ((-1, 0, 0), (0, 3329, 0), (0, 0, 4095)):
            with self.assertRaises(ValueError):
                butterfly(*args)
        with self.assertRaises(TypeError):
            butterfly(True, 0, 0)
        for coeffs in ([0] * 255, [0] * 257, [Q] * 256):
            with self.assertRaises(ValueError):
                forward_ntt(coeffs)

    def test_ntt_matches_unmodified_reference(self):
        rng = random.Random(9433)
        cases = [[0] * 256, [1] * 256, [Q - 1] * 256, list(range(256))]
        cases += [[rng.randrange(Q) for _ in range(256)] for _ in range(100)]
        ring = make_mlkem(use_backend=False).R
        for coefficients in cases:
            original = coefficients.copy()
            backend = SoftwareButterfly()
            result = forward_ntt(coefficients, backend)
            self.assertEqual(result, ring(coefficients.copy()).to_ntt().coeffs)
            self.assertEqual(backend.calls, 896)
            self.assertEqual(coefficients, original)

    def test_ntt_against_direct_mathematical_definition(self):
        # Independent O(n^2) evaluation of the even/odd coefficient polynomials
        # at roots of y^128 + 1; no butterfly algorithm used here.
        rng = random.Random(203)
        coefficients = [rng.randrange(Q) for _ in range(256)]
        expected = []
        for i in range(128):
            root = pow(17, 2 * bit_reverse_7(i) + 1, Q)
            for parity in (0, 1):
                expected.append(sum(coefficients[2*j + parity] * pow(root, j, Q)
                                    for j in range(128)) % Q)
        self.assertEqual(forward_ntt(coefficients), expected)

    def test_integrated_mlkem_matches_reference_all_parameters(self):
        # Fixed seed/message ONLY for regression; demo uses system randomness.
        seed = bytes(range(64))
        for parameter in PARAMETERS:
            with self.subTest(parameter=parameter):
                ref = make_mlkem(parameter, use_backend=False)
                integrated = make_mlkem(parameter)
                ref_ek, ref_dk = ref.key_derive(seed)
                ek, dk = integrated.key_derive(seed)
                self.assertEqual((ek, dk), (ref_ek, ref_dk))
                ref.random_bytes = lambda n: bytes(range(n))
                integrated.random_bytes = lambda n: bytes(range(n))
                key, ct = integrated.encaps(ek)
                self.assertEqual((key, ct), ref.encaps(ref_ek))
                self.assertEqual(integrated.decaps(dk, ct), key)
                self.assertEqual(ref.decaps(ref_dk, ct), key)
                changed = bytes([ct[0] ^ 1]) + ct[1:]
                rejected_key = integrated.decaps(dk, changed)
                self.assertNotEqual(rejected_key, key)
                self.assertEqual(rejected_key, ref.decaps(ref_dk, changed))
                self.assertGreater(integrated.R.butterfly_backend.calls, 0)

    def test_end_to_end_messages(self):
        for parameter in PARAMETERS:
            for message in (b"", "中文测试".encode(), bytes(range(256))):
                with self.subTest(parameter=parameter, length=len(message)):
                    result = run_demo(message, parameter)
                    self.assertTrue(result["shared_secret_match"])
                    self.assertTrue(result["plaintext_match"])
                    self.assertTrue(result["tampered_tag_rejected"])
                    self.assertEqual(result["butterfly_calls"] % 896, 0)


if __name__ == "__main__":
    unittest.main()
