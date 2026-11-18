import unittest

from golden_model import Q, butterfly, generate_vectors


class GoldenModelTests(unittest.TestCase):
    def test_known_answers(self):
        for inputs, expected in (
            ((10, 4, 3), (22, 3327)),
            ((0, 0, 0), (0, 0)),
            ((3328, 3328, 3328), (0, 3327)),
            ((1, 3328, 1), (0, 2)),
            ((3328, 0, 3328), (3328, 3328)),
        ):
            self.assertEqual(butterfly(*inputs), expected)

    def test_all_input_positions_reject_invalid_values(self):
        for position in range(3):
            for value in (-1, Q, 4095):
                operands = [0, 0, 0]
                operands[position] = value
                with self.assertRaises(ValueError):
                    butterfly(*operands)
            for value in (1.5, "1", True):
                operands = [0, 0, 0]
                operands[position] = value
                with self.assertRaises(TypeError):
                    butterfly(*operands)

    def test_vectors_obey_algebraic_identities(self):
        for a, b, zeta, u, v in generate_vectors(10000):
            self.assertTrue(0 <= u < Q and 0 <= v < Q)
            self.assertEqual((u + v) % Q, (2 * a) % Q)
            self.assertEqual((u - v) % Q, (2 * b * zeta) % Q)

    def test_reproducible_vectors(self):
        rows = list(generate_vectors(10, seed=42))
        self.assertEqual(len(rows), 75)
        self.assertEqual(rows, list(generate_vectors(10, seed=42)))
        self.assertNotEqual(rows, list(generate_vectors(10, seed=43)))
        with self.assertRaises(ValueError):
            list(generate_vectors(-1))


if __name__ == "__main__":
    unittest.main()
