# HL2DM SourceMod Plugins

Custom [SourceMod](https://www.sourcemod.net/) plugins for the **[S-UK] Half-Life 2: Deathmatch** servers, converted from the legacy *Mattie EventScripts* (Python‑2) setup to native SourcePawn.

## Plugins

| Plugin | What it does | CVars / config |
|---|---|---|
| **saysounds** | Chat-trigger sounds — type a keyword (`hi`, `woohoo`, `bird`, …) and it plays a sound. 105 triggers, random pick per trigger. | `configs/saysounds.cfg` |
| **botping** | Gives bots a fake scoreboard ping so they look like real players. | `sm_botping_min` (50), `sm_botping_max` (75), `sm_botping_interval` (3.0) |
| **ragequit_sm** | "`<name>` has left in rage!" + sound when a player dies then immediately disconnects. | `sm_ragequit_maxdelay` (10.0) |
| **killsremaining** | Center message + voice line at 10 / 5 / 1 kills to the frag limit. | uses `mp_fraglimit` |
| **deathmessages** | Custom kill-feed text in chat (per-weapon kills, suicides, world/NPC deaths). | `configs/deathmessages.cfg` — `%1` = victim, `%2` = killer |
| **hitsound_precache** | Helper: precaches + download-registers the custom hitsound (the main hitsound plugin only precaches its built-in default). | — |
| **tagwatch** | Log-only: records players wearing the clan tag (name + SteamID + already-whitelisted?) to build a member whitelist before enforcing tag protection. **Never kicks.** | `sm_tagwatch_tag` (`S-UK`), `sm_tagwatch_enable` (1) → `logs/tagwatch.log` |
| **botpropdamage** | Makes bots take damage from gravity-gunned / thrown physics props (the HL2DM engine applies impact damage to real players but skips fake clients). Measures prop speed from position deltas — vphysics doesn't update `m_vecAbsVelocity` — plus a path-sweep that catches fast props that tunnel through the hitbox. Also dissolves bots hit by **AR2 orbs** (combine balls), which the engine skips the same way. Kills credited to the thrower/firer. | `sm_botpropdmg_minspeed` (250), `dmgper100` (15), `maxdamage` (120), `radius` (45), `cooldown` (0.5), `debug` (0) |
| **netwatch** | Logs per-player connection quality — samples ping/loss/choke every 30s: live `FLAG` lines when over threshold, plus a per-session `SESSION` summary (avg + peak) on disconnect. For spotting bad / deliberately-high-ping connections and deciding whether to act. | `sm_netwatch_loss` (3.0), `sm_netwatch_choke` (5.0), `sm_netwatch_ping` (200) → `logs/netwatch.log` |

## Install
1. Copy `plugins/*.smx` → `addons/sourcemod/plugins/`
2. Copy `configs/*.cfg` → `addons/sourcemod/configs/`
3. Edit `scripting/*.sp` and recompile with `spcomp` if you want to change behavior.
4. The referenced sounds must exist under `sound/` and be downloadable (fast-dl / a downloader plugin). Stock HL2 sounds (`vo/`, `ambient/`, `npc/`) need no download.

## Notes
- Sound plugins precache in `OnMapStart`, so after a fresh load they need one map change before their sounds play (on-screen text works immediately).
- `deathmessages.cfg` and `saysounds.cfg` are plain KeyValues — add/remove entries freely, then `sm plugins reload <name>`.

## Related (client-side companions)
These run on the **player's** Linux machine, not the server:
- **[hl2dm-linux-texture-fix](https://github.com/kababoom/hl2dm-linux-texture-fix)** — fixes purple/missing custom-map textures on the native Linux HL2:DM client (lowercases VPK/BSP content; no Proton, keeps VAC).
- **[linux-bhop](https://github.com/kababoom/linux-bhop)** — hold-to-bunnyhop (auto-jump) via evdev/uinput; works native or Proton.

## Credits
Written/ported for the S‑UK HL2DM servers. `deathmessages` message style is inspired by MacDGuy's *Custom Player Death Messages*; `saysounds`/`botping`/`ragequit`/`killsremaining` replace the old EventScripts `sh_say`/`rg_botping`/`ragequit`/`kill_cd`.
