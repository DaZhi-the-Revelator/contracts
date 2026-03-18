# contracts

**Version 1.2.2** · MIT License · by DaZhi-the-Revelator

A contract programming module for V. Provides **preconditions**, **postconditions**, **invariants**, and **assertions** — all routed through a configurable handler, fully disable-able, and compatible with V’s `!T` error model.

Contracts are **runtime guarantees** that define what your code *requires*, *ensures*, and *maintains*.

------

## Table of Contents

- [At a Glance](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#at-a-glance)
- [Philosophy](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#philosophy)
- [Installation](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#installation)
- [Quick Start](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#quick-start)
- [Shorthand](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#shorthand)
- [When to Use What](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#when-to-use-what)
- [API](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#api)
- [Real-World Examples](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#real-world-examples)
- [Anti-Patterns](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#anti-patterns)
- [Production Usage](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#production-usage)
- [Testing](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#testing)
- [Common Pitfalls](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#common-pitfalls)
- [Run Tests](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#run-tests)
- [Changelog](https://chatgpt.com/c/69bab78e-21fc-8329-8325-532ffc2ac608#changelog)

------

## At a Glance

- No global state — everything flows through `Config`
- Contracts are runtime correctness guarantees
- Replaceable handler (panic, log, collect, recover)
- Works with `!T` via `ViolationError`
- Precise diagnostics via `@FILE` / `@LINE`
- Zero overhead when disabled (explicitly)

------

## Philosophy

Contracts are executable boundaries:

- `require` → must be true before execution
- `ensure` → must be true after execution
- `invariant_check` → must always hold

They define valid program states—not optional checks.

------

## Installation

```sh
v install dazhi_the_revelator.contracts
import dazhi_the_revelator.contracts
```

------

## Quick Start

```v
import dazhi_the_revelator.contracts

const cfg = contracts.Config{}

fn divide(a f64, b f64) f64 {
    contracts.require(&cfg, b != 0.0, 'divisor must not be zero', @FILE, @LINE)

    result := a / b

    contracts.ensure(&cfg, result == result, 'result must not be NaN', @FILE, @LINE)
    return result
}
```

------

## Shorthand

```v
contracts.require(b != 0.0, 'divisor must not be zero')
contracts.ensure(result == result, 'result must not be NaN')
```

> ⚠️ Shorthand captures file/line inside the module, not your call site.

------

## When to Use What

| Situation                        | Use                |
| -------------------------------- | ------------------ |
| Caller gave invalid input        | `require`          |
| Function produced invalid output | `ensure`           |
| Internal state must remain valid | `invariant_check`  |
| General sanity check             | `assert_that`      |
| Validate return inline           | `ensure_result`    |
| Optional must exist              | `require_not_none` |
| One guarded execution            | `checked`          |

------

## API

### Config

```v
pub struct Config {
    enabled bool               = true
    handler ViolationHandlerFn = panic_handler
}
```

------

### require

#### Full form

```v
contracts.require(&cfg, cond, msg, @FILE, @LINE)
```

#### Shorthand

```v
contracts.require(cond, msg)
```

------

### ensure

#### Full form

```v
contracts.ensure(&cfg, cond, msg, @FILE, @LINE)
```

#### Shorthand

```v
contracts.ensure(cond, msg)
```

------

### ensure_result

#### Full form

```v
return contracts.ensure_result(&cfg, value, cond, msg, @FILE, @LINE)
```

#### Short form

```v
result := compute()
contracts.ensure(cond, msg)
return result
```

------

### invariant_check

#### Full form

```v
contracts.invariant_check(&cfg, cond, msg, @FILE, @LINE)
```

#### Shorthand

```v
contracts.invariant_check(cond, msg)
```

------

### assert_that

#### Full form

```v
contracts.assert_that(&cfg, cond, msg, @FILE, @LINE)
```

#### Shorthand

```v
contracts.assert_that(cond, msg)
```

------

### assert_eq

#### Full form

```v
contracts.assert_eq(&cfg, actual, expected, label, @FILE, @LINE)
```

#### Shorthand

```v
contracts.assert_eq(actual, expected, label)
```

------

### assert_ne

#### Full form

```v
contracts.assert_ne(&cfg, actual, unexpected, label, @FILE, @LINE)
```

#### Shorthand

```v
contracts.assert_ne(actual, unexpected, label)
```

------

### assert_lt

#### Full form

```v
contracts.assert_lt(&cfg, actual, limit, label, @FILE, @LINE)
```

#### Shorthand

```v
contracts.assert_lt(actual, limit, label)
```

------

### assert_gt

#### Full form

```v
contracts.assert_gt(&cfg, actual, floor, label, @FILE, @LINE)
```

#### Shorthand

```v
contracts.assert_gt(actual, floor, label)
```

------

### assert_in_range

#### Full form

```v
contracts.assert_in_range(&cfg, actual, lo, hi, label, @FILE, @LINE)
```

#### Shorthand

```v
contracts.assert_in_range(actual, lo, hi, label)
```

------

### assert_approx_eq

#### Full form

```v
contracts.assert_approx_eq(&cfg, actual, expected, tol, label, @FILE, @LINE)
```

#### Shorthand

```v
contracts.assert_approx_eq(actual, expected, tol, label)
```

------

### require_not_none

#### Full form

```v
val := contracts.require_not_none(&cfg, maybe, msg, @FILE, @LINE)
```

#### Shorthand

```v
val := contracts.require_not_none(maybe, msg)
```

> ⚠️ Returns zero value if handler does not panic.

------

### checked

#### Full form

```v
return contracts.checked(&cfg, cond, msg, fn () T { ... }, @FILE, @LINE)
```

#### Short form

```v
contracts.require(cond, msg)
return body()
```

------

### Invariant

#### Full form

```v
mut inv := contracts.Invariant{ cfg: &cfg }
inv.check(cond, 'msg')
inv.validate(@FILE, @LINE)
```

#### Short form

```v
contracts.invariant_check(cond, 'msg')
```

------

### ContractedFn

#### Full form

```v
mut cf := contracts.ContractedFn[int]{ cfg: &cfg }
cf.pre(cond, 'msg')
return cf.call(fn () int { ... }, @FILE, @LINE)
```

#### Simpler

```v
contracts.require(cond, msg)
return body()
```

> ⚠️ `post()` runs before execution.

------

### ViolationError

```v
return contracts.ViolationError{ info: ... }
```

------

## Real-World Examples

### API boundaries

```v
ct.require(req.email.contains('@'), 'invalid email')
```

### Invariants

```v
ct.invariant_check(acc.balance >= 0, 'balance must be non-negative')
```

### Data integrity

```v
ct.ensure(out.len == input.len, 'length must match')
```

------

## Anti-Patterns

- Disabling contracts by default
- Using shorthand everywhere
- Using float equality with `assert_eq`
- Using contracts for control flow
- Misusing `ContractedFn.post()`

------

## Production Usage

Contracts are designed to run in production.

```v
const cfg = contracts.Config{}
```

Disable only deliberately:

```v
const cfg = contracts.disabled()
```

------

## Testing

```v
mut violations := []contracts.ViolationInfo{}

const cfg = contracts.Config{
    handler: fn [mut violations] (info contracts.ViolationInfo) {
        violations << info
    }
}
```

------

## Common Pitfalls

- Missing `@FILE`, `@LINE`
- Overusing shorthand
- Float comparisons
- Silent zero values

------

## Run Tests

```sh
v test .
```

------

## Changelog

### 1.2.2

- Cleanup

### 1.2.0

- Shorthand

### 1.1.0

- `disabled()`

### 1.0.0

- Initial release
