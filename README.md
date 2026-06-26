# HL2DM SourceMod Plugins

Custom [SourceMod](https://www.sourcemod.net/) plugins for the **[S-UK] Half-Life 2: Deathmatch** servers, converted from the legacy *Mattie EventScripts* (Python‑2) setup to native SourcePawn.

## Plugins

| Plugin | What it does | CVars / config |
|---|---|---|
| **saysounds** | Chat-trigger sounds — type a keyword (`hi`, `woohoo`, `bird`, …) and it plays a sound. 105 triggers, random pick per trigger. **Bots are rate-limited per word** (`sm_saysounds_bot_cooldown`, default 120s) so they can't spam the same sound (e.g. the "cry" baby-wail); humans are never limited. | `configs/saysounds.cfg`, `sm_saysounds_bot_cooldown` (120) |
| **botping** | Gives bots a fake scoreboard ping so they look like real players. | `sm_botping_min` (50), `sm_botping_max` (75), `sm_botping_interval` (3.0) |
| **ragequit_sm** | "`<name>` has left in rage!" + sound when a player dies then immediately disconnects. | `sm_ragequit_maxdelay` (10.0) |
| **killsremaining** | Center message + voice line at 10 / 5 / 1 kills to the frag limit. | uses `mp_fraglimit` |
| **deathmessages** | Custom kill-feed text in chat (per-weapon kills, suicides, world/NPC deaths). | `configs/deathmessages.cfg` — `%1` = victim, `%2` = killer |
| **hitsound_precache** | Helper: precaches + download-registers the custom hitsound (the main hitsound plugin only precaches its built-in default). | — |
| **tagwatch** | Log-only: records players wearing the clan tag (name + SteamID + already-whitelisted?) to build a member whitelist before enforcing tag protection. **Never kicks.** | `sm_tagwatch_tag` (`S-UK`), `sm_tagwatch_enable` (1) → `logs/tagwatch.log` |
| **botpropdamage** | Makes bots take damage from gravity-gunned / thrown physics props (the HL2DM engine applies impact damage to real players but skips fake clients). Measures prop speed from position deltas — vphysics doesn't update `m_vecAbsVelocity` — plus a path-sweep that catches fast props that tunnel through the hitbox. Also dissolves bots hit by **AR2 orbs** (combine balls), which the engine skips the same way. Kills credited to the thrower/firer. | `sm_botpropdmg_minspeed` (250), `dmgper100` (15), `maxdamage` (120), `radius` (45), `cooldown` (0.5), `debug` (0) |
| **botdamagescale** | Scales the damage **bots deal to human players** (default `0.40`) — softens the "bot rounds a corner and instantly melts you" moment (bots hit for 117 raw on a point-blank shotgun). Bot-vs-bot and your own shots are untouched. | `sm_botdamage_scale` (0.40 — `1.0` = off), `sm_botdamage_debug` |
| **netwatch** | Logs per-player connection quality — samples ping/loss/choke every 30s: live `FLAG` lines when over threshold, plus a per-session `SESSION` summary (avg + peak) on disconnect. For spotting bad / deliberately-high-ping connections and deciding whether to act. | `sm_netwatch_loss` (3.0), `sm_netwatch_choke` (5.0), `sm_netwatch_ping` (200) → `logs/netwatch.log` |
| **botchat** | Bots trash-talk with random one-liners: on a kill ("die human", "too easy", shotgun → "this shotgun totally owns"), on dying (per weapon — crossbow → "doh"/"ns", crowbar → "lets see you try that again!"), answering chat keywords (a player types `gg`/`lol`/`timeleft` → a bot fires back), and greeting on join ("Finally its my turn", "fresh meat"). Port of the `ace_botchat` EventScript (Ace Rimmer / Loki). Lines + triggers in `configs/botchat_replies.txt`. | `sm_botchat_chance` (5 — 1-in-N per event, lower = chattier), `sm_botchat_replies` (1) |
| **botskins** | Random player model per bot on spawn — a mix of Group03 rebels (male/female) + combine variants — so the bots look like a group of real players instead of one identical white-combine army. (HRCbot's `hrcbot_playermodel` sets only ONE model for all bots; `*` = default = combine.) Precaches the list on `OnMapStart`; a 0.1s post-spawn timer applies the model so it overrides HRCbot's. | `sm_botskins_enable` (1) |
| **showdamage** | Shows the damage you deal — accumulated per tick so a shotgun blast reads as one number — as white `-24  (victim: 76 HP)` (or `… killed!`) in the chat. Detects hits via `SDKHooks_OnTakeDamage` because **HL2DM doesn't fire `player_hurt` reliably**. Adapted from exvel/stickz/malt's *Show Damage* (github.com/stickz/Redstone). | `sm_show_damage` (1), `sm_show_damage_ff` (1 — keep for FFA), `sm_show_damage_own_dmg` (0), `sm_show_damage_text_area` (3=chat / 2=hint / 1=center) |
| **colorupsound** | Restores the level-up feedback the third-party `colorup.smx` (kill-count player colors) lost when it was ported off EventScripts: at **10/20/30/40/50** kills it plays the `sanctuaryuk/winner.mp3` victory sting (recycled from the retired Mani admin plugin — it was left only in `downloads.ini`) + a center message *"You're now level N - &lt;color&gt;"* to that player, once per level (on the transition only). Companion to colorup.smx, which still does the colors. | `sm_colorupsound_enable` (1) |
| **bennyhill** | Plays *Yakety Sax* (the Benny Hill theme) when a human player gets a **pistol** kill — server-wide, rate-limited so a flurry of pistol kills doesn't stack the tune. Clip = `sanctuaryuk/bennyhill.mp3` (on the maps.hagenit.nl fast-dl + game box). | `sm_bennyhill_enable` (1), `sm_bennyhill_cooldown` (20.0), `sm_bennyhill_all` (1=everyone / 0=killer) |
| **suicidesound** | Plays *Suicide Is Painless* (the M\*A\*S\*H theme, `sanctuaryuk/suicide.mp3`) when a human player **suicides** (self-kill, or a world / fall death). Re-uses a clip already shipped on the servers (an old Mani sound, also wired as a `suicide is painless!` chat trigger in saysounds). | `sm_suicidesound_enable` (1), `sm_suicidesound_cooldown` (8.0), `sm_suicidesound_all` (1/0) |
| **haplo_protect_redux_2025** | Spawn + chat-area protection for **humans only** (skips bots via `IsFakeClient`). God-mode + red render tint on spawn, ends on shoot/move; reflects incoming damage back at anyone who shoots a protected player. **v2.5**: `OnTakeDamage` now never reflects off a bot, and protection flags are cleared whenever a client takes over a slot — fixes a deflection where a bot inheriting a just-protected human's slot kept the **stale** flag (plus a stale *grace* flag that made `OnPlayerRunCmd` never clear it, so it stuck permanently) and bounced your shots back as *your* suicide. (v2.4 added the spawn-time bot-exemption + load-time god-mode cleanup.) By [S-UK] Haplo & Gemini. | `sm_spawnprotect_color`, `sm_spawnprotect_move_threshold`, `sm_chatprotect_enabled`, `sm_chatprotect_wall_time` |

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
