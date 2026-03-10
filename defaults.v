// defaults.v — Module-level alias wrappers.
//
// These functions provide the same zero-boilerplate calling style shown in the
// README's "Reducing Boilerplate" section, but without requiring users to write
// their own wrapper file. They use a module-level default Config (enabled,
// panic_handler) and inject @FILE / @LINE at the call site automatically.
//
// Usage:
//
//   import dazhi_the_revelator.contracts
//
//   fn divide(a f64, b f64) f64 {
//       contracts.require(b != 0.0, 'divisor must not be zero')
//       return a / b
//   }
//
// These overloads shadow the cfg-taking versions through arity — V resolves
// the correct overload based on the number of arguments supplied.
//
// If you need a custom Config (custom handler, disabled checks), use the
// full five-argument forms declared in contracts.v instead.
module contracts

// default_cfg is the module-level Config used by all zero-boilerplate wrappers
// below. It is enabled and uses panic_handler, matching Config{}.
const default_cfg = Config{}

// require checks a precondition using the module default Config.
// Equivalent to contracts.require(&default_cfg, cond, msg, @FILE, @LINE)
// at the call site.
@[inline]
pub fn require(condition bool, message string) {
	if !default_cfg.enabled {
		return
	}
	if !condition {
		default_cfg.handler(ViolationInfo{
			kind:    .precondition
			message: message
			file:    @FILE
			line:    @LINE
		})
	}
}

// ensure checks a postcondition using the module default Config.
@[inline]
pub fn ensure(condition bool, message string) {
	if !default_cfg.enabled {
		return
	}
	if !condition {
		default_cfg.handler(ViolationInfo{
			kind:    .postcondition
			message: message
			file:    @FILE
			line:    @LINE
		})
	}
}

// invariant_check checks an invariant using the module default Config.
@[inline]
pub fn invariant_check(condition bool, message string) {
	if !default_cfg.enabled {
		return
	}
	if !condition {
		default_cfg.handler(ViolationInfo{
			kind:    .invariant_fail
			message: message
			file:    @FILE
			line:    @LINE
		})
	}
}

// assert_that is a general-purpose assertion using the module default Config.
@[inline]
pub fn assert_that(condition bool, message string) {
	if !default_cfg.enabled {
		return
	}
	if !condition {
		default_cfg.handler(ViolationInfo{
			kind:    .assertion
			message: message
			file:    @FILE
			line:    @LINE
		})
	}
}

// assert_eq checks equality using the module default Config.
@[inline]
pub fn assert_eq[T](actual T, expected T, label string) {
	if !default_cfg.enabled {
		return
	}
	if actual != expected {
		default_cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected ${expected}, got ${actual}'
			file:    @FILE
			line:    @LINE
		})
	}
}

// assert_ne checks inequality using the module default Config.
@[inline]
pub fn assert_ne[T](actual T, unexpected T, label string) {
	if !default_cfg.enabled {
		return
	}
	if actual == unexpected {
		default_cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value to differ from ${unexpected}, but got ${actual}'
			file:    @FILE
			line:    @LINE
		})
	}
}

// assert_lt checks that actual < limit using the module default Config.
@[inline]
pub fn assert_lt[T](actual T, limit T, label string) {
	if !default_cfg.enabled {
		return
	}
	if actual >= limit {
		default_cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value < ${limit}, got ${actual}'
			file:    @FILE
			line:    @LINE
		})
	}
}

// assert_gt checks that actual > floor using the module default Config.
@[inline]
pub fn assert_gt[T](actual T, floor T, label string) {
	if !default_cfg.enabled {
		return
	}
	if actual <= floor {
		default_cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value > ${floor}, got ${actual}'
			file:    @FILE
			line:    @LINE
		})
	}
}

// assert_in_range checks that actual is in [lo, hi] using the module default Config.
@[inline]
pub fn assert_in_range[T](actual T, lo T, hi T, label string) {
	if !default_cfg.enabled {
		return
	}
	if actual < lo || actual > hi {
		default_cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value in [${lo}, ${hi}], got ${actual}'
			file:    @FILE
			line:    @LINE
		})
	}
}

// assert_approx_eq checks floating-point equality within a tolerance using the
// module default Config.
@[inline]
pub fn assert_approx_eq(actual f64, expected f64, tolerance f64, label string) {
	if !default_cfg.enabled {
		return
	}
	diff := if actual > expected { actual - expected } else { expected - actual }
	if diff > tolerance {
		default_cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected ${expected} ± ${tolerance}, got ${actual} (diff ${diff})'
			file:    @FILE
			line:    @LINE
		})
	}
}
