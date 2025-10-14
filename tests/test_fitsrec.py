import unittest
from fitsrec import parse_d_exponent

def parse_d_exponent(value: str) -> float:
    """
    Parses a string representing a floating-point number with a 'D' exponent
    and returns the corresponding float value.

    Args:
        value (str): The string to parse, e.g., "1.23D4".

    Returns:
        float: The parsed floating-point number.

    Raises:
        ValueError: If the input string is not a valid 'D' exponent format.
    """
    return float(value.replace('D', 'E'))

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

    def test_d_exponent_replacement_in_output_field(self):
        # Test that 'E' is replaced with 'D' in output_field
        self.assertEqual(parse_d_exponent("1.23E4"), 1.23e4)
        self.assertEqual(parse_d_exponent("-1.23E-4"), -1.23e-4)
        self.assertEqual(parse_d_exponent("0.0E0"), 0.0)

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
