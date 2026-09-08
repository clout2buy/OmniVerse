# Working on OmniVerse (instructions for Ares)

You are building this game slowly, one solid step per session. Quality over quantity. A session that ships one polished, tested feature is a good session.

## Every session

1. Read `docs/DESIGN.md` (intent), `docs/BACKLOG.md` (what's next), and the last few entries of `docs/CHANGELOG.md` (what just happened).
2. Pick **one** task from the top of the backlog. If it is too big for a session, split it in the backlog first and do the first piece.
3. Do it. Keep changes focused. Don't refactor unrelated code.
4. Run the checks (below). They must pass.
5. Mark the task done in `BACKLOG.md`, add a `CHANGELOG.md` entry, commit with a clear message.

## Checks

```powershell
.\tools\check.ps1            # import + tests + headless smoke run
.\tools\check.ps1 -Models    # also regenerate placeholder .glb files with Blender
```

- `tests/run_tests.gd` validates every form, join codes, and that core scripts compile. Add tests when you add logic.
- The smoke run hosts a solo match headless for 180 frames. Any `SCRIPT ERROR` fails it.

## Tools you have

- **Godot 4.7.1** (console build) at `C:\Users\Clout\OneDrive\Desktop\Installers & Archives\Godot_v4.7.1\Godot_v4.7.1-stable_win64_console.exe`. Override with `$env:GODOT`.
- **Blender 5.1** at `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`. Override with `$env:BLENDER`.
  Use it headless: `blender -b --factory-startup -P script.py`. See `tools/blender/gen_placeholders.py` for the model conventions.
- To see the game: `godot --path . -- --solo` hosts a match immediately. Screenshots can be captured from a script with `get_viewport().get_texture().get_image().save_png()` if you need to look at your work.

## Where things live

| What | Where |
|---|---|
| Form stats + abilities | `data/forms/<id>.gd` (one file per creature) |
| What an ability kind does | `scripts/combat/ability_runner.gd` |
| Player movement, camera, health, RPCs | `scripts/player/player.gd` |
| HUD | `scripts/ui/hud.gd` (drawn in code) |
| Arena | `scripts/world/arena.gd` (procedural for now) |
| Cel shader + outline | `assets/shaders/`, applied via `scripts/world/cel.gd` |
| Networking, join codes | `scripts/autoload/net.gd`, `scripts/net/join_code.gd` |
| Models | `assets/models/<form id>.glb` (human from `tools/blender/gen_human.py`, others from `gen_placeholders.py`) |
| Concept art | `docs/concepts/` |

## Rules

- **Never hardcode a creature.** Stats, names, colors, model paths all go in its `data/forms` file.
- **New mechanic = new `AbilityData.Kind`** + one `match` case in the runner. Keep the runner the only place abilities execute.
- **Every visual goes through `Cel`.** Don't add StandardMaterial3D meshes to the world.
- **Models face +Y in Blender**, feet at origin, roughly 1.8 units tall. Same file name to replace a placeholder.
- **Don't break multiplayer.** Anything that changes state other players must see goes through an RPC on the owning node.
- **Keep the game runnable at every commit.** If the editor can't open the project, that's a broken commit.
- If a task turns out to need a design decision, write the options in `BACKLOG.md` under the task and pick the simplest one. Note it in the changelog.

## Original IP

Ben 10 is the inspiration, not the content. Do not add Ben 10 aliens, names, or the Omnitrix. Invent creatures for the Mutrix.

## Releasing

`.\tools\release.ps1 0.2.0` runs checks, bumps `config/version`, tags `v0.2.0`, pushes. GitHub Actions (`.github/workflows/release.yml`) exports Windows + Linux, builds the Inno Setup installer, and publishes the release. Players see "UPDATE TO v0.2.0" in the lobby on next launch (`scripts/autoload/updater.gd`). Never delete a release that players may be updating from.
