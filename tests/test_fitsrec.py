import unittest
from fitsrec import parse_d_exponent

class TestDExponentParsing(unittest.TestCase):

    def test_valid_d_exponents(self):
        # Test valid D exponent formats
        self.assertAlmostEqual(parse_d_exponent("1.23D4"), 1.23e4)
        self.assertAlmostEqual(parse_d_exponent("-1.23D-4"), -1.23e-4)
        self.assertAlmostEqual(parse_d_exponent("0.0D0"), 0.0)

    def test_edge_cases(self):
        # Test edge cases
        self.assertAlmostEqual(parse_d_exponent("1D0"), 1.0)
        self.assertAlmostEqual(parse_d_exponent("-1D0"), -1.0)
        self.assertAlmostEqual(parse_d_exponent("1.0D-1"), 0.1)
        self.assertAlmostEqual(parse_d_exponent("1.0D+1"), 10.0)

    def test_d_exponent_replacement(self):
        # Test that 'D' exponent is correctly replaced and parsed
        self.assertAlmostEqual(parse_d_exponent("1.23D4"), 1.23e4)
        self.assertAlmostEqual(parse_d_exponent("-1.23D-4"), -1.23e-4)
        self.assertAlmostEqual(parse_d_exponent("0.0D0"), 0.0)

    def test_invalid_d_exponents(self):
        # Test invalid D exponent formats
        with self.assertRaises(ValueError):
            parse_d_exponent("1.23D")
        with self.assertRaises(ValueError):
            parse_d_exponent("D4")
        with self.assertRaises(ValueError):
            parse_d_exponent("1.23E4")  # Should raise if not handled

if __name__ == "__main__":
    unittest.main()
