# Zombie spawner review

Spawns only during night segments from DayNight, on the existing 30-metre ring
around the cottage at the main scene origin. First-night interval is 15 seconds;
subsequent intervals are 15 / day_count seconds, clamped to 0.1 seconds.
The exported spawn_interval sets the first-night interval. The existing initial
scene zombie remains present during daylight. Existing zombies persist at dawn.

Night one spawns green walkers (2 m/s). Starting on night two, orange runners
(3 m/s) join the pool: 15% chance on night two, increasing by 15 percentage
points each night up to 60%. Types share targeting, collision, and attack rules.
Runner materials are per-instance; walkers retain the scene material.

Dawn discards partial spawn progress. The existing 12-zombie cap includes the
initial zombie and discards backlog; spawning resumes when population drops.
Large clock steps use the day count of each night segment.

Changed files: scripts/zombie_spawner.gd, scripts/zombie.gd, tests/test_day_night.gd,
docs/day-night-review.md, and this document.

Automated verification: Godot headless editor import; test_day_night.gd
(night-only spawning, day scaling, large steps, invalid time, dawn reset,
ring placement, cap, resumption, cleanup, runner availability/speed/material,
and two complete clock cycles); test_game_outcome.gd;
test_zombie.gd; test_temperature.gd; test_player.gd; test_cottage.gd;
test_firewood.gd.

Human review required:
- Observe no new zombies during daylight, then timed arrivals after dusk.
- Compare first- and second-night cadence: 15 seconds versus 7.5 seconds.
- Confirm first-night arrivals are green walkers; later nights can spawn orange
  runners moving 50% faster. Check the mix and difficulty feel fair.
- Confirm arrivals surround the cottage and navigate around walls.
- Confirm no new arrivals after dawn and population never exceeds 12.

No planner brief was supplied or found, so its file/test checklist could not be
verified. Human review remains pending.

Current automated results (Godot 4.5.1): editor import and day/night, game outcome,
temperature, player, and firewood suites pass. Zombie suite reports eight failures
(targeting/navigation); cottage suite reports one failure (sprint+interact door
boarding). Both failures were reproduced in a temporary project copy with the
variant changes removed. Human review remains pending.
