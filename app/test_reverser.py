"""Unit tests for the number-reversal logic."""

import pytest
from reverser import reverse_number


class TestHappyPath:
    def test_basic_reversal(self):
        assert reverse_number("12345") == "54321"

    def test_single_digit(self):
        assert reverse_number("7") == "7"

    def test_round_trip(self):
        assert reverse_number("123") == "321"


class TestNegativeNumbers:
    def test_negative_preserves_sign(self):
        assert reverse_number("-123") == "-321"

    def test_negative_single_digit(self):
        assert reverse_number("-5") == "-5"

    def test_negative_with_trailing_zero(self):
        # -1200 reversed → -0021 → -21
        assert reverse_number("-1200") == "-21"


class TestLeadingAndTrailingZeros:
    def test_trailing_zeros_become_leading_zeros_stripped(self):
        # 1200 → 0021 → 21
        assert reverse_number("1200") == "21"

    def test_input_zero(self):
        assert reverse_number("0") == "0"

    def test_all_zeros(self):
        assert reverse_number("000") == "0"


class TestNonNumericInput:
    def test_letters_raise_value_error(self):
        with pytest.raises(ValueError, match="Non-numeric"):
            reverse_number("abc")

    def test_float_string_raises_value_error(self):
        with pytest.raises(ValueError, match="Non-numeric"):
            reverse_number("1.5")

    def test_empty_string_raises_value_error(self):
        with pytest.raises(ValueError, match="must not be empty"):
            reverse_number("")

    def test_whitespace_only_raises(self):
        with pytest.raises(ValueError, match="must not be empty"):
            reverse_number("   ")

    def test_alphanumeric_raises(self):
        with pytest.raises(ValueError, match="Non-numeric"):
            reverse_number("12ab")


class TestIntegerOverflow:
    def test_large_number_within_range(self):
        # 9223372036854775807 reversed = 7085746360273372329 — still in range
        assert reverse_number("9223372036854775807") == "7085746360273372329"

    def test_overflow_raises_value_error(self):
        # A number whose reversal exceeds INT64_MAX
        with pytest.raises(ValueError, match="64-bit"):
            reverse_number("99999999999999999999")
