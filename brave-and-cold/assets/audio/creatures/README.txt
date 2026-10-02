CREATURE SOUNDS - drop-in folder
================================
Put recorded sounds in the folder for the creature, named  <event>_<number>.<ogg|wav|mp3>
(or drop raw downloads in <project>/audio_in/<kind>/ and run  python tools/audio/prep_clips.py  - it names, trims, normalises).

zombie/  idle  alert  attack  hurt  death   (groan, spotted-you shout, grab, hit, die)
wolf/    howl  growl  attack  hurt  death
bear/    roar  growl  attack  hurt  death
deer/    snort hurt   death   alert

* Several files with the same event are variants; one is picked at random each time (3-6 per event sounds natural).
* Missing event? it falls back (hurt -> grunt, death -> hurt ...) and finally to the built-in synthetic sound,
  so you can add files a few at a time.
* Mono, 0.4-4 s for hurt/attack/growl, up to 8 s for idle/roar, howls may be long. Quiet tail trimmed.
* Loudness: aim for similar levels; the game sets distance falloff, wall muffling and 3D position itself.
* Keep a note of every pack's licence (CC0 / royalty-free / CC-BY needs credit) in docs/audio_credits.md.
