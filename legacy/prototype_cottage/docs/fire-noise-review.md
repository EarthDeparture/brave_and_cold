# Fire fuel, light, and attraction review

Fireplace now exposes OUT, DYING (last 5 seconds), and LIT states. Lit fire
has a 6 m light radius and emits 24 m noise; dying fire has a 3 m light
radius, smaller flame, and emits 8 m noise. Values are exported for tuning.
Noise emits immediately on ignition/restoration to lit and every second
while burning, through NoiseEvents.emit_noise at the hearth's world position.
Burnout stops pulses; existing zombie noise memory expires normally.
DayNight's existing aggro multiplier still applies to hearing.

Warmth remains 5 points/second within 3 m, including dying embers, with
partial-final-frame heat and Temperature clamping preserved. Refueling
extends warmth and restores the larger attraction radius. Window attraction
and player detection remain independent zombie targeting mechanisms.

Reviewed scripts/fireplace.gd, scripts/noise.gd, scripts/zombie.gd,
scripts/temperature.gd, scenes/fireplace.tscn, and tests/test_fire_noise.gd.
Godot 4.5.1 headless import passed. Headless fire_noise, firewood, temperature,
hud, zombie, and day_night tests passed with zero failures. The new test covers failed
ignition, pulse cadence, negative time, state boundaries across large steps,
near/far zombie hearing, refueling, burnout, and relighting.

Human review required: light the fire, observe warmth recovery and approaching
zombies, wait for the last 5 seconds and confirm reduced light/flame and the
Dying prompt, then refuel and confirm increased brightness/attraction. Let it
burn out and verify warmth stops and zombies' remembered noise expires.
Check balance and readability in daytime and at night.

No separate planner brief/file/test checklist was supplied or found; exact
planner checklist verification and human playability review remain pending.
