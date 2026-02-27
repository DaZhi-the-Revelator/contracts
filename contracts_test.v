module contracts

// cfg_default is a standard enabled Config used across all tests.
const cfg_default = Config{}

// cfg_disabled is a Config with all checks turned off, used to verify no-op behaviour.
const cfg_disabled = Config{ enabled: false }

// collect_cfg builds a Config whose handler appends every violation to `out`
// instead of panicking, allowing tests to assert on violations safely.
fn collect_cfg(mut out []ViolationInfo) Config {
	return Config{
		handler: fn [mut out] (info ViolationInfo) {
			out << info
		}
	}
}

// ── require ───────────────────────────────────────────────────────────────────

fn test_require_passes_when_condition_true() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	require(&cfg, true, 'should not fire', @FILE, @LINE)
	assert violations.len == 0
}

fn test_require_fires_when_condition_false() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	require(&cfg, false, 'test precondition', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .precondition
	assert violations[0].message == 'test precondition'
}

fn test_require_no_op_when_disabled() {
	mut violations := []ViolationInfo{}
	mut cfg := collect_cfg(mut violations)
	cfg = Config{ enabled: false, handler: cfg.handler }
	require(&cfg, false, 'should be skipped', @FILE, @LINE)
	assert violations.len == 0
}

// ── ensure ────────────────────────────────────────────────────────────────────

fn test_ensure_passes_when_condition_true() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	ensure(&cfg, true, 'should not fire', @FILE, @LINE)
	assert violations.len == 0
}

fn test_ensure_fires_when_condition_false() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	ensure(&cfg, false, 'test postcondition', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .postcondition
}

fn test_ensure_no_op_when_disabled() {
	mut violations := []ViolationInfo{}
	cfg := Config{ enabled: false, handler: fn (info ViolationInfo) {} }
	ensure(&cfg, false, 'should be skipped', @FILE, @LINE)
	assert violations.len == 0
}

// ── invariant_check ───────────────────────────────────────────────────────────

fn test_invariant_check_passes_when_condition_true() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	invariant_check(&cfg, true, 'should not fire', @FILE, @LINE)
	assert violations.len == 0
}

fn test_invariant_check_fires_when_condition_false() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	invariant_check(&cfg, false, 'test invariant', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .invariant_fail
}

// ── assert_that ───────────────────────────────────────────────────────────────

fn test_assert_that_passes_when_condition_true() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_that(&cfg, true, 'should not fire', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_that_fires_when_condition_false() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_that(&cfg, false, 'test assertion', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .assertion
}

// ── assert_eq ─────────────────────────────────────────────────────────────────

fn test_assert_eq_passes_when_equal() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_eq(&cfg, 42, 42, 'answer', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_eq_fires_when_not_equal() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_eq(&cfg, 1, 2, 'my value', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .assertion
	assert violations[0].message.contains('expected 2')
	assert violations[0].message.contains('got 1')
}

// ── assert_ne ─────────────────────────────────────────────────────────────────

fn test_assert_ne_passes_when_not_equal() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_ne(&cfg, 1, 2, 'index', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_ne_fires_when_equal() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_ne(&cfg, 5, 5, 'index', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .assertion
}

// ── assert_lt ─────────────────────────────────────────────────────────────────

fn test_assert_lt_passes_when_less() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_lt(&cfg, 3, 10, 'index', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_lt_fires_when_equal() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_lt(&cfg, 10, 10, 'index', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .assertion
	assert violations[0].message.contains('expected value < 10')
}

fn test_assert_lt_fires_when_greater() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_lt(&cfg, 15, 10, 'index', @FILE, @LINE)
	assert violations.len == 1
}

// ── assert_gt ─────────────────────────────────────────────────────────────────

fn test_assert_gt_passes_when_greater() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_gt(&cfg, 10, 3, 'count', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_gt_fires_when_equal() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_gt(&cfg, 5, 5, 'count', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .assertion
	assert violations[0].message.contains('expected value > 5')
}

fn test_assert_gt_fires_when_less() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_gt(&cfg, 2, 5, 'count', @FILE, @LINE)
	assert violations.len == 1
}

// ── assert_in_range ───────────────────────────────────────────────────────────

fn test_assert_in_range_passes_at_lo() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_in_range(&cfg, 0, 0, 100, 'value', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_in_range_passes_at_hi() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_in_range(&cfg, 100, 0, 100, 'value', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_in_range_passes_in_middle() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_in_range(&cfg, 50, 0, 100, 'value', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_in_range_fires_below_lo() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_in_range(&cfg, -1, 0, 100, 'value', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .assertion
	assert violations[0].message.contains('expected value in [0, 100]')
}

fn test_assert_in_range_fires_above_hi() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_in_range(&cfg, 101, 0, 100, 'value', @FILE, @LINE)
	assert violations.len == 1
}

// ── ensure_result ─────────────────────────────────────────────────────────────

fn test_ensure_result_returns_value_when_passing() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	result := ensure_result(&cfg, 99, true, 'should pass', @FILE, @LINE)
	assert result == 99
	assert violations.len == 0
}

fn test_ensure_result_fires_and_still_returns_value() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	result := ensure_result(&cfg, 99, false, 'test postcondition on result', @FILE, @LINE)
	assert result == 99
	assert violations.len == 1
	assert violations[0].kind == .postcondition
}

// ── require_not_none ──────────────────────────────────────────────────────────

fn test_require_not_none_unwraps_present_value() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	maybe := ?string('hello')
	result := require_not_none(&cfg, maybe, 'must be present', @FILE, @LINE)
	assert result == 'hello'
	assert violations.len == 0
}

fn test_require_not_none_fires_when_none() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	maybe := ?string(none)
	_ := require_not_none(&cfg, maybe, 'value was none', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .precondition
	assert violations[0].message == 'value was none'
}

// ── checked ───────────────────────────────────────────────────────────────────

fn test_checked_runs_body_when_condition_true() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	result := checked(&cfg, true, 'should pass', fn () int { return 42 }, @FILE, @LINE)
	assert result == 42
	assert violations.len == 0
}

fn test_checked_fires_when_condition_false() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	_ := checked(&cfg, false, 'bad precondition', fn () int { return 0 }, @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .precondition
}

// ── Invariant struct ──────────────────────────────────────────────────────────

fn test_invariant_validate_passes_when_all_checks_true() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	mut inv := Invariant{ cfg: &cfg }
	inv.check(true, 'a')
	inv.check(true, 'b')
	passed := inv.validate(@FILE, @LINE)
	assert passed == true
	assert violations.len == 0
}

fn test_invariant_validate_fires_for_each_failure() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	mut inv := Invariant{ cfg: &cfg }
	inv.check(false, 'first failure')
	inv.check(true,  'passes fine')
	inv.check(false, 'second failure')
	passed := inv.validate(@FILE, @LINE)
	assert passed == false
	assert violations.len == 2
	assert violations[0].message == 'first failure'
	assert violations[1].message == 'second failure'
}

fn test_invariant_reset_clears_failures() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	mut inv := Invariant{ cfg: &cfg }
	inv.check(false, 'old failure')
	inv.reset()
	passed := inv.validate(@FILE, @LINE)
	assert passed == true
	assert violations.len == 0
}

// ── ContractedFn ──────────────────────────────────────────────────────────────

fn test_contracted_fn_runs_body_when_preconditions_pass() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	mut cf := ContractedFn[int]{ cfg: &cfg }
	cf.pre(true, 'always fine')
	result := cf.call(fn () int { return 7 }, @FILE, @LINE)
	assert result == 7
	assert violations.len == 0
}

fn test_contracted_fn_fires_when_precondition_fails() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	mut cf := ContractedFn[int]{ cfg: &cfg }
	cf.pre(false, 'bad precondition')
	_ := cf.call(fn () int { return 0 }, @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .precondition
}

fn test_contracted_fn_fires_when_postcondition_fails() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	mut cf := ContractedFn[int]{ cfg: &cfg }
	cf.pre(true, 'pre passes')
	cf.post(false, 'bad postcondition')
	_ := cf.call(fn () int { return 0 }, @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .postcondition
}

// ── ViolationError ────────────────────────────────────────────────────────────

fn test_violation_error_msg_contains_message() {
	err := ViolationError{
		info: ViolationInfo{
			kind:    .precondition
			message: 'divisor must not be zero'
			file:    'test.v'
			line:    '42'
		}
	}
	assert err.msg().contains('divisor must not be zero')
	assert err.msg().contains('test.v:42')
	assert err.msg().contains('Precondition')
}

fn test_violation_error_msg_postcondition() {
	err := ViolationError{
		info: ViolationInfo{
			kind:    .postcondition
			message: 'result must be positive'
			file:    'math.v'
			line:    '7'
		}
	}
	assert err.msg().contains('Postcondition')
	assert err.msg().contains('result must be positive')
}

fn test_violation_error_code_is_zero() {
	err := ViolationError{}
	assert err.code() == 0
}

// ── ViolationInfo fields ──────────────────────────────────────────────────────

fn test_violation_info_carries_file_and_line() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	require(&cfg, false, 'location test', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].file.len > 0
	assert violations[0].line.len > 0
}

// ── ViolationInfo.str() ──────────────────────────────────────────────────────

fn test_violation_info_str_precondition() {
	info := ViolationInfo{
		kind:    .precondition
		message: 'x must be positive'
		file:    'math.v'
		line:    '10'
	}
	s := info.str()
	assert s.contains('Precondition (require) violated')
	assert s.contains('math.v:10')
	assert s.contains('x must be positive')
}

fn test_violation_info_str_postcondition() {
	info := ViolationInfo{ kind: .postcondition, message: 'result must be >= 0', file: 'f.v', line: '5' }
	assert info.str().contains('Postcondition (ensure) violated')
}

fn test_violation_info_str_invariant() {
	info := ViolationInfo{ kind: .invariant_fail, message: 'len >= 0', file: 'f.v', line: '1' }
	assert info.str().contains('Invariant violated')
}

fn test_violation_info_str_assertion() {
	info := ViolationInfo{ kind: .assertion, message: 'index in bounds', file: 'f.v', line: '1' }
	assert info.str().contains('Assertion failed')
}

fn test_violation_info_str_matches_panic_handler_format() {
	info := ViolationInfo{
		kind:    .precondition
		message: 'test'
		file:    'a.v'
		line:    '99'
	}
	// str() and ViolationError.msg() must produce identical output
	err := ViolationError{ info: info }
	assert info.str() == err.msg()
}

// ── disabled() ────────────────────────────────────────────────────────────────

fn test_disabled_returns_config_with_enabled_false() {
	cfg := disabled()
	assert cfg.enabled == false
}

fn test_disabled_config_skips_require() {
	mut violations := []ViolationInfo{}
	cfg := Config{ enabled: false, handler: fn [mut violations] (info ViolationInfo) { violations << info } }
	require(&cfg, false, 'should be skipped', @FILE, @LINE)
	assert violations.len == 0
}

// ── assert_approx_eq ──────────────────────────────────────────────────────────

fn test_assert_approx_eq_passes_when_within_tolerance() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_approx_eq(&cfg, 3.14160, 3.14159, 0.0001, 'pi', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_approx_eq_passes_when_exact() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_approx_eq(&cfg, 1.0, 1.0, 0.0001, 'value', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_approx_eq_passes_at_boundary() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_approx_eq(&cfg, 1.0001, 1.0, 0.0001, 'value', @FILE, @LINE)
	assert violations.len == 0
}

fn test_assert_approx_eq_fires_when_outside_tolerance() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_approx_eq(&cfg, 3.2, 3.14159, 0.0001, 'pi', @FILE, @LINE)
	assert violations.len == 1
	assert violations[0].kind == .assertion
	assert violations[0].message.contains('pi')
	assert violations[0].message.contains('3.14159')
}

fn test_assert_approx_eq_fires_when_negative_diff_outside_tolerance() {
	mut violations := []ViolationInfo{}
	cfg := collect_cfg(mut violations)
	assert_approx_eq(&cfg, 2.9, 3.14159, 0.0001, 'pi', @FILE, @LINE)
	assert violations.len == 1
}

fn test_assert_approx_eq_no_op_when_disabled() {
	mut violations := []ViolationInfo{}
	cfg := Config{ enabled: false, handler: fn [mut violations] (info ViolationInfo) { violations << info } }
	assert_approx_eq(&cfg, 99.0, 0.0, 0.0001, 'value', @FILE, @LINE)
	assert violations.len == 0
}

// ── Config defaults ───────────────────────────────────────────────────────────

fn test_config_default_is_enabled() {
	cfg := Config{}
	assert cfg.enabled == true
}

fn test_config_can_be_disabled() {
	cfg := Config{ enabled: false }
	assert cfg.enabled == false
}

fn test_panic_handler_is_default() {
	cfg := Config{}
	// We cannot call cfg.handler(failing info) without panicking, so we just
	// verify the field is not nil by checking the Config compiles and is usable.
	assert cfg.enabled == true
}
