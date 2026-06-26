#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* ColorUpSound — restores the level-up feedback the third-party colorup.smx
 * (kill-count player colors) lost when it was ported off EventScripts: at
 * 10/20/30/40/50 kills it plays a triumphant sound + a "You're now level N -
 * <color>" center message to that player, once per level (on the transition).
 * Sound = sanctuaryuk/winner.mp3 (the old Mani "winner" victory sting — it was
 * left only in downloads.ini after Mani was retired, so this re-uses it and
 * re-registers the download to stay self-contained). Companion to colorup.smx,
 * which still does the colors. */

#define SOUND     "sanctuaryuk/winner.mp3"
#define SOUNDFILE "sound/sanctuaryuk/winner.mp3"

ConVar g_enable;
int  g_levels[5]     = { 10, 20, 30, 40, 50 };
char g_colors[5][16] = { "Yellow", "Green", "Blue", "Magenta", "Red" };
int  g_level[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name        = "ColorUpSound",
	author      = "HagenIT",
	description = "Level-up sound + message for colorup",
	version     = "1.1",
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
	AddFileToDownloadsTable(SOUNDFILE);   // already in downloads.ini, but keeps the plugin self-contained
	for (int i = 1; i <= MaxClients; i++)
		g_level[i] = 0;
}

public void OnClientPutInServer(int client)
{
	g_level[client] = 0;
}

void DoLevelUp(int client, int lvl)
{
	PrintCenterText(client, "You're now level %d - %s", lvl, g_colors[lvl - 1]);
	PrecacheSound(SOUND, true);           // safety for a mid-map plugin reload
	EmitSoundToClient(client, SOUND);
}

public Action Evt_Death(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_enable.BoolValue)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(e.GetInt("attacker"));
	int victim   = GetClientOfUserId(e.GetInt("userid"));
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker))
		return Plugin_Continue;
	if (attacker == victim || IsFakeClient(attacker))
		return Plugin_Continue;

	int frags = GetClientFrags(attacker);
	int lvl = 0;
	for (int i = 0; i < 5; i++)
		if (frags >= g_levels[i])
			lvl = i + 1;

	if (lvl > g_level[attacker])
	{
		g_level[attacker] = lvl;
		DoLevelUp(attacker, lvl);
	}
	return Plugin_Continue;
}
