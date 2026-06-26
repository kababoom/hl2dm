#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* ColorUpSound — restores the level-up sound + center message that the old
 * EventScripts colorup played but the SM colorup.smx port dropped. colorup.smx
 * still handles the player colors; this re-adds the audible/visible
 * "You're now level N - <color>" feedback at the same kill thresholds, only on
 * the transition into a new level (not every kill). Matches the original:
 *   levels  10 / 20 / 30 / 40 / 50  ->  Yellow / Green / Blue / Magenta / Red
 *   sound   doors/latchunlocked1.wav  (stock HL2, no download needed)
 * The sound is emitted to the leveling player only, like the ES es_cexec play. */

#define SOUND "doors/latchunlocked1.wav"

ConVar g_enable;
int  g_levels[5]    = { 10, 20, 30, 40, 50 };
char g_colors[5][16] = { "Yellow", "Green", "Blue", "Magenta", "Red" };
int  g_level[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name        = "ColorUpSound",
	author      = "HagenIT",
	description = "Level-up sound + message for colorup (restores the dropped ES behavior)",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_enable = CreateConVar("sm_colorupsound_enable", "1", "Play the colorup level-up sound + message (1/0)");
	AutoExecConfig(true, "colorupsound");
	HookEvent("player_death", Evt_Death, EventHookMode_Post);
}

public void OnMapStart()
{
	PrecacheSound(SOUND, true);
	for (int i = 1; i <= MaxClients; i++)
		g_level[i] = 0;          // frags reset on map change -> level resets too
}

public void OnClientPutInServer(int client)
{
	g_level[client] = 0;
}

public void Evt_Death(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_enable.BoolValue)
		return;

	int attacker = GetClientOfUserId(e.GetInt("attacker"));
	int victim   = GetClientOfUserId(e.GetInt("userid"));
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker))
		return;
	if (attacker == victim || IsFakeClient(attacker))   // skip suicides + bots (bots can't hear/see)
		return;

	int frags = GetClientFrags(attacker);
	int lvl = 0;
	for (int i = 0; i < 5; i++)
		if (frags >= g_levels[i])
			lvl = i + 1;

	if (lvl > g_level[attacker])                          // only on the transition into a new level
	{
		g_level[attacker] = lvl;
		PrintCenterText(attacker, "You're now level %d - %s", lvl, g_colors[lvl - 1]);
		EmitSoundToClient(attacker, SOUND);
	}
}
