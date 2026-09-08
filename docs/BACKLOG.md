# Backlog

Ordered. Pick from the top unless something is blocked. One task per session, finished, tested, logged.
Mark tasks `[x]` when done and add a line to CHANGELOG.md. Add new tasks at the right priority, not the bottom.

## P0 — make the fight feel good

- [ ] Verify in-editor: camera framing matches Smite reference (character lower-center, wide view). Tune `spring_length`, arm offset, FOV in `scenes/player.tscn`.
- [ ] Hit feedback: brief hit-stop, camera shake on heavy hits, damage numbers floating above targets.
- [ ] Basic attack animation timing: melee should have a short wind-up (0.1s) before damage lands, and the model should lunge slightly.
- [ ] Projectiles: add a trail (ribbon or particles) and a muzzle flash.
- [ ] Ground-targeted abilities: show a range ring on the floor while an ability key is held, cast on release (Smite style). Start with Flashbang and Static Field.
- [ ] Ultimate ready flash and sound cue.

## P1 — models and animation pipeline

- [ ] Rig placeholders to a humanoid skeleton in Blender (script), so Mixamo animations retarget. Start with the human.
- [ ] Import Mixamo idle / run / jump / attack clips; drive an `AnimationTree` from player state (idle, run, air, attack, stunned, dead).
- [ ] Transform animation: dissolve out old model, particle burst, dissolve in new model. Cel shader needs a `dissolve` uniform.
- [ ] Sculpt the human properly from `docs/concepts/human_turnaround.jpg`. Keep the file name `human.glb`.
- [ ] Sculpt Vantablade, Bulwark, Voltrix as real creatures.
- [ ] Per-ability animation hooks: `AbilityData` gets an `anim` field; the runner plays it.

## P1 — arena and world

- [ ] Hand-built arena scene replacing the procedural one. Keep `Game.spawn_points` populated.
- [ ] Jump pads, a center high ground, and a hazard.
- [ ] Better sky, fog, and post-processing preset for the cel look.

## P2 — multiplayer

- [ ] Late-joiner state: make sure a player who joins mid-match sees everyone's current form and health (currently relies on `_announce` on connect; verify).
- [ ] Relay or NAT punch-through so nobody has to port-forward. Options: Noray, a tiny relay server, or Steam networking later.
- [ ] Lobby: player list, ready-up, host starts the match.
- [ ] Reconnect handling and a clean "host left" screen.
- [ ] Interpolation buffer for remote players (currently a simple lerp; jitters on bad connections).

## P2 — game modes and progression

- [ ] Match rules: FFA to 10 kills, timer, end screen with scoreboard.
- [ ] Team mode (2v2) with team colors on outlines.
- [ ] Save the player's name and settings locally.

## P3 — new creatures (Ares's ongoing job)

Each creature: a `data/forms/<id>.gd`, a `.glb`, four abilities, a role, lore, and an entry in DESIGN.md. Ideas:
- [ ] A **controller** (medium everything, traps and zones).
- [ ] A **flyer** (short flight on ability, weak on the ground).
- [ ] A **healer/support** that buffs allies (needs team mode).
- [ ] A **shapeshifting glitch** whose abilities change each cast.

## P3 — audio

- [ ] Ability sounds, hit sounds, mutation sound, UI clicks.
- [ ] Arena ambience and a music loop.

## Tech debt

- [ ] Cooldowns reset on mutation. Decide: keep per-form cooldown state, or a global "mutation sickness" penalty.
- [ ] `receive_hit` applies damage on every peer (call_local); switch to authority-applied with health sync if desync shows up.
- [ ] Replace primitive `Fx` with GPUParticles3D presets.
- [ ] Unit tests for AbilityRunner targeting (cone, radius, nearest).

## Networking notes (2026-09-08)
- Hosting now tries UPnP to open UDP 7777 automatically; falls back to a manual-forward message. Joiners get a 12s timeout message.
- [ ] Relay / NAT punch-through for hosts behind CGNAT or routers without UPnP (Noray, or a tiny relay on a VPS). This is the only way to make "it just works" universal.
