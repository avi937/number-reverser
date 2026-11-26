"""
Core number-reversal logic.

Edge-case decisions:
  - Negative numbers  : preserve the minus sign  (-123 → -321)
  - Leading/trailing zeros : stripped by Python int cast (0120 → not valid int literal;
    if we receive "0120" as a string we return "021" → "21" after int parse)
  - Non-numeric input  : raise ValueError with a descriptive message
  - Integer overflow   : Python ints are arbitrary precision; we cap at 64-bit signed
    range (-9223372036854775808 to 9223372036854775807) and raise if the
    *reversed* result would exceed that range.
"""

INT64_MAX = 9_223_372_036_854_775_807
INT64_MIN = -9_223_372_036_854_775_808


def reverse_number(value: str) -> str:
    """Reverse the digits of an integer string.

    Args:
        value: A string representation of an integer (e.g. "12345", "-678").

    Returns:
        The reversed string (e.g. "54321", "-876").

    Raises:
        ValueError: If input is not a valid integer or the result overflows 64-bit signed range.
    """
    value = value.strip()

    if not value:
        raise ValueError("Input must not be empty.")

    # Detect and preserve sign
    negative = value.startswith("-")
    digits = value[1:] if negative else value

    # Validate that the remaining part is all digits
    if not digits.isdigit():
        raise ValueError(
            f"Non-numeric input: '{value}'. Only integer strings are accepted."
        )

    # Strip leading zeros from the digit string, reverse, strip trailing zeros
    # (which become leading zeros after reversal)
    reversed_digits = digits[::-1].lstrip("0") or "0"

    # Handle special case: "-0" should return "0"
    if negative and reversed_digits == "0":
        return "0"

    # Reconstruct with sign
    result_str = f"-{reversed_digits}" if negative else reversed_digits
    result_int = int(result_str)

    # 64-bit signed overflow guard
    if result_int > INT64_MAX or result_int < INT64_MIN:
        raise ValueError(
            f"Reversed result {result_int} exceeds 64-bit signed integer range."
        )

    return result_str
