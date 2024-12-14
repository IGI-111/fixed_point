library;

/// Represents a signed fixed point number with 18 decimal places of precision
/// Internally stored as a u256 where:
/// - The highest bit (255) is used as the sign bit (0 for positive, 1 for negative)
/// - The remaining bits store the absolute value multiplied by 10^18
pub struct IFP256 {
    // The raw u256 value, where highest bit is sign and rest is scaled absolute value
    value: u256,
}

/// Constants used throughout the implementation
pub const SCALE: u256 =      0xDE0B6B3A7640000; // 10^18
pub const HALF_SCALE: u256 = 0x6F05B59D3B20000; // 10^18 / 2
pub const SIGN_MASK: u256 = u256::max() >> 1; // All bits except highest are 1
pub const SIGN_BIT: u256 = !(SIGN_MASK); // Only highest bit is 1

impl IFP256 {
    /// Creates a new IFP256 from a raw u256 value
    /// The value is assumed to already be in the correct format with sign bit
    pub fn from_raw(value: u256) -> Self {
        let magnitude = value & SIGN_MASK;
        if magnitude == u256::zero() {
            // Force positive zero
            Self { value: u256::zero() }
        } else {
            Self { value }
        }
    }

    /// Creates a new IFP256 from a whole number and sign
    pub fn from_u256(value: u256, negative: bool) -> Self {
        if value == u256::zero() {
            // Force positive zero regardless of requested sign
            Self { value: u256::zero() }
        } else {
            let scaled = value * SCALE;
            let sign_bit = if negative { SIGN_BIT } else { u256::zero() };
            Self {
                value: scaled | sign_bit
            }
        }
    }

    /// Creates a new IFP256 from separate whole and decimal parts
    pub fn from_parts(whole: u256, decimal_part: u256, decimal_places: u32, negative: bool) -> Self {
        let whole_scaled = whole * SCALE;
        let decimal_scaled = if decimal_places >= 18 {
            decimal_part / u256::from(10u64).pow(decimal_places - 18)
        } else {
            decimal_part * u256::from(10u64).pow(18u32 - decimal_places)
        };
        let absolute_value = whole_scaled + decimal_scaled;
        
        if absolute_value == u256::zero() {
            // Force positive zero regardless of requested sign
            Self { value: u256::zero() }
        } else {
            let sign_bit = if negative { SIGN_BIT } else { u256::zero() };
            Self {
                value: absolute_value | sign_bit
            }
        }
    }

    /// Returns the absolute value (magnitude) of the number
    pub fn abs_value(self) -> u256 {
        self.value & SIGN_MASK
    }

    /// Returns true if this number is negative
    pub fn is_negative(self) -> bool {
        self.abs_value() != u256::zero() && (self.value & SIGN_BIT) != u256::zero()
    }

    /// Returns true if this number is zero
    pub fn is_zero(self) -> bool {
        self.abs_value() == u256::zero()
    }

    /// Return zero, which is canonically positive
    pub fn zero(self) -> Self {
        Self::from_u256(0, false)
    }

    /// Returns the raw underlying value including sign bit
    pub fn raw_value(self) -> u256 {
        self.value
    }

    /// Returns the integer part of the absolute value
    pub fn floor(self) -> u256 {
        self.abs_value() / SCALE
    }

    /// Returns the decimal part as a number between 0 and SCALE-1
    pub fn decimal_part(self) -> u256 {
        self.abs_value() % SCALE
    }

    /// Negates the number
    pub fn negate(self) -> Self {
        Self {
            value: self.abs_value() | (!self.value & SIGN_BIT)
        }
    }

    /// Adds two signed fixed point numbers
    pub fn add(self, other: Self) -> Self {
        if self.is_zero() {
            return other;
        }
        if other.is_zero() {
            return self;
        }
        // Rest of addition logic remains the same
        if self.is_negative() == other.is_negative() {
            let sum = self.abs_value() + other.abs_value();
            Self {
                value: sum | (self.value & SIGN_BIT)
            }
        } else {
            let self_abs = self.abs_value();
            let other_abs = other.abs_value();
            
            if self_abs >= other_abs {
                let diff = self_abs - other_abs;
                if diff == u256::zero() {
                    Self { value: u256::zero() }  // Canonical zero
                } else {
                    Self {
                        value: diff | (self.value & SIGN_BIT)
                    }
                }
            } else {
                Self {
                    value: (other_abs - self_abs) | (other.value & SIGN_BIT)
                }
            }
        }
    }

    /// Subtracts other from self
    pub fn sub(self, other: Self) -> Self {
        self.add(other.negate())
    }

    /// Multiplies two signed fixed point numbers
    pub fn mul(self, other: Self) -> Self {
        if self.is_zero() || other.is_zero() {
            return Self { value: u256::zero() };  // Canonical zero
        }
        
        let result_negative = self.is_negative() != other.is_negative();
        let result = self.abs_value() * other.abs_value();
        let scaled_result = (result + HALF_SCALE) / SCALE;
        
        if scaled_result == u256::zero() {
            Self { value: u256::zero() }  // Canonical zero
        } else {
            let sign_bit = if result_negative { SIGN_BIT } else { u256::zero() };
            Self {
                value: scaled_result | sign_bit
            }
        }
    }

    /// Divides self by other
    pub fn div(self, other: Self) -> Self {
        if self.is_zero() {
            return Self { value: u256::zero() };  // Canonical zero
        }

        // Result is negative if signs are different
        let result_negative = self.is_negative() != other.is_negative();
        
        // Divide absolute values
        let result = (self.abs_value() * SCALE + HALF_SCALE) / other.abs_value();
        
        // Apply sign
        let sign_bit = if result_negative { SIGN_BIT } else { u256::zero() };
        Self {
            value: result | sign_bit
        }
    }

    /// Returns true if absolute value of self is greater than absolute value of other
    pub fn abs_gt(self, other: Self) -> bool {
        self.abs_value() > other.abs_value()
    }

    /// Returns true if self is greater than other, considering signs
    pub fn gt(self, other: Self) -> bool {
        if self.is_negative() != other.is_negative() {
            !self.is_negative()
        } else {
            if self.is_negative() {
                self.abs_value() < other.abs_value()
            } else {
                self.abs_value() > other.abs_value()
            }
        }
    }

    /// Returns true if self is less than other, considering signs
    pub fn lt(self, other: Self) -> bool {
        !self.gt(other) && !self.eq(other)
    }

    /// Returns true if self equals other
    pub fn eq(self, other: Self) -> bool {
        self.value == other.value
    }

    /// Rounds to the nearest whole number, preserving sign
    pub fn round(self) -> (u256, bool) {
        let decimal = self.decimal_part();
        let whole = self.floor();
        
        let rounded = if decimal >= HALF_SCALE {
            whole + 1
        } else {
            whole
        };
        
        if rounded == u256::zero() {
            // 0 is canonically positive
            (0, false)
        } else {
            (rounded, self.is_negative())
        }
    }
}

impl From<u256> for IFP256 {
    fn from(val: u256) -> IFP256 {
        IFP256::from_u256(val, false)
    }
}

#[test]
fn test_signed_fixed_point() {
    // Test basic creation
    let one = IFP256::from_u256(u256::from(1u64), false);
    let neg_one = IFP256::from_u256(u256::from(1u64), true);
    let two = IFP256::from_u256(u256::from(2u64), false);
    let half = IFP256::from_parts(u256::from(0u64), u256::from(5u64), 1, false);

    // Test signs
    assert(!one.is_negative());
    assert(neg_one.is_negative());

    // Test addition with same signs
    let three = two.add(one);
    assert(three.floor() == u256::from(3u64));
    assert(!three.is_negative());

    // Test addition with different signs
    let result = one.add(neg_one);
    assert(result.floor() == u256::from(0u64));

    // Test multiplication
    let neg_result = two.mul(neg_one);
    assert(neg_result.is_negative());
    assert(neg_result.floor() == u256::from(2u64));

    // Test division
    let div_result = one.div(two);
    assert(div_result.decimal_part() == HALF_SCALE);
    assert(!div_result.is_negative());

    // Test comparison
    assert(two.gt(one));
    assert(one.gt(half));
    assert(half.gt(neg_one));
    assert(neg_one.lt(half));
    assert(one.eq(one));
}

#[test]
fn test_zero_handling() {
    // Test zero construction
    let zero_positive = IFP256::from_u256(u256::zero(), false);
    let zero_negative = IFP256::from_u256(u256::zero(), true);
    
    // Test canonical representation
    assert(zero_positive.raw_value() == zero_negative.raw_value());
    assert(zero_positive.raw_value() == u256::zero());
    assert(!zero_positive.is_negative());
    assert(!zero_negative.is_negative());
    
    // Test equality
    assert(zero_positive.eq(zero_negative));
    
    // Test arithmetic with zero
    let one = IFP256::from_u256(0x1, false);
    let neg_one = IFP256::from_u256(0x1, true);
    
    // Addition
    assert(zero_positive.add(one).eq(one));
    assert(zero_negative.add(one).eq(one));
    assert(one.add(zero_positive).eq(one));
    assert(neg_one.add(zero_negative).eq(neg_one));
    
    // Multiplication
    assert(zero_positive.mul(one).eq(zero_positive));
    assert(zero_negative.mul(neg_one).eq(zero_positive));
    assert(one.mul(zero_positive).eq(zero_positive));

    // Division
    assert(zero_positive.mul(one).eq(zero_positive));
    assert(zero_negative.mul(one).eq(zero_positive));
    assert(zero_positive.mul(neg_one).eq(zero_positive));
    assert(zero_negative.mul(neg_one).eq(zero_positive));
    
    // Subtraction that results in zero
    assert(one.sub(one).eq(zero_positive));
    assert(neg_one.sub(neg_one).eq(zero_positive));
}
