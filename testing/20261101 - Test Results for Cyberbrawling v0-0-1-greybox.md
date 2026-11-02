# Test Results — Cyberbrawling my way to my love! v0.0.1, grey box (2026-11-01)

*Javier & Claude. Javier's first try of the grey-box build (commits up to `a226a5c`), the same night it was built.
Reported through the assistant team.*

## F-1: the hero walks left nonstop with the Logitech G13 plugged in
- **What happened:** with the G13 connected, the hero walked left (and up the street) by himself and never stopped.
- **Why:** the G13's thumbstick reports full left and full up while resting. At connect, Godot delivers 0 then -1
  in the same instant, and the game read the stick straight through its action map, so "full left" counted as held.
  The same fault was F-8 on Karatecation; this game's own lesson L-6 warned about it, and the build still read the
  stick plainly. Our miss.
- **Fix:** sticks no longer go through the action map. `scripts/sim/stick_guard.gd` counts a stick axis only once it
  has been seen near the middle after its connect burst (a real stick passes the middle when a hand moves it), each
  pad and axis on its own; a dead zone of 0.25 swallows drift, and unplugging a pad starts it over.
- **Proof:** `tests/test_sticks.gd` replays the G13's connect burst through Godot's own input. On the old code it
  fails (the hero is told full left and full up every tick); on the fixed code it passes. 51 tests, 422 checks.
- **Status:** fixed in the build; waiting for Javier's re-try with the G13 plugged back in.
