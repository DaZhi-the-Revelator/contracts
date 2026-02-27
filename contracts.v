module contracts

// enabled controls whether all contract checks are executed.
// Set to `false` to skip all checks at runtime, which is useful for production
// or release builds where performance is critical and contracts have already
// been validated during development and testing.
// This is a global flag and affects `require`, `ensure`, `invariant_check`,
// `assert_that`, and all helper types.
pub __global enabled = true

// ViolationKind identifies which type of contract was violated.
// Used in `ViolationInfo` passed to the registered violation handler.
pub enum ViolationKind {
	precondition   // A `require()` check failed — the caller did not meet its obligations.
	postcondition  // An `ensure()` check failed — the function did not meet its guarantees.
	invariant_fail // An `invariant_check()` or `Invariant.validate()` failed — object state is inconsistent.
	assertion      // An `assert_that()` check failed — a general logic error was detected.
}

// ViolationInfo holds all contextual information about a contract violation.
// It is passed to the active `ViolationHandlerFn` whenever a check fails.
pub struct ViolationInfo {
pub:
	kind    ViolationKind // The category of the violated contract.
	message string        // The human-readable description provided at the call site.
	file    string        // The source file where the violation occurred (from `@FILE`).
	line    int           // The source line where the violation occurred (from `@LINE`).
}

// ViolationHandlerFn is the signature for a custom violation handler.
// Replace `contracts.handler` with your own function of this type to override
// the default panic behaviour — e.g. to log violations or collect them for testing.
pub type ViolationHandlerFn = fn (ViolationInfo)

fn default_handler(info ViolationInfo) {
	kind_str := match info.kind {
		.precondition   { 'Precondition (require) violated' }
		.postcondition  { 'Postcondition (ensure) violated' }
		.invariant_fail { 'Invariant violated' }
		.assertion      { 'Assertion failed' }
	}
	panic('${kind_str} [${info.file}:${info.line}]: ${info.message}')
}

// handler is the active violation handler called whenever any contract check fails.
// Defaults to a panic with a formatted message. Reassign to customise behaviour:
//
//   contracts.handler = fn (info contracts.ViolationInfo) {
//       eprintln('CONTRACT VIOLATION: ${info.message}')
//   }
pub __global handler ViolationHandlerFn = default_handler

// require checks a precondition — a condition the *caller* must satisfy before
// a function begins executing. Use this to document and enforce the assumptions
// your function makes about its inputs.
// Pass `@FILE` and `@LINE` at the call site so violation messages point to the
// exact source location.
//
// Example:
//   fn divide(a f64, b f64) f64 {
//       contracts.require(b != 0.0, 'divisor must not be zero', @FILE, @LINE)
//       return a / b
//   }
@[inline]
pub fn require(condition bool, message string, file string, line int) {
	if !enabled {
		return
	}
	if !condition {
		handler(ViolationInfo{
			kind:    .precondition
			message: message
			file:    file
			line:    line
		})
	}
}

// ensure checks a postcondition — a guarantee the *function* makes about its
// result or side-effects before returning. Use this to document and enforce
// what your function promises to deliver.
// Pass `@FILE` and `@LINE` at the call site so violation messages point to the
// exact source location.
//
// Example:
//   fn abs(x f64) f64 {
//       result := if x < 0 { -x } else { x }
//       contracts.ensure(result >= 0.0, 'result must be non-negative', @FILE, @LINE)
//       return result
//   }
@[inline]
pub fn ensure(condition bool, message string, file string, line int) {
	if !enabled {
		return
	}
	if !condition {
		handler(ViolationInfo{
			kind:    .postcondition
			message: message
			file:    file
			line:    line
		})
	}
}

// invariant_check verifies that an object or data structure is in a consistent
// state. Typically called at the start and end of mutating methods to catch
// accidental corruption of internal state early.
// Pass `@FILE` and `@LINE` at the call site so violation messages point to the
// exact source location.
//
// Example:
//   fn (mut s Stack) push(value int) {
//       contracts.invariant_check(s.len >= 0, 'len must be non-negative', @FILE, @LINE)
//       s.data << value
//       s.len++
//       contracts.invariant_check(s.len >= 0, 'len must be non-negative', @FILE, @LINE)
//   }
@[inline]
pub fn invariant_check(condition bool, message string, file string, line int) {
	if !enabled {
		return
	}
	if !condition {
		handler(ViolationInfo{
			kind:    .invariant_fail
			message: message
			file:    file
			line:    line
		})
	}
}

// assert_that is a general-purpose assertion with a descriptive message.
// Unlike V's built-in `assert`, failures are routed through the active
// `contracts.handler`, enabling custom error reporting instead of always panicking.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_that(index < arr.len, 'index out of bounds', @FILE, @LINE)
@[inline]
pub fn assert_that(condition bool, message string, file string, line int) {
	if !enabled {
		return
	}
	if !condition {
		handler(ViolationInfo{
			kind:    .assertion
			message: message
			file:    file
			line:    line
		})
	}
}

// assert_eq asserts that two values are equal, automatically formatting the
// "expected X, got Y" message so call sites stay concise.
// `T` must be a type that supports `==` and string interpolation.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_eq(result, 42, 'add(40, 2)', @FILE, @LINE)
@[inline]
pub fn assert_eq[T](actual T, expected T, label string, file string, line int) {
	if !enabled {
		return
	}
	if actual != expected {
		handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected ${expected}, got ${actual}'
			file:    file
			line:    line
		})
	}
}

// assert_ne asserts that two values are not equal, automatically formatting the
// "expected X != Y but they were equal" message so call sites stay concise.
// `T` must be a type that supports `==` and string interpolation.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_ne(index, -1, 'find result', @FILE, @LINE)
@[inline]
pub fn assert_ne[T](actual T, unexpected T, label string, file string, line int) {
	if !enabled {
		return
	}
	if actual == unexpected {
		handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value to differ from ${unexpected}, but got ${actual}'
			file:    file
			line:    line
		})
	}
}

// ensure_result checks a postcondition and returns `value` unchanged, allowing
// the check to be inlined directly on a return statement without a temporary variable.
// Use this when the postcondition involves the function's return value.
//
// Example:
//   fn clamp(x f64, lo f64, hi f64) f64 {
//       result := if x < lo { lo } else if x > hi { hi } else { x }
//       return contracts.ensure_result(result, result >= lo && result <= hi,
//           'result must be within [lo, hi]', @FILE, @LINE)
//   }
@[inline]
pub fn ensure_result[T](value T, condition bool, message string, file string, line int) T {
	ensure(condition, message, file, line)
	return value
}

// require_not_none unwraps an optional value, firing a precondition violation if
// it is `none`. This removes the boilerplate of a separate `require` + unwrap pair
// when a function receives an optional that must be present.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   fn process(maybe_name ?string) string {
//       name := contracts.require_not_none(maybe_name, 'name must be provided', @FILE, @LINE)
//       return name.to_upper()
//   }
@[inline]
pub fn require_not_none[T](value ?T, message string, file string, line int) T {
	if !enabled {
		// In release mode we still need to return something; unwrap with or-panic.
		return value or { panic(message) }
	}
	return value or {
		handler(ViolationInfo{
			kind:    .precondition
			message: message
			file:    file
			line:    line
		})
		panic('unreachable: violation handler returned')
	}
}

// Invariant is a helper struct for fluent, multi-condition invariant checking.
// Accumulate conditions with `check()`, then fire all failures at once with
// `validate()`. This avoids stopping at the first failing condition and gives
// a complete picture of a broken object state.
// Call `reset()` to clear accumulated failures and reuse the same instance.
//
// Example:
//   fn (s &Stack) check_invariants(file string, line int) {
//       mut inv := contracts.Invariant{}
//       inv.check(s.len >= 0,          'len must be >= 0')
//       inv.check(s.cap >= s.len,      'cap must be >= len')
//       inv.check(s.data.len == s.len, 'data length must equal len')
//       inv.validate(file, line)
//   }
pub struct Invariant {
mut:
	failures []string
}

// check records a single invariant condition for deferred evaluation.
// If `condition` is false, `message` is accumulated for reporting by `validate()`.
// Has no effect when `contracts.enabled` is `false`.
pub fn (mut i Invariant) check(condition bool, message string) {
	if !enabled {
		return
	}
	if !condition {
		i.failures << message
	}
}

// validate fires the active violation handler once per accumulated failure.
// Returns `true` if all invariants passed, `false` if any failed.
// Has no effect and returns `true` when `contracts.enabled` is `false`.
pub fn (mut i Invariant) validate(file string, line int) bool {
	if !enabled {
		return true
	}
	if i.failures.len == 0 {
		return true
	}
	for msg in i.failures {
		handler(ViolationInfo{
			kind:    .invariant_fail
			message: msg
			file:    file
			line:    line
		})
	}
	return false
}

// reset clears all accumulated failures so the Invariant instance can be reused
// for another validation cycle without allocating a new struct.
// Has no effect when `contracts.enabled` is `false`.
pub fn (mut i Invariant) reset() {
	if !enabled {
		return
	}
	i.failures.clear()
}

// ContractedFn is a builder that lets you attach preconditions and postconditions
// to a closure and execute it in one place. All recorded preconditions are checked
// before the body runs; all recorded postconditions are checked after it returns.
// `T` is the return type of the wrapped function.
//
// Example:
//   mut cf := contracts.ContractedFn[f64]{}
//   cf.pre(b != 0.0, 'divisor must not be zero')
//   result := cf.call(fn () f64 { return a / b }, @FILE, @LINE)
pub struct ContractedFn[T] {
pub mut:
	preconditions  []string // Failure messages for each recorded precondition.
	postconditions []string // Failure messages for each recorded postcondition.
	pre_results    []bool   // Evaluated boolean results for each precondition.
	post_results   []bool   // Evaluated boolean results for each postcondition.
}

// pre records a precondition result and its associated failure message.
// Conditions are evaluated by the caller before being passed in, so all
// expressions are captured at the point of the `pre()` call.
// Returns `&ContractedFn[T]` to allow method chaining.
pub fn (mut c ContractedFn[T]) pre(condition bool, message string) &ContractedFn[T] {
	c.pre_results << condition
	c.preconditions << message
	return &c
}

// post records a postcondition result and its associated failure message.
// Must be called before `call()`. Because V evaluates arguments eagerly,
// the condition expression is captured at the point of the `post()` call
// (before the body runs), so only use `post()` for conditions that can be
// expressed independently of `body()`'s return value. For return-value checks,
// prefer `ensure_result()` inside the body instead.
// Returns `&ContractedFn[T]` to allow method chaining.
pub fn (mut c ContractedFn[T]) post(condition bool, message string) &ContractedFn[T] {
	c.post_results << condition
	c.postconditions << message
	return &c
}

// call verifies all recorded preconditions, invokes `body`, then verifies all
// recorded postconditions. Returns the value produced by `body`.
// Pass `@FILE` and `@LINE` so violation messages reference the call site.
pub fn (mut c ContractedFn[T]) call(body fn () T, file string, line int) T {
	for idx, ok in c.pre_results {
		require(ok, c.preconditions[idx], file, line)
	}

	result := body()

	for idx, ok in c.post_results {
		ensure(ok, c.postconditions[idx], file, line)
	}

	return result
}
