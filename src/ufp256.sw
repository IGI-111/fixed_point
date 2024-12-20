library;

use core::ops::*;

/// Represents a fixed point number with 18 decimal places of precision
/// Internally stored as a u256 where the value is multiplied by 10^18
pub struct UFP256 {
    // The raw u256 value, scaled by SCALE
    value: u256,
}

/// Constants used throughout the implementation
pub const SCALE: u256 =      0xDE0B6B3A7640000; // 10^18
pub const HALF_SCALE: u256 = 0x6F05B59D3B20000; // 10^18 / 2


impl UFP256 {
    /// Creates a new UFP256 from a raw u256 value
    /// The value is assumed to already be scaled by SCALE
    pub fn from_raw(value: u256) -> Self {
        Self { value }
    }

    /// Creates a new UFP256 from a whole number
    pub fn from_u256(value: u256) -> Self {
        Self {
            value: value * SCALE
        }
    }

    /// Creates a new UFP256 from separate whole and decimal parts
    /// decimal_places specifies how many decimal places are in the decimal_part
    pub fn from_parts(whole: u256, decimal_part: u256, decimal_places: u32) -> Self {
        let whole_scaled = whole * SCALE;
        let decimal_scaled = if decimal_places >= 18 {
            decimal_part / u256::from(10u64).pow(decimal_places - 18)
        } else {
            decimal_part * u256::from(10u64).pow(18u32 - decimal_places)
        };
        Self {
            value: whole_scaled + decimal_scaled
        }
    }

    pub fn zero() -> Self {
        Self::from_u256(0)
    }

    /// Returns the raw underlying value
    pub fn raw_value(self) -> u256 {
        self.value
    }

    /// Returns the integer part of the fixed point number
    pub fn floor(self) -> u256 {
        self.value / SCALE
    }

    /// Returns the decimal part as a number between 0 and SCALE-1
    pub fn decimal_part(self) -> u256 {
        self.value % SCALE
    }

    /// Rounds the fixed point number to the nearest whole number
    pub fn round(self) -> u256 {
        let decimal = self.decimal_part();
        let whole = self.floor();
        
        if decimal >= HALF_SCALE {
            whole + 1
        } else {
            whole
        }
    }
}

impl From<u256> for UFP256 {
    fn from(val: u256) -> UFP256 {
        UFP256::from_u256(val)
    }
}

impl Add for UFP256 {
    /// Adds two fixed point numbers
    fn add(self, other: Self) -> Self {
        Self {
            value: self.value + other.value
        }
    }
}

impl Subtract for UFP256 {
    /// Subtracts two fixed point numbers
    fn subtract(self, other: Self) -> Self {
        Self {
            value: self.value - other.value
        }
    }
}

impl Multiply for UFP256 {
    /// Multiplies two fixed point numbers
    fn multiply(self, other: Self) -> Self {
        // Perform multiplication and then divide by SCALE to maintain fixed point
        let result = self.value * other.value;
        Self {
            value: (result + HALF_SCALE) / SCALE  // Round to nearest
        }
    }
}

impl Divide for UFP256 {
    /// Divides two fixed point numbers
    fn divide(self, other: Self) -> Self {
        // Multiply by SCALE first to maintain precision
        let result = (self.value * SCALE + HALF_SCALE) / other.value;
        Self {
            value: result
        }
    }
}

impl Ord for UFP256 {
    /// Returns true if this value is greater than other
    fn gt(self, other: Self) -> bool {
        self.value > other.value
    }

    /// Returns true if this value is less than other
    fn lt(self, other: Self) -> bool {
        self.value < other.value
    }
}

impl Eq for UFP256 {
    /// Returns true if this value is equal to other
    fn eq(self, other: Self) -> bool {
        self.value == other.value
    }
}


#[test]
fn test_fixed_point() {
    // Test basic creation and arithmetic
    let one = UFP256::from_u256(0x1);
    let two = UFP256::from_u256(0x2);
    let half = UFP256::from_parts(0x0, 0x5, 1);

    // Test addition
    let three = two + one;
    assert_eq(three.floor(), u256::from(3u64));

    // Test multiplication
    let result = two * half;
    assert_eq(result.floor(), u256::from(1u64));

    // Test division
    let result = one / two;
    assert_eq(result.decimal_part(), HALF_SCALE);

    // Test comparison
    assert(two > one);
    assert(half < one);
    assert(one == one);


    // 6.4789374 * 38 = 246.1996212 
    let term1 = UFP256::from_parts(0x6, 0x49147E, 7);
    let term2 = UFP256::from_u256(0x26);
    let res = term1 * term2;
    let expected = UFP256::from_parts(0xF6, 0x1E75B4, 7);
    assert(res == expected);
    
    // 6.4789374 * 38 + 23.1 = 269.2996212
    let term3 = UFP256::from_parts(0x17, 0x1, 1);
    let res = res + term3;
    let expected = UFP256::from_parts(0x10D, 0x2DB7F4, 7);
    assert(res == expected);
    
}
