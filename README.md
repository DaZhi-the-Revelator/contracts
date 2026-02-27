# contracts

**Version 1.0.0** · MIT License · by Ouyang Dazhi

A contract programming module for V. It provides **preconditions**, **postconditions**, **invariants**, and **assertions** — all routable through a replaceable violation handler, and all disableable with a single flag for production builds.

Contract programming is a way of making your code's expectations explicit and machine-checkable. Instead of silently doing the wrong thing when given bad input, a function states upfront what it requires and what it guarantees. When those rules are broken, you get an immediate, precise error message pointing to the exact cause — rather than a cryptic crash somewhere downstream.

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [enabled](#enabled)
  - [handler](#handler)
  - [require](#require)
  - [ensure](#ensure)
  - [ensure_result](#ensure_result)
  - [invariant_check](#invariant_check)
  - [assert_that](#assert_that)
  - [assert_eq](#assert_eq)
  - [assert_ne](#assert_ne)
  - [require_not_none](#require_not_none)
  - [Invariant](#invariant)
  - [ContractedFn](#contractedfn)
- [Design Notes](#design-notes)
- [Running the Tests](#running-the-tests)

---

## Installation

Copy the `contracts/` folder into your project or into `~/.vmodules/contracts/`, then import:

```v
import contracts
```

---

## Quick Start

```v
import contracts

fn divide(a f64, b f64) f64 {
    contracts.require(b != 0.0, 'divisor must not be zero', @FILE, @LINE)
    result := a / b
    contracts.ensure(!isnan(result), 'result must not be NaN', @FILE, @LINE)
    return result
}

fn main() {
    println(divide(10.0, 2.0))  // 5.0
    divide(10.0, 0.0)           // panic: Precondition (require) violated [main.v:5]: divisor must not be zero
}
```

> **Why `@FILE` and `@LINE`?**
> These are V compile-time identifiers that capture the exact source file and line number where you wrote the call. Every violation message therefore reports *where* the contract was broken, not somewhere deep inside the module.

---

## API Reference

---

### `enabled`

```v
pub __global enabled = true
```

Controls whether all contract checks run. Set to `false` to make every check a no-op — useful for production or release builds once correctness has been validated during development.

```v
// Disable for a release build
contracts.enabled = false

// Or wire to a compile-time flag
contracts.enabled = $if !prod { true } else { false }
```

---

### `handler`

```v
pub __global handler ViolationHandlerFn = default_handler
```

The function called whenever any contract check fails. The default panics with a formatted message. Replace it to log, collect, or otherwise handle violations:

```v
// Simple example — print instead of panic
contracts.handler = fn (info contracts.ViolationInfo) {
    eprintln('Violation: ${info.message}')
}
```

```v
// Advanced example — collect violations for testing or monitoring
struct ViolationLog {
mut:
    entries []contracts.ViolationInfo
}

fn (mut log ViolationLog) install() {
    contracts.handler = fn [mut log] (info contracts.ViolationInfo) {
        log.entries << info
    }
}

mut log := ViolationLog{}
log.install()

contracts.require(false, 'test failure', @FILE, @LINE)
println(log.entries[0].message)  // test failure

contracts.handler = contracts.default_handler  // restore default
```

---

### `require`

```v
pub fn require(condition bool, message string, file string, line int)
```

Checks a **precondition** — something the *caller* must ensure is true before calling a function. If the condition is false, the violation handler fires. Violations here mean the caller passed bad arguments or called the function at the wrong time.

**Simple example**

```v
// You can only enter a ride if you are tall enough.
fn enter_ride(height_cm int) {
    contracts.require(height_cm >= 120, 'you must be at least 120 cm tall', @FILE, @LINE)
    println('Enjoy the ride!')
}

enter_ride(135)  // Enjoy the ride!
enter_ride(110)  // panic: Precondition (require) violated … you must be at least 120 cm tall
```

**Advanced example**

```v
// A binary search requires a sorted, non-empty slice and a valid range.
fn binary_search(items []int, target int, lo int, hi int) int {
    contracts.require(items.len > 0,  'items must not be empty',       @FILE, @LINE)
    contracts.require(lo >= 0,        'lo must be >= 0',                @FILE, @LINE)
    contracts.require(hi < items.len, 'hi must be < items.len',         @FILE, @LINE)
    contracts.require(lo <= hi,       'lo must be <= hi',                @FILE, @LINE)
    // ... search logic ...
    return -1
}
```

---

### `ensure`

```v
pub fn ensure(condition bool, message string, file string, line int)
```

Checks a **postcondition** — something the *function* promises will be true when it returns. If the condition is false, the violation handler fires. Violations here mean there is a bug in the function itself, not in its caller.

**Simple example**

```v
// This function promises it will always return a number >= 0.
fn my_abs(x int) int {
    result := if x < 0 { -x } else { x }
    contracts.ensure(result >= 0, 'abs result must be non-negative', @FILE, @LINE)
    return result
}

println(my_abs(-7))  // 7
println(my_abs(3))   // 3
```

**Advanced example**

```v
// A sort function promises the output has the same length and same elements
// as the input, and that no adjacent pair is out of order.
fn safe_sort(items []int) []int {
    mut result := items.clone()
    result.sort()
    contracts.ensure(result.len == items.len, 'sorted length must match input', @FILE, @LINE)
    for i in 1 .. result.len {
        contracts.ensure(result[i - 1] <= result[i],
            'output must be non-decreasing at index ${i}', @FILE, @LINE)
    }
    return result
}
```

---

### `ensure_result`

```v
pub fn ensure_result[T](value T, condition bool, message string, file string, line int) T
```

Checks a postcondition that involves the return value and passes the value through unchanged. Lets you write the check inline on the `return` statement instead of using a separate variable.

**Simple example**

```v
// Guarantee the score is always between 0 and 100, right on the return line.
fn calculate_score(correct int, total int) int {
    raw := (correct * 100) / total
    return contracts.ensure_result(raw, raw >= 0 && raw <= 100,
        'score must be 0–100', @FILE, @LINE)
}

println(calculate_score(8, 10))  // 80
```

**Advanced example**

```v
// A clamping function guarantees its output is within [lo, hi],
// checked without an extra named variable.
fn clamp(value f64, lo f64, hi f64) f64 {
    contracts.require(lo <= hi, 'lo must be <= hi', @FILE, @LINE)
    raw := if value < lo { lo } else if value > hi { hi } else { value }
    return contracts.ensure_result(raw, raw >= lo && raw <= hi,
        'clamp result must be within [lo, hi]', @FILE, @LINE)
}

println(clamp(150.0, 0.0, 100.0))  // 100.0
println(clamp(-5.0,  0.0, 100.0))  // 0.0
```

---

### `invariant_check`

```v
pub fn invariant_check(condition bool, message string, file string, line int)
```

Checks that an object or data structure is in a **consistent internal state**. Call at the start and end of any method that mutates a struct to catch corruption immediately at the point it occurs.

**Simple example**

```v
// A score tracker must never go below zero or above the maximum.
struct ScoreTracker {
mut:
    score int
    max   int
}

fn (mut s ScoreTracker) add_points(n int) {
    contracts.invariant_check(s.score >= 0 && s.score <= s.max,
        'score must be within [0, max] before add', @FILE, @LINE)
    s.score += n
    contracts.invariant_check(s.score >= 0 && s.score <= s.max,
        'score must be within [0, max] after add', @FILE, @LINE)
}
```

**Advanced example**

```v
// A doubly-linked list checks that its length counter matches the actual
// number of nodes before and after every mutation.
struct LinkedList {
mut:
    head  ?&Node
    tail  ?&Node
    count int
}

fn (l &LinkedList) actual_count() int {
    mut n := 0
    mut cur := l.head
    for cur != none {
        n++
        cur = cur?.next
    }
    return n
}

fn (mut l LinkedList) check_state() {
    contracts.invariant_check(l.count == l.actual_count(),
        'count must match actual node count', @FILE, @LINE)
    contracts.invariant_check(l.count >= 0,
        'count must be non-negative', @FILE, @LINE)
}

fn (mut l LinkedList) append(value int) {
    l.check_state()
    // ... append logic ...
    l.count++
    l.check_state()
}
```

---

### `assert_that`

```v
pub fn assert_that(condition bool, message string, file string, line int)
```

A general-purpose assertion with a descriptive message. Unlike V's built-in `assert`, failures go through the active `contracts.handler` instead of always panicking, and the message is always included in the output. Use anywhere you want to state that something must be true.

**Simple example**

```v
// After loading a config file, make sure we got at least one entry.
fn load_config(path string) []string {
    lines := ['entry1', 'entry2']  // simulated file read
    contracts.assert_that(lines.len > 0, 'config file must not be empty', @FILE, @LINE)
    return lines
}
```

**Advanced example**

```v
// After a merge operation, assert structural consistency of the result.
fn merge_maps(a map[string]int, b map[string]int) map[string]int {
    mut result := a.clone()
    for k, v in b {
        result[k] = v
    }
    contracts.assert_that(result.len >= a.len,
        'merged map must be at least as large as the first input', @FILE, @LINE)
    // Every key from b must now be present.
    for k in b.keys() {
        contracts.assert_that(k in result,
            'key "${k}" from second map must exist in result', @FILE, @LINE)
    }
    return result
}
```

---

### `assert_eq`

```v
pub fn assert_eq[T](actual T, expected T, label string, file string, line int)
```

Asserts that two values are equal and automatically formats an `"expected X, got Y"` message. Removes the boilerplate of manually writing the message for equality checks.

**Simple example**

```v
fn add(a int, b int) int { return a + b }

contracts.assert_eq(add(2, 3), 5, 'add(2, 3)', @FILE, @LINE)
// passes silently

contracts.assert_eq(add(2, 3), 9, 'add(2, 3)', @FILE, @LINE)
// panic: Assertion failed … add(2, 3): expected 9, got 5
```

**Advanced example**

```v
// Verify a transformation round-trips correctly.
fn encode(s string) string { return s.to_upper() }
fn decode(s string) string { return s.to_lower() }

fn test_round_trip(input string) {
    result := decode(encode(input))
    contracts.assert_eq(result, input, 'round-trip of "${input}"', @FILE, @LINE)
}

test_round_trip('hello')  // passes
```

---

### `assert_ne`

```v
pub fn assert_ne[T](actual T, unexpected T, label string, file string, line int)
```

Asserts that two values are **not** equal and automatically formats a message when they are. Useful for checking that a search succeeded, a pointer is not null-equivalent, or a value changed.

**Simple example**

```v
// Make sure a search actually found something (index != -1).
names := ['Alice', 'Bob', 'Carol']
idx := names.index('Bob')
contracts.assert_ne(idx, -1, 'index of Bob', @FILE, @LINE)
println(names[idx])  // Bob
```

**Advanced example**

```v
// After applying a transform, verify the result actually changed.
fn apply_discount(price f64, pct f64) f64 {
    contracts.require(pct > 0.0 && pct < 1.0, 'discount must be between 0 and 1', @FILE, @LINE)
    result := price * (1.0 - pct)
    contracts.assert_ne(result, price, 'discounted price', @FILE, @LINE)
    return result
}

println(apply_discount(100.0, 0.2))  // 80.0
```

---

### `require_not_none`

```v
pub fn require_not_none[T](value ?T, message string, file string, line int) T
```

Unwraps an optional value, firing a precondition violation if it is `none`. Combines a nil-guard check and unwrap into one call, removing the need to write `require(x != none, ...) ; val := x?` separately.

**Simple example**

```v
// Greet a user — their name must have been provided.
fn greet(maybe_name ?string) string {
    name := contracts.require_not_none(maybe_name, 'a name must be provided', @FILE, @LINE)
    return 'Hello, ${name}!'
}

println(greet('Alice'))      // Hello, Alice!
greet(none)                  // panic: Precondition (require) violated … a name must be provided
```

**Advanced example**

```v
// A database lookup that must succeed — missing rows are a programming error here.
struct User { name string; age int }

fn find_user(db map[int]User, id int) User {
    maybe := db[id] or { none }  // returns none if key missing
    return contracts.require_not_none(maybe,
        'user with id ${id} must exist in the database', @FILE, @LINE)
}

db := { 1: User{'Alice', 30}, 2: User{'Bob', 25} }
println(find_user(db, 1).name)  // Alice
find_user(db, 99)               // panic: Precondition (require) violated … user with id 99 must exist
```

---

### `Invariant`

```v
pub struct Invariant { ... }

pub fn (mut i Invariant) check(condition bool, message string)
pub fn (mut i Invariant) validate(file string, line int) bool
pub fn (mut i Invariant) reset()
```

A helper struct for **multi-condition invariant checking**. Instead of stopping at the first failed condition, `Invariant` accumulates all failures and then reports them all at once via `validate()`. This gives a complete picture of a broken object state rather than forcing you to fix one condition at a time. Use `reset()` to clear failures and reuse the same instance across multiple validation cycles.

**Simple example**

```v
// Check that a rectangle is valid — all conditions reported at once.
struct Rect { x int; y int; width int; height int }

fn (r &Rect) validate(file string, line int) {
    mut inv := contracts.Invariant{}
    inv.check(r.width > 0,  'width must be positive')
    inv.check(r.height > 0, 'height must be positive')
    inv.validate(file, line)
}

mut r := Rect{ x: 0, y: 0, width: -5, height: 0 }
r.validate(@FILE, @LINE)
// fires twice:
//   Invariant violated … width must be positive
//   Invariant violated … height must be positive
```

**Advanced example**

```v
// A bounded queue checks multiple structural properties before and after mutations.
struct BoundedQueue {
mut:
    items    []int
    capacity int
    head_idx int
}

fn (q &BoundedQueue) check_invariants() {
    mut inv := contracts.Invariant{}
    inv.check(q.capacity > 0,              'capacity must be positive')
    inv.check(q.items.len <= q.capacity,   'items must not exceed capacity')
    inv.check(q.head_idx >= 0,             'head_idx must be >= 0')
    inv.check(q.head_idx <= q.items.len,   'head_idx must not exceed items.len')
    inv.validate(@FILE, @LINE)
}

fn (mut q BoundedQueue) enqueue(v int) {
    q.check_invariants()
    contracts.require(q.items.len < q.capacity, 'queue is full', @FILE, @LINE)
    q.items << v
    q.check_invariants()
}

fn (mut q BoundedQueue) dequeue() int {
    q.check_invariants()
    contracts.require(q.head_idx < q.items.len, 'queue is empty', @FILE, @LINE)
    val := q.items[q.head_idx]
    q.head_idx++
    q.check_invariants()
    return val
}
```

---

### `ContractedFn`

```v
pub struct ContractedFn[T] { ... }

pub fn (mut c ContractedFn[T]) pre(condition bool, message string) &ContractedFn[T]
pub fn (mut c ContractedFn[T]) post(condition bool, message string) &ContractedFn[T]
pub fn (mut c ContractedFn[T]) call(body fn () T, file string, line int) T
```

A builder that lets you attach pre- and postconditions to a closure and execute it in one place. All preconditions are verified before `body` runs; all postconditions are verified after it returns. `T` is the return type of the wrapped function.

> **Note on postconditions:** Because V evaluates function arguments eagerly, any expression passed to `post()` is captured *before* `body()` runs. This means `post()` is suited to conditions that do not depend on the return value of `body`. For return-value postconditions, use `ensure_result()` inside the body instead.

**Simple example**

```v
// Wrap a calculation with a pre-check that the input is valid.
fn safe_sqrt(x f64) f64 {
    mut cf := contracts.ContractedFn[f64]{}
    cf.pre(x >= 0.0, 'x must be non-negative for sqrt')
    return cf.call(fn [x] () f64 { return math.sqrt(x) }, @FILE, @LINE)
}

println(safe_sqrt(9.0))   // 3.0
safe_sqrt(-1.0)           // panic: Precondition (require) violated … x must be non-negative for sqrt
```

**Advanced example**

```v
// Chain multiple preconditions and a context-independent postcondition.
fn bounded_divide(a f64, b f64, lo f64, hi f64) f64 {
    mut cf := contracts.ContractedFn[f64]{}
    cf.pre(b != 0.0,  'divisor must not be zero')
    cf.pre(lo < hi,   'lo must be less than hi')
    // post() condition evaluated before body — only valid for context-free assertions.
    cf.post(lo < hi,  'lo must still be less than hi after call')
    return cf.call(fn [a, b] () f64 {
        result := a / b
        return contracts.ensure_result(result, result >= lo && result <= hi,
            'result must be within [lo, hi]', @FILE, @LINE)
    }, @FILE, @LINE)
}
```

---

## Design Notes

**`@FILE` and `@LINE` at every call site.** V's compile-time identifiers are evaluated where you write them, not inside the module. Passing them explicitly means every violation message tells you the exact file and line in *your* code where the broken contract was written — which is always more useful than a location deep inside the module.

**`require` vs `ensure` vs `assert_that`.** These are intentionally separate. `require` means the *caller* made a mistake. `ensure` means *this function* made a mistake. `assert_that` is for general logic checks that don't fit neatly into either category. Keeping them distinct makes bug attribution immediate — you know whose code to look at without reading the message.

**Replaceable handler.** The default behaviour is to panic, but you can swap in any function matching `ViolationHandlerFn`. Common alternatives: a logger for production systems, a collector for test suites, or an error-reporter for monitoring. None of your call sites change when you swap the handler.

**Zero overhead when disabled.** Every check function is `@[inline]` and begins with `if !enabled { return }`. With `contracts.enabled = false`, the compiler sees an always-false branch and eliminates all contract code — no string allocation, no condition evaluation, no function call overhead.

**`Invariant.reset()` for reuse.** If you check invariants frequently (e.g., every frame in a game loop), allocating a new `Invariant{}` each time creates GC pressure. `reset()` clears the failure slice in place so you can reuse the same instance.

**`require_not_none` and generic functions.** `require_not_none`, `assert_eq`, `assert_ne`, and `ensure_result` are all generic over `T`. V's type inference means you rarely need to write the type parameter explicitly — just pass the values and the compiler works it out.

---

## Running the Tests

```sh
v test .
```

All tests are in `contracts_test.v`. They use a `ViolationCollector` helper that temporarily replaces the global handler to capture violations instead of panicking, making every scenario safely testable.
