# Audio credits & licence

All recorded sounds currently shipped come from the **Sonniss GDC 2026 Game Audio Bundle** (free, royalty-free,
no attribution required, unlimited projects, commercial use allowed; licence PDF is inside each bundle zip:
"License - GDC Game Audio.pdf"). Credit is still given here as courtesy.

Clips are cut, mono-mixed, resampled to 44.1 kHz, loudness-normalised and (for loops) crossfaded by
`tools/audio/sonniss_import.py`; the level report is `tools/audio/sonniss_report.txt`.
Do not re-distribute the raw packs; only the processed clips in `brave-and-cold/assets/audio/` ship.

| Game use | Source pack (vendor) |
|---|---|
| wolf growl / attack (Werewolf Growl), bear growl (pitched down) | Epic Stock Media - Halloween Game Haunted House and Horror Audio Scare Kit |
| wolf hurt (dog grunt) | 344 Audio - Dog Vocalisations Vol. 1 |
| bear roar | 344 Audio - Dinosaurs Vol. 2 |
| bear attack | 344 Audio - Dinosaurs Vol. 1 |
| zombie attack / death / hurt / idle | Epic Stock Media - Humanoid Creatures Vol 4 (Monstrous and Undead Creature Vocalization) |
| zombie idle (exhale) | SoundBits - Vox Bestiae Source Elements |
| zombie idle (panting) | SoundBits - Vox Hominis Human Effort Voices |
| wind loop | 344 Audio - Extreme Winds Vol. 1 |
| campfire loop | Ivo Vicic - Campfire / Bonfire FX |
| cloth rustle | InMotionAudio - Foley T-Shirt |
| thud (body hit) | 344 Audio - Cinematic Fight Vol. 1 |
| chop (wood impact) | 344 Audio - Historical Weapons Vol. 2 |
| hammer (metal tap) | Epic Stock Media - HD Game Materials |

Anything not listed (gunshot, glass, footsteps, crash, slice, groan horde bed, deer, wolf howl) is still the procedural synth in `systems/sfx.gd`.
