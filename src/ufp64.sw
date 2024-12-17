library;

use core::ops::*;

/// Represents a fixed point number with 6 decimal places of precision
/// Internally stored as a u64 where the value is multiplied by 10^6
pub struct UFP64 {
    // The raw u64 value, scaled by SCALE
    value: u64,
}

/// Constants used throughout the implementation
pub const SCALE: u64 =      1_000_000; // 10^6
pub const HALF_SCALE: u64 = 500_000;   // 10^6 / 2


impl UFP64 {
    /// Creates a new UFP64 from a raw u64 value
    /// The value is assumed to already be scaled by SCALE
    pub fn from_raw(value: u64) -> Self {
        Self { value }
    }

    /// Creates a new UFP64 from a whole number
    pub fn from_u64(value: u64) -> Self {
        Self {
            value: value * SCALE
        }
    }

    /// Creates a new UFP64 from separate whole and decimal parts
    /// decimal_places specifies how many decimal places are in the decimal_part
    pub fn from_parts(whole: u64, decimal_part: u64, decimal_places: u32) -> Self {
        let whole_scaled = whole * SCALE;
        let decimal_scaled = if decimal_places >= 6 {
            decimal_part / 10.pow(decimal_places - 6)
        } else {
            decimal_part * 10.pow(6u32 - decimal_places)
        };
        Self {
            value: whole_scaled + decimal_scaled
        }
    }

    pub fn zero() -> Self {
        Self::from_u64(0)
    }

    /// Returns the raw underlying value
    pub fn raw_value(self) -> u64 {
        self.value
    }

    /// Returns the integer part of the fixed point number
    pub fn floor(self) -> u64 {
        self.value / SCALE
    }

    /// Returns the decimal part as a number between 0 and SCALE-1
    pub fn decimal_part(self) -> u64 {
        self.value % SCALE
    }

    /// Rounds the fixed point number to the nearest whole number
    pub fn round(self) -> u64 {
        let decimal = self.decimal_part();
        let whole = self.floor();
        
        if decimal >= HALF_SCALE {
            whole + 1
        } else {
            whole
        }
    }

}

impl From<u64> for UFP64 {
    fn from(val: u64) -> UFP64 {
        UFP64::from_u64(val)
    }
}

impl Add for UFP64 {
    /// Adds two fixed point numbers
    fn add(self, other: Self) -> Self {
        Self {
            value: self.value + other.value
        }
    }
}

impl Subtract for UFP64 {
    /// Subtracts two fixed point numbers
    fn subtract(self, other: Self) -> Self {
        Self {
            value: self.value - other.value
        }
    }
}

impl Multiply for UFP64 {
    /// Multiplies two fixed point numbers
    fn multiply(self, other: Self) -> Self {
        // Perform multiplication and then divide by SCALE to maintain fixed point
        let a = self.value * other.value;
        let a = a + HALF_SCALE;
        let result = ( a) / SCALE;
        Self {
            value: result
        }
    }
}

impl Divide for UFP64 {
    /// Divides two fixed point numbers
    fn divide(self, other: Self) -> Self {
        // Multiply by SCALE first to maintain precision
        let result = (self.value * SCALE + HALF_SCALE) / other.value;
        Self {
            value: result
        }
    }
}

impl Ord for UFP64 {
    /// Returns true if this value is greater than other
    fn gt(self, other: Self) -> bool {
        self.value > other.value
    }

    /// Returns true if this value is less than other
    fn lt(self, other: Self) -> bool {
        self.value < other.value
    }
}

impl Eq for UFP64 {
    /// Returns true if this value is equal to other
    fn eq(self, other: Self) -> bool {
        self.value == other.value
    }
}

impl UFP64 {
    /// Computes the square root using Newton-Raphson method
    /// Returns None if the input is zero
    /// Performs 4 iterations which gives sufficient precision for 6 decimal places
    pub fn sqrt(self) -> Option<Self> {
        if self.value == 0 {
            return None;
        }

        // Initial guess: scale the input down by SCALE to account for fixed point,
        // take the square root, then scale back up
        let mut x = UFP64::from_raw((self.value * SCALE).sqrt());
        
        // Newton-Raphson iterations: x = (x + n/x) / 2
        // Where n is our input number
        // We do 4 iterations which gives us sufficient precision
        let mut i = 0;
        while i < 4 {
            // Calculate n/x
            let div = self/x;
            // Add x + n/x
            let sum = x + div;
            // Divide by 2
            x = UFP64::from_raw((sum.value + 1) >> 1);

            i+=1;
        }

        Some(x)
    }
}



#[test]
fn test_fixed_point() {
    // Test basic creation and arithmetic
    let one = UFP64::from_u64(1);
    let two = UFP64::from_u64(2);
    let half = UFP64::from_parts(0, 5, 1);

    // Test addition
    let three = two + one;
    assert_eq(three.floor(), u64::from(3u64));

    // Test multiplication
    let result = two * half;
    assert_eq(result.floor(), u64::from(1u64));

    // Test division
    let result = one / two;
    assert_eq(result.decimal_part(), HALF_SCALE);

    // Test comparison
    assert(two > one);
    assert(half < one);
    assert(one == one);

    // 6.47893 * 38 = 246.19934 
    let term1 = UFP64::from_parts(6, 47893, 5);
    let term2 = UFP64::from_u64(38);
    let res = term1 * term2;
    let expected = UFP64::from_parts(246, 19934, 5);
    assert(res == expected);
    
    // 6.47893 * 38 + 23.1 = 269.29934
    let term3 = UFP64::from_parts(23, 1, 1);
    let res = res + term3;
    let expected = UFP64::from_parts(269, 29934, 5);
    assert(res == expected);
}


#[test]
fn test_sqrt() {
    // Test perfect squares
    let four = UFP64::from_u64(4);
    let two = UFP64::from_u64(2);
    assert_eq(four.sqrt().unwrap(), two);

    // Test with decimal places
    let n = UFP64::from_parts(2, 25, 2); // 2.25
    let expected = UFP64::from_parts(1, 5, 1); // 1.5
    let result = n.sqrt().unwrap();
    assert_eq(result, expected);

    // Test larger number
    let n = UFP64::from_parts(123, 456789, 6); // 123.456789
    let result = n.sqrt().unwrap();
    let expected = UFP64::from_parts(11, 111111, 6); // ~11.111111
    // Allow small margin of error due to rounding
    assert(result.value - expected.value < 10);

    // Test sqrt(2)
    let n = UFP64::from_u64(2); // 123.456789
    let result = n.sqrt().unwrap();
    let expected = UFP64::from_parts(1, 414213, 6); // ~1.41421356
   // Allow small margin of error due to rounding
    assert(result.value - expected.value < 100);

    // Test zero
    assert_eq(UFP64::zero().sqrt(), None);
}
