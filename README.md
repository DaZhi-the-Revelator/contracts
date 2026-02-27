# contracts

**Version 1.1.0** · MIT License · by Ouyang Dazhi

A contract programming module for V. It provides **preconditions**, **postconditions**, **invariants**, and **assertions** — all routable through a replaceable violation handler, all disableable with a single flag, and all integrated with V's native `!T` error propagation.

Contract programming is a way of making your code's expectations explicit and machine-checkable. Instead of silently doing the wrong thing when given bad input, a function states upfront what it requires and what it guarantees. When those rules are broken, you get an immediate, precise error message pointing to the exact cause — rather than a cryptic crash somewhere downstream.

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Reducing Boilerplate — Project-Level Aliases](#reducing-boilerplate--project-level-aliases)
- [API Reference](#api-reference)
  - [Config](#config)
  - [disabled](#disabled)
  - [panic_handler](#panic_handler)
  - [ViolationInfo.str](#violationinfostr)
  - [ViolationError](#violationerror)
  - [require](#require)
  - [ensure](#ensure)
  - [ensure_result](#ensure_result)
  - [invariant_check](#invariant_check)
  - [assert_that](#assert_that)
  - [assert_eq](#assert_eq)
  - [assert_ne](#assert_ne)
  - [assert_lt](#assert_lt)
  - [assert_gt](#assert_gt)
  - [assert_in_range](#assert_in_range)
  - [assert_approx_eq](#assert_approx_eq)
  - [require_not_none](#require_not_none)
  - [checked](#checked)
  - [Invariant](#invariant)
  - [ContractedFn](#contractedfn)
- [Design Notes](#design-notes)
- [Running the Tests](#running-the-tests)
- [Changelog](#changelog)

---

## Installation

Copy the `contracts/` folder into your project or into `~/.vmodules/contracts/`, then import:

```v
import contracts
```

---

## Quick Start

Every function takes a `&Config` as its first argument. Create one `Config` constant per file or module and pass it everywhere. No globals, no shared mutable state.

```v
import contracts

// One constant per file — shared by all functions in this file.
const cfg = contracts.Config{}

fn divide(a f64, b f64) f64 {
    contracts.require(&cfg, b != 0.0, 'divisor must not be zero', @FILE, @LINE)
    result := a / b
    contracts.ensure(&cfg, result != math.inf(1), 'result must be finite', @FILE, @LINE)
    return result
}

fn main() {
    println(divide(10.0, 2.0))  // 5.0
    divide(10.0, 0.0)           // panic: Precondition (require) violated [main.v:5]: divisor must not be zero
}
```

> **Why `@FILE` and `@LINE`?**
> These are V compile-time identifiers evaluated at the exact line you write them. Every violation message therefore points to your call site, not somewhere inside the module. See [Reducing Boilerplate](#reducing-boilerplate--project-level-aliases) for how to avoid typing them repeatedly.

---

## Reducing Boilerplate — Project-Level Aliases

Every call ends with `, @FILE, @LINE`. That is intentional — it guarantees accurate violation locations — but it adds visual noise. The cleanest solution is a single wrapper file in your project that fixes the `cfg` and injects `@FILE`/`@LINE` automatically:

```v
// file: myproject/c.v
module main  // use your own module name

import contracts

const contracts_cfg = contracts.Config{}

@[inline] fn require(cond bool, msg string) {
    contracts.require(&contracts_cfg, cond, msg, @FILE, @LINE)
}
@[inline] fn ensure(cond bool, msg string) {
    contracts.ensure(&contracts_cfg, cond, msg, @FILE, @LINE)
}
@[inline] fn invariant_check(cond bool, msg string) {
    contracts.invariant_check(&contracts_cfg, cond, msg, @FILE, @LINE)
}
@[inline] fn assert_that(cond bool, msg string) {
    contracts.assert_that(&contracts_cfg, cond, msg, @FILE, @LINE)
}
@[inline] fn assert_eq[T](actual T, expected T, label string) {
    contracts.assert_eq(&contracts_cfg, actual, expected, label, @FILE, @LINE)
}
@[inline] fn assert_approx_eq(actual f64, expected f64, tolerance f64, label string) {
    contracts.assert_approx_eq(&contracts_cfg, actual, expected, tolerance, label, @FILE, @LINE)
}
@[inline] fn assert_lt[T](actual T, limit T, label string) {
    contracts.assert_lt(&contracts_cfg, actual, limit, label, @FILE, @LINE)
}
@[inline] fn assert_gt[T](actual T, floor T, label string) {
    contracts.assert_gt(&contracts_cfg, actual, floor, label, @FILE, @LINE)
}
@[inline] fn assert_in_range[T](actual T, lo T, hi T, label string) {
    contracts.assert_in_range(&contracts_cfg, actual, lo, hi, label, @FILE, @LINE)
}
```

Your call sites then become clean and natural:

```v
require(b != 0.0, 'divisor must not be zero')
assert_in_range(hour, 0, 23, 'hour')
assert_approx_eq(result, 3.14159, 0.0001, 'pi')
```

Because `@FILE` and `@LINE` are evaluated in each wrapper at compile time, violation messages still point to your call sites — not the wrapper file.

---

## API Reference

---

### `Config`

```v
pub struct Config {
pub:
    enabled bool               = true
    handler ViolationHandlerFn = panic_handler
}
```

Holds the runtime settings for a set of contract checks. Create one instance per file, module, or test scope and pass it (as `&cfg`) to every contract function. There is no global state — all behaviour is controlled through this struct.

`enabled` — when `false`, every check that receives this Config is a no-op. Set to `false` for production or release builds.

`handler` — called whenever a check fails. Defaults to `panic_handler`. Replace with any `fn (ViolationInfo)` function to log, collect, or otherwise handle violations.

```v
// Standard config — enabled, panics on violation.
const cfg = contracts.Config{}

// Custom handler — logs instead of panicking.
const cfg = contracts.Config{
    handler: fn (info contracts.ViolationInfo) {
        eprintln(info.str())
    }
}

// Wire enabled to a compile-time flag: v -d prod myapp.v
const cfg = contracts.Config{ enabled: $if !prod { true } else { false } }
```

---

### `disabled`

```v
pub fn disabled() Config
```

Returns a `Config` with all checks turned off. Use this for production or release builds instead of writing `Config{ enabled: false }` at every call site.

```v
// Development build: full checking.
const cfg = contracts.Config{}

// Production build: all checks skipped.
const cfg = contracts.disabled()
```

---

### `panic_handler`

```v
pub fn panic_handler(info ViolationInfo)
```

The built-in violation handler. Panics with a formatted message containing the violation kind, source file, line number, and message. This is the default value of `Config.handler` and can be assigned explicitly to restore default behaviour after substituting a custom handler.

---

### `ViolationInfo.str`

```v
pub fn (info ViolationInfo) str() string
```

Returns the same formatted string that `panic_handler` would produce. Implementing `str()` makes `ViolationInfo` usable directly in string interpolation and `eprintln` calls inside custom handlers — no manual formatting needed. The output is identical to `ViolationError.msg()`.

```v
// Simple example — use str() in a custom logging handler.
const cfg = contracts.Config{
    handler: fn (info contracts.ViolationInfo) {
        eprintln('[VIOLATION] ${info.str()}')
    }
}
```

```v
// Advanced example — store formatted messages in a log alongside raw info.
struct AuditLog {
mut:
    entries []string
    raw     []contracts.ViolationInfo
}

fn (mut log AuditLog) handler(info contracts.ViolationInfo) {
    log.entries << info.str()
    log.raw     << info
}

mut audit := AuditLog{}
const cfg = contracts.Config{
    handler: fn [mut audit] (info contracts.ViolationInfo) {
        audit.handler(info)
    }
}
```

---

### `ViolationError`

```v
pub struct ViolationError {
pub:
    info ViolationInfo
}

pub fn (e ViolationError) msg() string
pub fn (e ViolationError) code() int
```

An error type wrapping a contract violation. Allows functions to return `!T` and participate in V's `or {}` / `!` error propagation instead of always panicking. Use when you want violations to be recoverable rather than fatal. `msg()` produces the same formatted string as `ViolationInfo.str()`.

**Simple example**

```v
fn safe_divide(a f64, b f64) !f64 {
    if b == 0.0 {
        return contracts.ViolationError{
            info: contracts.ViolationInfo{
                kind:    .precondition
                message: 'divisor must not be zero'
                file:    @FILE
                line:    @LINE
            }
        }
    }
    return a / b
}

result := safe_divide(10.0, 0.0) or {
    eprintln('caught: ${err}')
    0.0
}
println(result)  // 0.0
```

**Advanced example**

```v
fn validated_sqrt(x f64) !f64 {
    if x < 0.0 {
        return contracts.ViolationError{
            info: contracts.ViolationInfo{
                kind: .precondition, message: 'x must be non-negative', file: @FILE, line: @LINE
            }
        }
    }
    return math.sqrt(x)
}

fn process(values []f64) ![]f64 {
    mut out := []f64{}
    for v in values {
        out << validated_sqrt(v)!
    }
    return out
}

results := process([4.0, 9.0, 16.0]) or { panic(err) }
println(results)  // [2.0, 3.0, 4.0]
```

---

### `require`

```v
pub fn require(cfg &Config, condition bool, message string, file string, line string)
```

Checks a **precondition** — something the *caller* must ensure is true before calling a function. Violations here mean the caller passed bad arguments or called the function at the wrong time.

**Simple example**

```v
const cfg = contracts.Config{}

fn enter_ride(height_cm int) {
    contracts.require(&cfg, height_cm >= 120, 'you must be at least 120 cm tall', @FILE, @LINE)
    println('Enjoy the ride!')
}

enter_ride(135)  // Enjoy the ride!
enter_ride(110)  // panic: Precondition (require) violated … you must be at least 120 cm tall
```

**Advanced example**

```v
fn binary_search(items []int, target int, lo int, hi int) int {
    contracts.require(&cfg, items.len > 0,  'items must not be empty',   @FILE, @LINE)
    contracts.require(&cfg, lo >= 0,        'lo must be >= 0',            @FILE, @LINE)
    contracts.require(&cfg, hi < items.len, 'hi must be < items.len',     @FILE, @LINE)
    contracts.require(&cfg, lo <= hi,       'lo must be <= hi',            @FILE, @LINE)
    // ... search logic ...
    return -1
}
```

---

### `ensure`

```v
pub fn ensure(cfg &Config, condition bool, message string, file string, line string)
```

Checks a **postcondition** — something the *function* promises will be true when it returns. Violations here mean there is a bug in the function itself, not in its caller.

**Simple example**

```v
fn my_abs(x int) int {
    result := if x < 0 { -x } else { x }
    contracts.ensure(&cfg, result >= 0, 'abs result must be non-negative', @FILE, @LINE)
    return result
}
```

**Advanced example**

```v
fn safe_sort(items []int) []int {
    mut result := items.clone()
    result.sort()
    contracts.ensure(&cfg, result.len == items.len,
        'sorted length must match input', @FILE, @LINE)
    for i in 1 .. result.len {
        contracts.ensure(&cfg, result[i - 1] <= result[i],
            'output must be non-decreasing at index ${i}', @FILE, @LINE)
    }
    return result
}
```

---

### `ensure_result`

```v
pub fn ensure_result[T](cfg &Config, value T, condition bool, message string, file string, line string) T
```

Checks a postcondition that involves the return value and passes the value through unchanged. Lets you write the check inline on the `return` statement.

**Simple example**

```v
fn calculate_score(correct int, total int) int {
    raw := (correct * 100) / total
    return contracts.ensure_result(&cfg, raw, raw >= 0 && raw <= 100,
        'score must be 0–100', @FILE, @LINE)
}
```

**Advanced example**

```v
fn clamp(value f64, lo f64, hi f64) f64 {
    contracts.require(&cfg, lo <= hi, 'lo must be <= hi', @FILE, @LINE)
    raw := if value < lo { lo } else if value > hi { hi } else { value }
    return contracts.ensure_result(&cfg, raw, raw >= lo && raw <= hi,
        'clamp result must be within [lo, hi]', @FILE, @LINE)
}
```

---

### `invariant_check`

```v
pub fn invariant_check(cfg &Config, condition bool, message string, file string, line string)
```

Checks that an object or data structure is in a **consistent internal state**. Call at the start and end of any method that mutates a struct to catch corruption immediately at the point it occurs.

**Simple example**

```v
struct ScoreTracker { mut: score int; max int }

fn (mut s ScoreTracker) add_points(n int) {
    contracts.invariant_check(&cfg, s.score >= 0 && s.score <= s.max,
        'score must be within [0, max] before add', @FILE, @LINE)
    s.score += n
    contracts.invariant_check(&cfg, s.score >= 0 && s.score <= s.max,
        'score must be within [0, max] after add', @FILE, @LINE)
}
```

**Advanced example**

```v
struct LinkedList { mut: head ?&Node; count int }

fn (l &LinkedList) actual_count() int {
    mut n := 0
    mut cur := l.head
    for cur != none { n++; cur = cur?.next }
    return n
}

fn (mut l LinkedList) check_state() {
    contracts.invariant_check(&cfg, l.count == l.actual_count(),
        'count must match actual node count', @FILE, @LINE)
    contracts.invariant_check(&cfg, l.count >= 0,
        'count must be non-negative', @FILE, @LINE)
}
```

---

### `assert_that`

```v
pub fn assert_that(cfg &Config, condition bool, message string, file string, line string)
```

A general-purpose assertion with a descriptive message. Unlike V's built-in `assert`, failures go through `cfg.handler` instead of always panicking.

**Simple example**

```v
fn load_config(path string) []string {
    lines := ['entry1', 'entry2']
    contracts.assert_that(&cfg, lines.len > 0, 'config file must not be empty', @FILE, @LINE)
    return lines
}
```

**Advanced example**

```v
fn merge_maps(a map[string]int, b map[string]int) map[string]int {
    mut result := a.clone()
    for k, v in b { result[k] = v }
    contracts.assert_that(&cfg, result.len >= a.len,
        'merged map must be at least as large as the first input', @FILE, @LINE)
    for k in b.keys() {
        contracts.assert_that(&cfg, k in result,
            'key "${k}" from second map must exist in result', @FILE, @LINE)
    }
    return result
}
```

---

### `assert_eq`

```v
pub fn assert_eq[T](cfg &Config, actual T, expected T, label string, file string, line string)
```

Asserts that two values are equal with an auto-formatted `"expected X, got Y"` message. For floating-point values, use [`assert_approx_eq`](#assert_approx_eq) instead.

**Simple example**

```v
contracts.assert_eq(&cfg, add(2, 3), 5, 'add(2, 3)', @FILE, @LINE)  // passes
contracts.assert_eq(&cfg, add(2, 3), 9, 'add(2, 3)', @FILE, @LINE)
// panic: Assertion failed … add(2, 3): expected 9, got 5
```

**Advanced example**

```v
fn test_round_trip(input string) {
    result := decode(encode(input))
    contracts.assert_eq(&cfg, result, input, 'round-trip of "${input}"', @FILE, @LINE)
}
```

---

### `assert_ne`

```v
pub fn assert_ne[T](cfg &Config, actual T, unexpected T, label string, file string, line string)
```

Asserts that two values are **not** equal with an auto-formatted message.

**Simple example**

```v
idx := names.index('Bob')
contracts.assert_ne(&cfg, idx, -1, 'index of Bob', @FILE, @LINE)
println(names[idx])  // Bob
```

**Advanced example**

```v
fn apply_discount(price f64, pct f64) f64 {
    contracts.require(&cfg, pct > 0.0 && pct < 1.0,
        'discount must be between 0 and 1', @FILE, @LINE)
    result := price * (1.0 - pct)
    contracts.assert_ne(&cfg, result, price, 'discounted price', @FILE, @LINE)
    return result
}
```

---

### `assert_lt`

```v
pub fn assert_lt[T](cfg &Config, actual T, limit T, label string, file string, line string)
```

Asserts that `actual` is strictly less than `limit` with an auto-formatted message.

**Simple example**

```v
fn get_item(items []string, index int) string {
    contracts.assert_lt(&cfg, index, items.len, 'index', @FILE, @LINE)
    return items[index]
}
```

**Advanced example**

```v
fn fetch_page(total_pages int, requested int) {
    contracts.assert_gt(&cfg, total_pages, 0, 'total_pages', @FILE, @LINE)
    contracts.assert_lt(&cfg, requested, total_pages, 'requested page', @FILE, @LINE)
    contracts.assert_gt(&cfg, requested, -1, 'requested page', @FILE, @LINE)
}
```

---

### `assert_gt`

```v
pub fn assert_gt[T](cfg &Config, actual T, floor T, label string, file string, line string)
```

Asserts that `actual` is strictly greater than `floor` with an auto-formatted message.

**Simple example**

```v
fn first(items []int) int {
    contracts.assert_gt(&cfg, items.len, 0, 'items.len', @FILE, @LINE)
    return items[0]
}
```

**Advanced example**

```v
struct Product { name string; price f64; stock int }

fn validate_product(p Product) {
    contracts.assert_that(&cfg, p.name.len > 0, 'product name must not be empty', @FILE, @LINE)
    contracts.assert_gt(&cfg, p.price, 0.0,     'price',                           @FILE, @LINE)
    contracts.assert_gt(&cfg, p.stock, -1,       'stock',                           @FILE, @LINE)
}
```

---

### `assert_in_range`

```v
pub fn assert_in_range[T](cfg &Config, actual T, lo T, hi T, label string, file string, line string)
```

Asserts that `actual` is within the inclusive range `[lo, hi]` with an auto-formatted message.

**Simple example**

```v
fn set_volume(pct int) {
    contracts.assert_in_range(&cfg, pct, 0, 100, 'volume percent', @FILE, @LINE)
    println('Volume set to ${pct}%')
}
```

**Advanced example**

```v
struct SimConfig { timestep f64; gravity f64; max_particles int }

fn validate_config(c SimConfig) {
    contracts.assert_in_range(&cfg, c.timestep,      0.001, 1.0,    'timestep',      @FILE, @LINE)
    contracts.assert_in_range(&cfg, c.gravity,       0.0,   20.0,   'gravity',       @FILE, @LINE)
    contracts.assert_in_range(&cfg, c.max_particles, 1,     100000, 'max_particles', @FILE, @LINE)
}
```

---

### `assert_approx_eq`

```v
pub fn assert_approx_eq(cfg &Config, actual f64, expected f64, tolerance f64, label string, file string, line string)
```

Asserts that two `f64` values are within `tolerance` of each other, with an auto-formatted message that includes the actual difference. Use this instead of `assert_eq` for floating-point values — exact `f64` equality is almost always wrong due to rounding.

**Simple example**

```v
import math

fn circle_area(r f64) f64 {
    return math.pi * r * r
}

contracts.assert_approx_eq(&cfg, circle_area(1.0), 3.14159, 0.0001, 'area of unit circle', @FILE, @LINE)
// passes — diff is within tolerance
```

**Advanced example**

```v
// Verify that a fast inverse square root approximation is close enough.
fn fast_inv_sqrt(x f64) f64 {
    // ... approximation ...
    return 0.0
}

fn test_inv_sqrt(input f64, expected f64) {
    result := fast_inv_sqrt(input)
    contracts.assert_approx_eq(&cfg, result, expected, 0.001,
        'fast_inv_sqrt(${input})', @FILE, @LINE)
}

test_inv_sqrt(4.0, 0.5)   // passes if result is within 0.001 of 0.5
test_inv_sqrt(16.0, 0.25) // passes if result is within 0.001 of 0.25
```

---

### `require_not_none`

```v
pub fn require_not_none[T](cfg &Config, value ?T, message string, file string, line string) T
```

Unwraps an optional value, firing a precondition violation if it is `none`. If the handler does not panic, a zero value of `T` is returned after the violation is reported.

**Simple example**

```v
fn greet(maybe_name ?string) string {
    name := contracts.require_not_none(&cfg, maybe_name,
        'a name must be provided', @FILE, @LINE)
    return 'Hello, ${name}!'
}
```

**Advanced example**

```v
struct User { name string; age int }

fn get_cached_user(cache map[int]User, id int) User {
    entry := cache[id] or { none }
    return contracts.require_not_none(&cfg, entry,
        'user ${id} must be present in cache before this call', @FILE, @LINE)
}
```

---

### `checked`

```v
pub fn checked[T](cfg &Config, condition bool, message string, body fn () T, file string, line string) T
```

Checks a single precondition then runs `body`, returning its result. Use this instead of building a full `ContractedFn` when you only need one guard.

**Simple example**

```v
import math

fn safe_sqrt(x f64) f64 {
    return contracts.checked(&cfg, x >= 0.0, 'x must be non-negative',
        fn [x] () f64 { return math.sqrt(x) }, @FILE, @LINE)
}
```

**Advanced example**

```v
fn parse_if_valid(token string, data string) MyResult {
    return contracts.checked(&cfg, token.len == 32, 'token must be 32 characters',
        fn [data] () MyResult { return expensive_parse(data) }, @FILE, @LINE)
}
```

---

### `Invariant`

```v
pub struct Invariant {
pub:
    cfg &Config = &Config{}
...
}

pub fn (mut i Invariant) check(condition bool, message string)
pub fn (mut i Invariant) validate(file string, line string) bool
pub fn (mut i Invariant) reset()
```

A helper struct for **multi-condition invariant checking**. Accumulates all failures with `check()`, then reports them all at once via `validate()`. Use `reset()` to clear failures and reuse the instance.

**Simple example**

```v
struct Rect { width int; height int }

fn (r &Rect) validate() {
    mut inv := contracts.Invariant{ cfg: &cfg }
    inv.check(r.width > 0,  'width must be positive')
    inv.check(r.height > 0, 'height must be positive')
    inv.validate(@FILE, @LINE)
}
// If both fail, both violations are reported before returning.
```

**Advanced example**

```v
// Store on the struct and reset() each cycle to avoid allocations.
struct BoundedQueue {
mut:
    items    []int
    capacity int
    head_idx int
    inv      contracts.Invariant
}

fn (mut q BoundedQueue) check_invariants() {
    q.inv.cfg = &cfg
    q.inv.reset()
    q.inv.check(q.capacity > 0,            'capacity must be positive')
    q.inv.check(q.items.len <= q.capacity, 'items must not exceed capacity')
    q.inv.check(q.head_idx >= 0,           'head_idx must be >= 0')
    q.inv.check(q.head_idx <= q.items.len, 'head_idx must not exceed items.len')
    q.inv.validate(@FILE, @LINE)
}
```

---

### `ContractedFn`

```v
@[heap]
pub struct ContractedFn[T] {
pub:
    cfg &Config = &Config{}
pub mut:
    preconditions  []string
    postconditions []string
    pre_results    []bool
    post_results   []bool
}

pub fn (mut c ContractedFn[T]) pre(condition bool, message string) &ContractedFn[T]
pub fn (mut c ContractedFn[T]) post(condition bool, message string) &ContractedFn[T]
pub fn (mut c ContractedFn[T]) call(body fn () T, file string, line string) T
```

A builder for attaching multiple pre- and postconditions to a closure. All preconditions are verified before `body` runs; all postconditions after. `pre()` and `post()` return `&ContractedFn[T]` for chaining.

> **Note:** V evaluates arguments eagerly, so expressions passed to `post()` are captured *before* `body()` runs. Use `post()` only for conditions that do not depend on `body()`'s return value. For return-value postconditions, use `ensure_result()` inside the body.

> **Tip:** If you only need one precondition, prefer the simpler [`checked`](#checked) function.

**Simple example**

```v
fn safe_divide(a f64, b f64) f64 {
    mut cf := contracts.ContractedFn[f64]{ cfg: &cfg }
    cf.pre(b != 0.0, 'divisor must not be zero')
    return cf.call(fn [a, b] () f64 { return a / b }, @FILE, @LINE)
}
```

**Advanced example**

```v
fn bounded_divide(a f64, b f64, lo f64, hi f64) f64 {
    mut cf := contracts.ContractedFn[f64]{ cfg: &cfg }
    cf.pre(b != 0.0, 'divisor must not be zero')
    cf.pre(lo < hi,  'lo must be less than hi')
    return cf.call(fn [a, b, lo, hi] () f64 {
        result := a / b
        return contracts.ensure_result(&cfg, result, result >= lo && result <= hi,
            'result must be within [lo, hi]', @FILE, @LINE)
    }, @FILE, @LINE)
}
```

---

## Design Notes

**No global state.** V discourages global variables, and this module has none. All settings live in the `Config` struct you create and own. This makes behaviour explicit, makes tests trivially isolated (each test creates its own `Config`), and makes the module safe to use in concurrent contexts.

**`@FILE` and `@LINE` at every call site.** V's compile-time identifiers are evaluated where you write them, not inside the module. Passing them explicitly means every violation message tells you the exact file and line in *your* code where the broken contract was written. The [project-level alias pattern](#reducing-boilerplate--project-level-aliases) lets you eliminate the repetition while keeping this accuracy.

**`require` vs `ensure` vs `assert_that`.** These are intentionally separate. `require` means the *caller* made a mistake. `ensure` means *this function* made a mistake. `assert_that` is for general logic checks that don't fit either category. Keeping them distinct makes bug attribution immediate.

**`ViolationInfo.str()` and consistent formatting.** `ViolationInfo.str()`, `ViolationError.msg()`, and `panic_handler` all produce the same formatted string. This means any custom handler, error message, or log entry looks identical to a panic message — no divergence between how violations appear in different contexts.

**`assert_approx_eq` for floating point.** Exact `f64` equality via `==` is almost always wrong. `assert_approx_eq` makes the tolerance explicit at the call site, which both documents the expected precision and prevents brittle tests that break on the least significant bit.

**`disabled()` for production builds.** `contracts.disabled()` is more readable and searchable than `Config{ enabled: false }` scattered across files. A project-wide grep for `disabled()` immediately shows every place where contracts are suppressed.

**`ViolationError` for recoverable contracts.** The default handler panics, which is right for most cases — a violated contract is a programming error that should have been caught in development. But for library code or edge-case recovery, `ViolationError` lets violations integrate cleanly with V's `!T` / `or {}` error handling.

**Zero overhead when disabled.** Every check function is `@[inline]` and begins with `if !cfg.enabled { return }`. With `disabled()`, the compiler eliminates all contract code — no string allocation, no condition evaluation, no call overhead.

**`Invariant.reset()` for reuse.** If invariants are checked frequently (e.g., every frame in a game loop), allocating a new `Invariant{}` each call creates unnecessary GC pressure. Store the instance on the struct and call `reset()` at the start of each validation cycle.

**Generic functions infer their type.** `assert_eq`, `assert_ne`, `assert_lt`, `assert_gt`, `assert_in_range`, `ensure_result`, `require_not_none`, and `checked` are all generic over `T`. V's type inference means you never need to write the type parameter explicitly.

---

## Running the Tests

```sh
v test .
```

All tests are in `contracts_test.v`. Each test creates its own collecting `Config` that appends violations to a local slice instead of panicking, so every scenario is safe to test without crashing the test runner. There are no shared globals to reset between tests.

---

## Changelog

### 1.1.0

- `ViolationInfo.str()` — formats a violation the same way `panic_handler` does; makes `ViolationInfo` directly usable in string interpolation and custom handlers without manual formatting. Output is identical to `ViolationError.msg()`.
- `disabled()` — constructor function returning `Config{ enabled: false }`; more readable and searchable than inline struct literals at every production call site.
- `assert_approx_eq` — floating-point equality assertion with an explicit tolerance; reports the actual difference on failure. Use instead of `assert_eq` for any `f64` value.

### 1.0.0

- Initial release.
- `Config` struct — explicit, global-free settings: `enabled` flag and replaceable `handler`.
- `panic_handler` — built-in handler that panics with full location info; assignable to `Config.handler`.
- `require`, `ensure`, `invariant_check`, `assert_that` — core contract checks.
- `ensure_result[T]` — inline postcondition on return values.
- `require_not_none[T]` — optional unwrap with precondition violation; returns zero value of `T` if handler does not panic.
- `assert_eq[T]`, `assert_ne[T]` — equality/inequality assertions with auto-formatted messages.
- `assert_lt[T]`, `assert_gt[T]`, `assert_in_range[T]` — comparison and range assertions.
- `checked[T]` — single-precondition shorthand for wrapping a closure.
- `ViolationError` — `IError`-compatible wrapper for recoverable contract violations.
- `Invariant` struct with `check`, `validate`, `reset` — multi-condition fluent invariant checking.
- `ContractedFn[T]` builder with `pre`, `post`, `call` — multi-condition pre/postcondition builder.
- Full test suite in `contracts_test.v`.
