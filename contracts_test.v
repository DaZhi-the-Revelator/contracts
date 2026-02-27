module contracts

// ── Helper: collect violations instead of panicking ──────────────────────────

struct ViolationCollector {
mut:
	violations []ViolationInfo
}

fn (mut vc ViolationCollector) install() {
	vc.violations.clear()
	handle := fn [mut vc] (info ViolationInfo) {
		vc.violations << info
	}
	handler = handle
}

fn (mut vc ViolationCollector) restore() {
	handler = default_handler
}

// ── require ───────────────────────────────────────────────────────────────────

fn test_require_passes_when_condition_true() {
	mut vc := ViolationCollector{}
	vc.install()
	require(true, 'should not fire', @FILE, @LINE)
	assert vc.violations.len == 0
	vc.restore()
}

fn test_require_fires_when_condition_false() {
	mut vc := ViolationCollector{}
	vc.install()
	require(false, 'test precondition', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .precondition
	assert vc.violations[0].message == 'test precondition'
	vc.restore()
}

fn test_require_no_op_when_disabled() {
	mut vc := ViolationCollector{}
	vc.install()
	enabled = false
	require(false, 'should be skipped', @FILE, @LINE)
	assert vc.violations.len == 0
	enabled = true
	vc.restore()
}

// ── ensure ────────────────────────────────────────────────────────────────────

fn test_ensure_passes_when_condition_true() {
	mut vc := ViolationCollector{}
	vc.install()
	ensure(true, 'should not fire', @FILE, @LINE)
	assert vc.violations.len == 0
	vc.restore()
}

fn test_ensure_fires_when_condition_false() {
	mut vc := ViolationCollector{}
	vc.install()
	ensure(false, 'test postcondition', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .postcondition
	vc.restore()
}

fn test_ensure_no_op_when_disabled() {
	mut vc := ViolationCollector{}
	vc.install()
	enabled = false
	ensure(false, 'should be skipped', @FILE, @LINE)
	assert vc.violations.len == 0
	enabled = true
	vc.restore()
}

// ── invariant_check ───────────────────────────────────────────────────────────

fn test_invariant_check_passes_when_condition_true() {
	mut vc := ViolationCollector{}
	vc.install()
	invariant_check(true, 'should not fire', @FILE, @LINE)
	assert vc.violations.len == 0
	vc.restore()
}

fn test_invariant_check_fires_when_condition_false() {
	mut vc := ViolationCollector{}
	vc.install()
	invariant_check(false, 'test invariant', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .invariant_fail
	vc.restore()
}

// ── assert_that ───────────────────────────────────────────────────────────────

fn test_assert_that_passes_when_condition_true() {
	mut vc := ViolationCollector{}
	vc.install()
	assert_that(true, 'should not fire', @FILE, @LINE)
	assert vc.violations.len == 0
	vc.restore()
}

fn test_assert_that_fires_when_condition_false() {
	mut vc := ViolationCollector{}
	vc.install()
	assert_that(false, 'test assertion', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .assertion
	vc.restore()
}

// ── assert_eq ─────────────────────────────────────────────────────────────────

fn test_assert_eq_passes_when_equal() {
	mut vc := ViolationCollector{}
	vc.install()
	assert_eq(42, 42, 'answer', @FILE, @LINE)
	assert vc.violations.len == 0
	vc.restore()
}

fn test_assert_eq_fires_when_not_equal() {
	mut vc := ViolationCollector{}
	vc.install()
	assert_eq(1, 2, 'my value', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .assertion
	assert vc.violations[0].message.contains('expected 2')
	assert vc.violations[0].message.contains('got 1')
	vc.restore()
}

// ── assert_ne ─────────────────────────────────────────────────────────────────

fn test_assert_ne_passes_when_not_equal() {
	mut vc := ViolationCollector{}
	vc.install()
	assert_ne(1, 2, 'index', @FILE, @LINE)
	assert vc.violations.len == 0
	vc.restore()
}

fn test_assert_ne_fires_when_equal() {
	mut vc := ViolationCollector{}
	vc.install()
	assert_ne(5, 5, 'index', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .assertion
	vc.restore()
}

// ── ensure_result ─────────────────────────────────────────────────────────────

fn test_ensure_result_returns_value_when_passing() {
	mut vc := ViolationCollector{}
	vc.install()
	result := ensure_result(99, true, 'should pass', @FILE, @LINE)
	assert result == 99
	assert vc.violations.len == 0
	vc.restore()
}

fn test_ensure_result_fires_and_still_returns_value() {
	mut vc := ViolationCollector{}
	vc.install()
	result := ensure_result(99, false, 'test postcondition on result', @FILE, @LINE)
	assert result == 99
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .postcondition
	vc.restore()
}

// ── require_not_none ──────────────────────────────────────────────────────────

fn test_require_not_none_unwraps_present_value() {
	mut vc := ViolationCollector{}
	vc.install()
	maybe := ?string('hello')
	result := require_not_none(maybe, 'must be present', @FILE, @LINE)
	assert result == 'hello'
	assert vc.violations.len == 0
	vc.restore()
}

fn test_require_not_none_fires_when_none() {
	mut vc := ViolationCollector{}
	vc.install()
	maybe := ?string(none)
	_ := require_not_none(maybe, 'value was none', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .precondition
	assert vc.violations[0].message == 'value was none'
	vc.restore()
}

// ── Invariant struct ──────────────────────────────────────────────────────────

fn test_invariant_validate_passes_when_all_checks_true() {
	mut vc := ViolationCollector{}
	vc.install()
	mut inv := Invariant{}
	inv.check(true, 'a')
	inv.check(true, 'b')
	passed := inv.validate(@FILE, @LINE)
	assert passed == true
	assert vc.violations.len == 0
	vc.restore()
}

fn test_invariant_validate_fires_for_each_failure() {
	mut vc := ViolationCollector{}
	vc.install()
	mut inv := Invariant{}
	inv.check(false, 'first failure')
	inv.check(true,  'passes fine')
	inv.check(false, 'second failure')
	passed := inv.validate(@FILE, @LINE)
	assert passed == false
	assert vc.violations.len == 2
	assert vc.violations[0].message == 'first failure'
	assert vc.violations[1].message == 'second failure'
	vc.restore()
}

fn test_invariant_reset_clears_failures() {
	mut vc := ViolationCollector{}
	vc.install()
	mut inv := Invariant{}
	inv.check(false, 'old failure')
	inv.reset()
	passed := inv.validate(@FILE, @LINE)
	assert passed == true
	assert vc.violations.len == 0
	vc.restore()
}

// ── ContractedFn ──────────────────────────────────────────────────────────────

fn test_contracted_fn_runs_body_when_preconditions_pass() {
	mut vc := ViolationCollector{}
	vc.install()
	mut cf := ContractedFn[int]{}
	cf.pre(true, 'always fine')
	result := cf.call(fn () int { return 7 }, @FILE, @LINE)
	assert result == 7
	assert vc.violations.len == 0
	vc.restore()
}

fn test_contracted_fn_fires_when_precondition_fails() {
	mut vc := ViolationCollector{}
	vc.install()
	mut cf := ContractedFn[int]{}
	cf.pre(false, 'bad precondition')
	_ := cf.call(fn () int { return 0 }, @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .precondition
	vc.restore()
}

fn test_contracted_fn_fires_when_postcondition_fails() {
	mut vc := ViolationCollector{}
	vc.install()
	mut cf := ContractedFn[int]{}
	cf.pre(true, 'pre passes')
	cf.post(false, 'bad postcondition')
	_ := cf.call(fn () int { return 0 }, @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].kind == .postcondition
	vc.restore()
}

// ── ViolationInfo fields ──────────────────────────────────────────────────────

fn test_violation_info_carries_file_and_line() {
	mut vc := ViolationCollector{}
	vc.install()
	require(false, 'location test', @FILE, @LINE)
	assert vc.violations.len == 1
	assert vc.violations[0].file.len > 0
	assert vc.violations[0].line > 0
	vc.restore()
}
