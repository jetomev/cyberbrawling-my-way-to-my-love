extends RefCounted
## Money on screen, one way only (Javier, 2026-11-04, through the assistant team: "$X,XXX.XX" — comma thousands, two
## decimals), for any amount the game shows, now or later: every price, tip, debt or prize goes through text().
## Javier & Claude.


## An amount in dollars as the game writes it: 1234.5 -> "$1,234.50", 0.0 -> "$0.00", -12.0 -> "-$12.00".
static func text(amount: float) -> String:
	var cents: int = roundi(absf(amount) * 100.0)
	var whole: String = str(cents / 100)
	var grouped := ""
	while whole.length() > 3:
		grouped = "," + whole.right(3) + grouped
		whole = whole.left(whole.length() - 3)
	return "%s$%s%s.%02d" % ["-" if amount < 0.0 and cents > 0 else "", whole, grouped, cents % 100]
