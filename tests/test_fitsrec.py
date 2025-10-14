import unittest
from fitsrec import parse_d_exponent

class TestDExponentParsing(unittest.TestCase):

    def test_valid_d_exponents(self):
        # Test valid D exponent formats
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
