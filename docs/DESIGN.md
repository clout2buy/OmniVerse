# OmniVerse — Design Document

**One line:** A third-person arena brawler where you mutate into creatures with the **Mutrix** and fight your friends.

This file is the source of truth for design. If code and this doc disagree, fix one of them and say which in the changelog.

## Pillars

1. **Mutation is the fantasy.** Transforming should feel like the best moment in the game every time. Big flash, silhouette change, new kit.
2. **Every form is a real character.** Four abilities, a distinct silhouette, a distinct movement feel. No reskins.
3. **The human matters.** You are playable and vulnerable as a human. Getting caught out of a mutation is tense.
4. **Clean, stylized, readable.** Cel shading with ink outlines. Bold colors per form. Readability over realism.
5. **Friends first.** Peer-to-peer, join by code, no accounts, no servers.

## Camera and controls

- Third person, over the shoulder, high angle like Smite. Character faces the camera direction. Mouse aims.
- WASD move, Space jump, Esc release mouse, Tab scoreboard.
- LMB basic attack (hold to repeat), Q ability 1, E ability 2, R ultimate.
- 1 to 4 selects a form on the Mutrix.

## The Mutrix

- Holds a list of learned forms. Human is always slot 1.
- **Lock rule:** after any damage dealt or taken, the Mutrix is locked for **15 seconds**. Then you can mutate freely.
- Mutating keeps your **health percentage** (50% human becomes 50% Bulwark). Prevents free heals.
- Ability cooldowns reset on mutation. (Known exploit for later balance; the 15s lock limits it.)
- Human ultimate, **Mutrix Overcharge**, bypasses the lock once and buffs the next mutation's damage.
- Death always respawns you as human.

## Forms

| Form | Role | HP | Speed | Basic | Ability 1 (Q) | Ability 2 (E) | Ultimate (R) |
|---|---|---|---|---|---|---|---|
| Human | baseline | 100 | 6.5 | Pistol | Dodge Roll | Flashbang (stun 1.2s) | Mutrix Overcharge |
| Vantablade | assassin | 70 | 7.5 | Claw Combo | Blink (behind target) | Smoke Veil (stealth 3s) | Execute (kills under 35%) |
| Bulwark | tank | 220 | 4.8 | Slam | Ground Pound (knockback) | Stone Skin (-50% dmg 5s) | Seismic Charge (stun 1.5s) |
| Voltrix | speedster | 110 | 9.5 | Charged Bolt | Dash Strike | Static Field (slow 55% 3s) | Storm Surge (chain x4) |

Numbers live in `data/forms/*.gd`. This table is the intent; tune the files.

### Ability kinds (engine support)

`AbilityData.Kind`: MELEE, PROJECTILE, DASH, BLINK, BUFF, AOE, STEALTH, EXECUTE, CHAIN, OVERCHARGE.
A new creature can be made purely from these. A creature that needs a new mechanic gets a new Kind plus a case in `AbilityRunner`.

## Art direction

- Reference: `docs/concepts/human_turnaround.jpg` for the human. Lanky, spiky blue hair, dark jacket with teal lapels, orange turtleneck, navy pants.
- Style target: Borderlands-style cel shading and ink outlines, but cleaner and less grungy. Bold flat colors, strong silhouettes.
- Creatures should each own a color: Vantablade purple-black, Bulwark stone and ember, Voltrix cyan and yellow.
- Models face **+Y in Blender** so they face **-Z in Godot**. Feet at origin, about 1.8 units tall. `FormData.size` scales in-game.

## Multiplayer

- Host opens UDP 7777 with ENet. Friends join with a code that encodes the host's IP and port.
- Each player is the authority over their own body. Position syncs at 30 Hz. Hits are broadcast by the attacker.
- Trust model: friends. No cheat protection, by design, for now.
- Internet play needs the host to port-forward 7777, or a relay later (see backlog).

## Later (not now)

- Exploration zones with wild creatures you scan to learn.
- Character creator for the human.
- Unstable mutations, hybrid forms, evolutions.
- Modes: FFA, teams, king of the hill.
