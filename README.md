# contracts

**Version 1.2.2** · MIT License · by DaZhi-the-Revelator

A contract programming module for V. Provides **preconditions**, **postconditions**, **invariants**, and **assertions** — all routed through a configurable handler, fully disable-able, and compatible with V’s `!T` error model.

------

## At a Glance

- No global state — everything flows through `Config`
- Replaceable violation handler (panic, log, collect)
- Works with `!T` via `ViolationError`
- Precise diagnostics with `@FILE` / `@LINE`
- Effectively zero overhead when disabled

------

## Installation

```sh
v install dazhi_the_revelator.contracts
import dazhi_the_revelator.contracts
```

------

## Quick Start

```v
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

> ⚠️ Shorthand loses call-site file/line. Use full form for accurate diagnostics.

------

# API

------

## `require` — Precondition

### Full form

```v
contracts.require(&cfg, b != 0.0, 'divisor must not be zero', @FILE, @LINE)
```

### Shorthand

```v
contracts.require(b != 0.0, 'divisor must not be zero')
```

------

## `ensure` — Postcondition

### Full form

```v
contracts.ensure(&cfg, result >= 0, 'result must be non-negative', @FILE, @LINE)
```

### Shorthand

```v
contracts.ensure(result >= 0, 'result must be non-negative')
```

------

## `ensure_result` — Return validation

### Full form

```v
return contracts.ensure_result(&cfg, value, value > 0, 'must be positive', @FILE, @LINE)
```

### Shorthand (inside body)

```v
result := compute()
contracts.ensure(result > 0, 'must be positive')
return result
```

------

## `invariant_check` — Internal consistency

### Full form

```v
contracts.invariant_check(&cfg, s.len >= 0, 'length must be valid', @FILE, @LINE)
```

### Shorthand

```v
contracts.invariant_check(s.len >= 0, 'length must be valid')
```

------

## `assert_that` — General assertion

### Full form

```v
contracts.assert_that(&cfg, items.len > 0, 'must not be empty', @FILE, @LINE)
```

### Shorthand

```v
contracts.assert_that(items.len > 0, 'must not be empty')
```

------

## `assert_eq`

### Full form

```v
contracts.assert_eq(&cfg, result, expected, 'result check', @FILE, @LINE)
```

### Shorthand

```v
contracts.assert_eq(result, expected, 'result check')
```

------

## `assert_ne`

### Full form

```v
contracts.assert_ne(&cfg, idx, -1, 'index must exist', @FILE, @LINE)
```

### Shorthand

```v
contracts.assert_ne(idx, -1, 'index must exist')
```

------

## `assert_lt`

### Full form

```v
contracts.assert_lt(&cfg, index, items.len, 'index', @FILE, @LINE)
```

### Shorthand

```v
contracts.assert_lt(index, items.len, 'index')
```

------

## `assert_gt`

### Full form

```v
contracts.assert_gt(&cfg, items.len, 0, 'items.len', @FILE, @LINE)
```

### Shorthand

```v
contracts.assert_gt(items.len, 0, 'items.len')
```

------

## `assert_in_range`

### Full form

```v
contracts.assert_in_range(&cfg, pct, 0, 100, 'percent', @FILE, @LINE)
```

### Shorthand

```v
contracts.assert_in_range(pct, 0, 100, 'percent')
```

------

## `assert_approx_eq`

### Full form

```v
contracts.assert_approx_eq(&cfg, result, 3.14, 0.01, 'pi', @FILE, @LINE)
```

### Shorthand

```v
contracts.assert_approx_eq(result, 3.14, 0.01, 'pi')
```

------

## `require_not_none`

### Full form

```v
val := contracts.require_not_none(&cfg, maybe, 'must exist', @FILE, @LINE)
```

### Shorthand

```v
val := contracts.require_not_none(maybe, 'must exist')
```

> ⚠️ If handler does not panic, returns zero value of `T`.

------

## `checked`

### Full form

```v
return contracts.checked(&cfg, x >= 0, 'must be non-negative',
    fn () f64 { return math.sqrt(x) }, @FILE, @LINE)
```

### Shorthand pattern

```v
contracts.require(x >= 0, 'must be non-negative')
return math.sqrt(x)
```

------

## `Invariant`

### Full form

```v
mut inv := contracts.Invariant{ cfg: &cfg }
inv.check(x > 0, 'x must be positive')
inv.check(y > 0, 'y must be positive')
inv.validate(@FILE, @LINE)
```

### Shorthand-style usage

```v
contracts.invariant_check(x > 0, 'x must be positive')
contracts.invariant_check(y > 0, 'y must be positive')
```

------

## `ContractedFn`

### Full form

```v
mut cf := contracts.ContractedFn[int]{ cfg: &cfg }
cf.pre(x > 0, 'x must be positive')
return cf.call(fn () int { return x * 2 }, @FILE, @LINE)
```

### Simpler alternative

```v
contracts.require(x > 0, 'x must be positive')
return x * 2
```

> ⚠️ `post()` cannot depend on return value (evaluated early)

------

## `ViolationError`

```v
return contracts.ViolationError{ info: ... }
```

Used for `!T` error flows instead of panicking.

------

## Production

```v
const cfg = $if prod {
    contracts.disabled()
} else {
    contracts.Config{}
}
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

- Shorthand hides real file/line
- `assert_eq` with floats → use `assert_approx_eq`
- `require_not_none` can silently return zero value
- `ContractedFn.post()` evaluated too early
- Forgetting `@FILE`, `@LINE`

------

## Run Tests

```sh
v test .
```
