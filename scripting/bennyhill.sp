#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* BennyHill — plays the Yakety Sax (Benny Hill theme) when a human player gets
 * a kill with the pistol (the dinky 9mm). Server-wide by default, rate-limited
 * so a flurry of pistol kills doesn't stack the tune over itself.
 * Sound = sanctuaryuk/bennyhill.mp3 (on the maps.hagenit.nl fast-dl + game box;
 * registered in the download table here, also on a mid-map load). */

#define SOUND     "sanctuaryuk/bennyhill.mp3"
#define SOUNDFILE "sound/sanctuaryuk/bennyhill.mp3"

ConVar g_enable, g_cooldown, g_all;
float g_lastPlay;

public Plugin myinfo =
{
	name        = "BennyHill",
	author      = "HagenIT",
	description = "Plays the Benny Hill theme on a pistol kill",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_enable   = CreateConVar("sm_bennyhill_enable",   "1",    "Play the Benny Hill tune on a pistol kill (1/0)");
	g_cooldown = CreateConVar("sm_bennyhill_cooldown", "20.0", "Minimum seconds between plays (the clip is ~16s)");
	g_all      = CreateConVar("sm_bennyhill_all",      "1",    "1 = the whole server hears it, 0 = only the killer");
	AutoExecConfig(true, "bennyhill");
	HookEvent("player_death", Evt_Death, EventHookMode_Post);
	AddFileToDownloadsTable(SOUNDFILE);   // also register on a mid-map load (OnMapStart handles fresh map loads)
}

public void OnMapStart()
{
	PrecacheSound(SOUND, true);
	AddFileToDownloadsTable(SOUNDFILE);
	g_lastPlay = -1000.0;
}

public Action Evt_Death(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_enable.BoolValue)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(e.GetInt("attacker"));
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || IsFakeClient(attacker))
		return Plugin_Continue;

	char weapon[48];
	e.GetString("weapon", weapon, sizeof(weapon));
	if (!StrEqual(weapon, "pistol", false))
		return Plugin_Continue;

	float now = GetGameTime();
	if (now - g_lastPlay < g_cooldown.FloatValue)
		return Plugin_Continue;
	g_lastPlay = now;

	PrecacheSound(SOUND, true);   // safety after a mid-map plugin reload
	if (g_all.BoolValue)
	{
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && !IsFakeClient(i))
				EmitSoundToClient(i, SOUND);
	}
	else
		EmitSoundToClient(attacker, SOUND);

	return Plugin_Continue;
}
