module contracts

// ViolationKind identifies which type of contract was violated.
// Used in `ViolationInfo` passed to the registered violation handler.
pub enum ViolationKind {
	precondition   // A `require()` check failed — the caller did not meet its obligations.
	postcondition  // An `ensure()` check failed — the function did not meet its guarantees.
	invariant_fail // An `invariant_check()` or `Invariant.validate()` failed — object state is inconsistent.
	assertion      // An `assert_that()` check failed — a general logic error was detected.
}

// ViolationInfo holds all contextual information about a contract violation.
// It is passed to the active handler in `Config` whenever a check fails.
pub struct ViolationInfo {
pub:
	kind    ViolationKind // The category of the violated contract.
	message string        // The human-readable description provided at the call site.
	file    string        // The source file where the violation occurred (from `@FILE`).
	line    string        // The source line where the violation occurred (from `@LINE`).
}

// ViolationHandlerFn is the signature for a custom violation handler.
// Assign a value of this type to `Config.handler` to override the default
// panic behaviour — e.g. to log violations or collect them for testing.
pub type ViolationHandlerFn = fn (ViolationInfo)

// panic_handler is the built-in handler. It panics with a formatted message
// containing the violation kind, file, line, and message.
// It is the default value of `Config.handler` and can be restored after
// substituting a custom handler.
pub fn panic_handler(info ViolationInfo) {
	kind_str := match info.kind {
		.precondition   { 'Precondition (require) violated' }
		.postcondition  { 'Postcondition (ensure) violated' }
		.invariant_fail { 'Invariant violated' }
		.assertion      { 'Assertion failed' }
	}
	panic('${kind_str} [${info.file}:${info.line}]: ${info.message}')
}

// disabled returns a `Config` with all checks turned off.
// Use this for production or release builds instead of writing
// `Config{ enabled: false }` at every call site.
//
// Example:
//   const cfg = contracts.disabled()
pub fn disabled() Config {
	return Config{ enabled: false }
}

// Config holds the runtime settings for a set of contract checks.
// Create one instance per module, subsystem, or test scope and pass it to
// every contract function. This keeps all state explicit and avoids globals.
//
// Example — typical setup at the top of a file:
//   const cfg = contracts.Config{}
//
// Example — disabled for a production build:
//   const cfg = contracts.disabled()
//
// Example — custom handler that logs instead of panicking:
//   const cfg = contracts.Config{
//       handler: fn (info contracts.ViolationInfo) {
//           eprintln('[contract] ${info.message}')
//       }
//   }
pub struct Config {
pub:
	// enabled controls whether all checks on this Config are executed.
	// Set to `false` to make every check a no-op — useful for production or
	// release builds once correctness has been validated during development.
	enabled bool = true
	// handler is called whenever a contract check fails.
	// Defaults to `panic_handler`, which panics with a formatted message.
	// Replace with any function matching `ViolationHandlerFn`.
	handler ViolationHandlerFn = panic_handler
}

// ViolationError is an error type that wraps a contract violation, allowing
// contract-checked functions to return `!T` and participate in V's standard
// `or {}` / `!` error propagation instead of always panicking.
//
// Example:
//   fn safe_divide(cfg &contracts.Config, a f64, b f64) !f64 {
//       if b == 0.0 {
//           return contracts.ViolationError{
//               info: contracts.ViolationInfo{
//                   kind:    .precondition
//                   message: 'divisor must not be zero'
//                   file:    @FILE
//                   line:    @LINE
//               }
//           }
//       }
//       return a / b
//   }
//
//   result := safe_divide(cfg, 10.0, 0.0) or { eprintln(err) ; 0.0 }
pub struct ViolationError {
pub:
	info ViolationInfo // The full violation detail that caused this error.
}

// msg returns a formatted error string describing the violation.
// Implements the `IError` interface so `ViolationError` works with `or {}` and `!`.
pub fn (e ViolationError) msg() string {
	kind_str := match e.info.kind {
		.precondition   { 'Precondition (require) violated' }
		.postcondition  { 'Postcondition (ensure) violated' }
		.invariant_fail { 'Invariant violated' }
		.assertion      { 'Assertion failed' }
	}
	return '${kind_str} [${e.info.file}:${e.info.line}]: ${e.info.message}'
}

// code returns 0. Required by the `IError` interface.
pub fn (e ViolationError) code() int {
	return 0
}

// str returns the same formatted string as `panic_handler` would produce,
// making `ViolationInfo` useful directly in string interpolation and `eprintln`
// calls inside custom handlers without manual formatting.
//
// Example:
//   contracts.handler = fn (info contracts.ViolationInfo) {
//       eprintln(info.str())
//   }
pub fn (info ViolationInfo) str() string {
	kind_str := match info.kind {
		.precondition   { 'Precondition (require) violated' }
		.postcondition  { 'Postcondition (ensure) violated' }
		.invariant_fail { 'Invariant violated' }
		.assertion      { 'Assertion failed' }
	}
	return '${kind_str} [${info.file}:${info.line}]: ${info.message}'
}

// require checks a precondition — a condition the *caller* must satisfy before
// a function begins executing. Use this to document and enforce the assumptions
// your function makes about its inputs.
// Pass `@FILE` and `@LINE` at the call site so violation messages point to the
// exact source location.
//
// Example:
//   fn divide(cfg &contracts.Config, a f64, b f64) f64 {
//       contracts.require(cfg, b != 0.0, 'divisor must not be zero', @FILE, @LINE)
//       return a / b
//   }
@[inline]
pub fn require(cfg &Config, condition bool, message string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if !condition {
		cfg.handler(ViolationInfo{
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
//   fn abs(cfg &contracts.Config, x f64) f64 {
//       result := if x < 0 { -x } else { x }
//       contracts.ensure(cfg, result >= 0.0, 'result must be non-negative', @FILE, @LINE)
//       return result
//   }
@[inline]
pub fn ensure(cfg &Config, condition bool, message string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if !condition {
		cfg.handler(ViolationInfo{
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
//   fn (mut s Stack) push(cfg &contracts.Config, value int) {
//       contracts.invariant_check(cfg, s.len >= 0, 'len must be non-negative', @FILE, @LINE)
//       s.data << value
//       s.len++
//       contracts.invariant_check(cfg, s.len >= 0, 'len must be non-negative', @FILE, @LINE)
//   }
@[inline]
pub fn invariant_check(cfg &Config, condition bool, message string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if !condition {
		cfg.handler(ViolationInfo{
			kind:    .invariant_fail
			message: message
			file:    file
			line:    line
		})
	}
}

// assert_that is a general-purpose assertion with a descriptive message.
// Unlike V's built-in `assert`, failures are routed through `cfg.handler`,
// enabling custom error reporting instead of always panicking.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_that(cfg, index < arr.len, 'index out of bounds', @FILE, @LINE)
@[inline]
pub fn assert_that(cfg &Config, condition bool, message string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if !condition {
		cfg.handler(ViolationInfo{
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
//   contracts.assert_eq(cfg, result, 42, 'add(40, 2)', @FILE, @LINE)
@[inline]
pub fn assert_eq[T](cfg &Config, actual T, expected T, label string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if actual != expected {
		cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected ${expected}, got ${actual}'
			file:    file
			line:    line
		})
	}
}

// assert_ne asserts that two values are not equal, automatically formatting the
// failure message so call sites stay concise.
// `T` must be a type that supports `==` and string interpolation.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_ne(cfg, index, -1, 'find result', @FILE, @LINE)
@[inline]
pub fn assert_ne[T](cfg &Config, actual T, unexpected T, label string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if actual == unexpected {
		cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value to differ from ${unexpected}, but got ${actual}'
			file:    file
			line:    line
		})
	}
}

// assert_lt asserts that `actual` is strictly less than `limit`, automatically
// formatting the failure message. Useful for bounds checks and loop guards.
// `T` must support `<` and string interpolation.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_lt(cfg, index, items.len, 'index', @FILE, @LINE)
@[inline]
pub fn assert_lt[T](cfg &Config, actual T, limit T, label string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if actual >= limit {
		cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value < ${limit}, got ${actual}'
			file:    file
			line:    line
		})
	}
}

// assert_gt asserts that `actual` is strictly greater than `floor`, automatically
// formatting the failure message. Useful for checking non-zero sizes, positive
// amounts, and minimum thresholds.
// `T` must support `>` and string interpolation.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_gt(cfg, items.len, 0, 'items.len', @FILE, @LINE)
@[inline]
pub fn assert_gt[T](cfg &Config, actual T, floor T, label string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if actual <= floor {
		cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value > ${floor}, got ${actual}'
			file:    file
			line:    line
		})
	}
}

// assert_in_range asserts that `actual` is within the inclusive range [lo, hi],
// automatically formatting the failure message. Avoids writing two separate
// `assert_that` calls for range checks.
// `T` must support `<`, `>`, and string interpolation.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_in_range(cfg, hour, 0, 23, 'hour', @FILE, @LINE)
@[inline]
pub fn assert_in_range[T](cfg &Config, actual T, lo T, hi T, label string, file string, line string) {
	if !cfg.enabled {
		return
	}
	if actual < lo || actual > hi {
		cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected value in [${lo}, ${hi}], got ${actual}'
			file:    file
			line:    line
		})
	}
}

// assert_approx_eq asserts that two floating-point values are within `tolerance`
// of each other, automatically formatting the failure message. Use this instead
// of `assert_eq` for `f32` or `f64` values, where exact equality is rarely
// correct due to floating-point rounding.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   contracts.assert_approx_eq(cfg, result, 3.14159, 0.0001, 'pi approximation', @FILE, @LINE)
@[inline]
pub fn assert_approx_eq(cfg &Config, actual f64, expected f64, tolerance f64, label string, file string, line string) {
	if !cfg.enabled {
		return
	}
	diff := if actual > expected { actual - expected } else { expected - actual }
	if diff > tolerance {
		cfg.handler(ViolationInfo{
			kind:    .assertion
			message: '${label}: expected ${expected} ± ${tolerance}, got ${actual} (diff ${diff})'
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
//   fn clamp(cfg &contracts.Config, x f64, lo f64, hi f64) f64 {
//       result := if x < lo { lo } else if x > hi { hi } else { x }
//       return contracts.ensure_result(cfg, result, result >= lo && result <= hi,
//           'result must be within [lo, hi]', @FILE, @LINE)
//   }
@[inline]
pub fn ensure_result[T](cfg &Config, value T, condition bool, message string, file string, line string) T {
	ensure(cfg, condition, message, file, line)
	return value
}

// require_not_none unwraps an optional value, firing a precondition violation if
// it is `none`. This removes the boilerplate of a separate `require` + unwrap pair
// when a function receives an optional that must be present.
// If the handler does not panic, a zero value of `T` is returned after the
// violation is reported.
// Pass `@FILE` and `@LINE` for accurate source location in violation messages.
//
// Example:
//   fn process(cfg &contracts.Config, maybe_name ?string) string {
//       name := contracts.require_not_none(cfg, maybe_name, 'name must be provided', @FILE, @LINE)
//       return name.to_upper()
//   }
@[inline]
pub fn require_not_none[T](cfg &Config, value ?T, message string, file string, line string) T {
	if !cfg.enabled {
		return value or { panic(message) }
	}
	return value or {
		cfg.handler(ViolationInfo{
			kind:    .precondition
			message: message
			file:    file
			line:    line
		})
		unsafe { T{} }
	}
}

// checked is a concise one-call shorthand for the most common ContractedFn
// pattern: one precondition plus a body. Avoids building a ContractedFn
// struct when you only need a single guard.
// Pass `@FILE` and `@LINE` so violation messages reference the call site.
//
// Example:
//   result := contracts.checked(cfg, x >= 0.0, 'x must be non-negative',
//       fn [x] () f64 { return math.sqrt(x) }, @FILE, @LINE)
@[inline]
pub fn checked[T](cfg &Config, condition bool, message string, body fn () T, file string, line string) T {
	require(cfg, condition, message, file, line)
	return body()
}

// Invariant is a helper struct for fluent, multi-condition invariant checking.
// Accumulate conditions with `check()`, then fire all failures at once with
// `validate()`. This avoids stopping at the first failing condition and gives
// a complete picture of a broken object state.
// Call `reset()` to clear accumulated failures and reuse the same instance.
//
// Example:
//   fn (s &Stack) check_invariants(cfg &contracts.Config) {
//       mut inv := contracts.Invariant{ cfg: cfg }
//       inv.check(s.len >= 0,          'len must be >= 0')
//       inv.check(s.cap >= s.len,      'cap must be >= len')
//       inv.check(s.data.len == s.len, 'data length must equal len')
//       inv.validate(@FILE, @LINE)
//   }
pub struct Invariant {
pub:
	cfg &Config = &Config{} // The Config whose handler and enabled flag govern these checks.
mut:
	failures []string
}

// check records a single invariant condition for deferred evaluation.
// If `condition` is false, `message` is accumulated for reporting by `validate()`.
// Has no effect when `cfg.enabled` is `false`.
pub fn (mut i Invariant) check(condition bool, message string) {
	if !i.cfg.enabled {
		return
	}
	if !condition {
		i.failures << message
	}
}

// validate fires `cfg.handler` once per accumulated failure.
// Returns `true` if all invariants passed, `false` if any failed.
// Has no effect and returns `true` when `cfg.enabled` is `false`.
pub fn (mut i Invariant) validate(file string, line string) bool {
	if !i.cfg.enabled {
		return true
	}
	if i.failures.len == 0 {
		return true
	}
	for msg in i.failures {
		i.cfg.handler(ViolationInfo{
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
// Has no effect when `cfg.enabled` is `false`.
pub fn (mut i Invariant) reset() {
	if !i.cfg.enabled {
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
//   mut cf := contracts.ContractedFn[f64]{ cfg: cfg }
//   cf.pre(b != 0.0, 'divisor must not be zero')
//   result := cf.call(fn () f64 { return a / b }, @FILE, @LINE)
@[heap]
pub struct ContractedFn[T] {
pub:
	cfg &Config = &Config{} // The Config whose handler and enabled flag govern these checks.
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
pub fn (mut c ContractedFn[T]) call(body fn () T, file string, line string) T {
	for idx, ok in c.pre_results {
		require(c.cfg, ok, c.preconditions[idx], file, line)
	}

	result := body()

	for idx, ok in c.post_results {
		ensure(c.cfg, ok, c.postconditions[idx], file, line)
	}

	return result
}
