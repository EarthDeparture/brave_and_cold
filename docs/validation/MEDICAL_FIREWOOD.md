# Bandaging, blood recovery and stored firewood

Baseline: `721981ffa35a9dfba4f5bbb17778a3954f10a04a`. Feature branch: `codex/bandaging-blood-firewood`. Rollback checkpoint: `checkpoint/pre-bandaging-blood-firewood-2026-10-05`. Local integration only; no push.

## Player behavior and root causes

Medical items had no use entry in the current Gear menu, so their default double-click action could drop them. Gear now exposes Apply bandage, Clean wound and Take antibiotics before drop/store. Selecting a bandage and pressing its use button, double-clicking it or choosing the right-click treatment stops active bleeding and consumes exactly one bandage. An unnecessary treatment preserves the item. The world binds treatment to the current player's injury object; saved/replaced avatars cannot accidentally target stale global injury state. The exact damaging bleed threshold is also treatable.

Recovery now runs once per actual advanced game time, awake and asleep, after needs and injury damage. It requires food strictly above 900 kcal, water strictly above 45%, no damaging bleeding, core temperature at least 35 C and no symptomatic infection. Awake recovery is 1 health point/hour (120 on the displayed blood scale); warm sleep is up to 3 points/hour (360 displayed), with the existing mild-cold rest penalty. Recovery caps at full health and never revives a dead player. The old separate sleep healing pass was removed, preventing double healing and recovery while underfed/dehydrated. Gear explains bleeding, recovery and the relevant pause reason. A bandage does not cure infection or refill blood immediately.

Blood remains the existing shared health pool, displayed as health times 120. This implementation therefore restores general lost health too; it does not introduce independent blood volume, wound categories or shock. Treatment remains immediate, matching current inventory use. Thresholds/rates are gameplay values to assess in human play-test. Recovery checks conditions each update; long accelerated steps that cross a threshold conservatively pause that step rather than award partial-step healing.

The original loose rack counter and provision chest were separate, so deposited wood could never update the initial log pile. The home chest is now the single authoritative fuel inventory. Gear deposits, withdrawals and the physical Stack firewood action update the original visible stack synchronously. Twelve logs are visible at most; overflow stays in storage with an explicit label. No new collision obstacles are added. A full backpack cannot withdraw a log, and a full visible rack cannot duplicate wood.

New games start with six stored logs, two carried logs and two hours of lit stove fuel: eighteen game hours total at continuous burn. Stored fuel and progress in existing saves are preserved. Legacy loose-rack wood merges once with stored wood, preserving weighted condition; home schema 2 uses only saved storage thereafter. The stove also refuses a log when it cannot accept its complete two-hour burn, preserving wood and matches. Relighting still requires one match and one log.

## Validation

Nine suites pass 414 checks: blood recovery 26; integrated medical/firewood 37; survival props 36; opening/save/power 53; live radio/calendar/audio/sleep 140; watch/walkie/door 46; door/stove/log reader 35; radio/tree/log/plank 29; survival 12. Tests cover real Gear mouse paths, current-avatar treatment, actual world/sleep time, thresholds, death/caps, fuel conservation, rack updates, capacity and repeated fresh-world save migrations. Final editor import is checked separately for script/parse errors.

Eight Forward+ Direct3D12 captures cover initial, empty, replenished, full and overflow rack; bandage use; recovering status; and a hydration pause at 1280x720. Two GPU assertions verify identical original replenished stack transforms and three distinct elevated layers at twelve logs. The headless dummy renderer does not retain MultiMesh transforms, so the geometry assertions run on the real renderer. Capture source: `brave-and-cold/tests/visual/capture_medical_firewood.gd`. Evidence: ignored `brave-and-cold/shots/medical-firewood/`. All eight images visually reviewed. Existing engine interpolation deprecation and shutdown CanvasItem/ObjectDB/resource warnings remain; they are not reported as resolved. Tests never write user saves. Human play-test is pending.

Roadside task ideas and their implementation requirements are in `docs/design/EARLY_OUTBREAK_ROAD_WORK.md`. New roadside quests, locations and assets are planned rather than implemented in this change.

## Play-test

- Take a bandage from home provisions if necessary. While bleeding, open Tab and double-click the bandage or select Apply bandage. Check that bleeding stops and one wrap disappears.
- Keep food above 900 kcal and water above 45%; check Gear's recovery status and gradual blood gain. Compare warm rest, low water and cold conditions. There should be no instant blood refill.
- Withdraw the home logs, gather/split timber and deposit wood using Gear or Stack firewood. The original stack should disappear/reappear, consume matching stored quantities and survive save/load.
- Start New Game to evaluate the smaller reserve. Time a gathering trip and assess whether fuel runs short fairly; loading an old game intentionally retains its previous supplies.

## Revert

Revert the feature commit to preserve later Claude/user changes, then refresh Godot imports. Do not hard-reset the shared checkout or restore unrelated files from the checkpoint. Schema-two home saves remain readable by the old code because they retain diagnostic wood_left and storage; reverting after saving would reintroduce the old split-stock model and can double-count fuel on a subsequent migration. For rollback comparison use the preserved pre-change save/checkpoint, or explicitly reconcile those two legacy counts rather than blindly switching a progressed save back and forth.
