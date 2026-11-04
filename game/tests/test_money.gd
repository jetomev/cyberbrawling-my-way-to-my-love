extends "res://tests/test_case.gd"
## Money on screen is always "$X,XXX.XX" (Javier, 2026-11-04): comma thousands, two decimals.

const Money := preload("res://scripts/sim/money.gd")


func test_money_is_dollars_comma_thousands_two_decimals() -> void:
	for c in [[0.0, "$0.00"], [5.0, "$5.00"], [12.5, "$12.50"], [999.99, "$999.99"], [1000.0, "$1,000.00"],
			[1234.5, "$1,234.50"], [1234567.891, "$1,234,567.89"], [0.005, "$0.01"], [-12.0, "-$12.00"], [-0.001, "$0.00"]]:
		eq(Money.text(c[0]), c[1], "%s" % str(c[0]))
