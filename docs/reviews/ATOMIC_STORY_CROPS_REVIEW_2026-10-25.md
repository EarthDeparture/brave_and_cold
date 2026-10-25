# Small story and greenhouse corrections

Start `8886280`; recovery tag `checkpoint/pre-atomic-story-crops-2026-10-25`. Each numbered change has its own local commit. No push. Claude's unfinished animal pass is outside this work.

1. Delivery chronology: the driver-sick override is restricted to worried Rowan on day two after 14:00. The existing day-three worried and ill dialogue can now play. The added day-three illness assertion failed before the fix; the complete town/save suite then passed **54 checks, zero failures** (`brave-and-cold/shots/atomic-story-chronology.log`). No new dialogue or stock behavior.

2. Conversation continuity: ordinary schedules wait while the resident is talking, including beyond the existing 18-minute grace. After closing the exchange the schedule catches up under its previous observation rules. The schedule suite passed **27 checks, zero failures**, including active conversation before/after the grace, release, and illness interruption (`brave-and-cold/shots/atomic-conversation-schedule.log`). Other observed transitions keep their existing policy.

Validation notes: the local headless run also reports the sandbox certificate-store error, the existing Terrain3D deprecation warning and a JSON-read error in the unrelated sound-board review loader. There were no GDScript errors. Assertions passed despite those diagnostics; they are not described as a clean application log. User saves and sound-review data were not edited.
