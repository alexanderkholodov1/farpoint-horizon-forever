# The Earth at every speed of time (issue #55)

In the trip (`scripts/screens/flight.gd`, `_spin_earth`) the Earth turns at its true angle while that can be followed
by eye; when time runs so fast it would turn more than 0.15 times a second (at x10,000 and above: day, night and the
clouds flashing by), it is held at its last angle, and the time note says "the Earth's turning held still (it would
be a blur)"; it eases back to the true angle when time slows. Checked with a harness at x10, x1,000 and x100,000.
