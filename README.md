# OmniVerse

Third-person arena brawler. You have the **Mutrix**: mutate into creatures and fight your friends.

Godot 4.7 + Blender 5.1. Peer-to-peer, join by code.

## Play

Open the folder in Godot 4.7 and press F5, or:

```powershell
& "C:\Users\Clout\OneDrive\Desktop\Installers & Archives\Godot_v4.7.1\Godot_v4.7.1-stable_win64.exe" --path . -- --solo
```

**HOST** to play alone (there are training dummies) or share the code with friends. Friends paste it and hit **JOIN**.
Same Wi-Fi: use the LAN code. Internet: host forwards UDP 7777.

| Key | Action |
|---|---|
| WASD / Space | Move / jump |
| LMB | Basic attack (hold) |
| Q / E / R | Ability 1 / Ability 2 / Ultimate |
| 1 2 3 4 | Mutate (Human, Bulwark, Vantablade, Voltrix) |
| Tab | Scoreboard |
| Esc | Release mouse / show codes |

## Develop

- `docs/DESIGN.md` — what the game is.
- `docs/BACKLOG.md` — what to build next.
- `docs/ARES.md` — how to work on it.
- `.\tools\check.ps1` — tests and smoke run. `-Models` regenerates placeholder meshes.
