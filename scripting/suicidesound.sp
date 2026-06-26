#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* SuicideSound — plays "Suicide Is Painless" (the M*A*S*H theme, suicide.mp3)
 * automatically when a human player suicides: kills themselves (kill bind, own
 * grenade/RPG) or dies to the world / fall damage. The clip was already on the
 * servers + fast-dl (an old Mani sound, also wired as a "suicide is painless!"
 * chat trigger in saysounds); this just fires it on the actual suicide death.
 * Server-wide by default, rate-limited. */

#define SOUND     "sanctuaryuk/suicide.mp3"
#define SOUNDFILE "sound/sanctuaryuk/suicide.mp3"

ConVar g_enable, g_cooldown, g_all;
float g_lastPlay;

public Plugin myinfo =
{
	name        = "SuicideSound",
	author      = "HagenIT",
	description = "Plays 'Suicide Is Painless' when a player suicides",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_enable   = CreateConVar("sm_suicidesound_enable",   "1",   "Play the M*A*S*H tune on a suicide (1/0)");
	g_cooldown = CreateConVar("sm_suicidesound_cooldown", "8.0", "Minimum seconds between plays");
	g_all      = CreateConVar("sm_suicidesound_all",      "1",   "1 = the whole server hears it, 0 = only the victim");
	AutoExecConfig(true, "suicidesound");
	HookEvent("player_death", Evt_Death, EventHookMode_Post);
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

	int victim   = GetClientOfUserId(e.GetInt("userid"));
	int attacker = GetClientOfUserId(e.GetInt("attacker"));
	if (victim < 1 || victim > MaxClients || !IsClientInGame(victim) || IsFakeClient(victim))
		return Plugin_Continue;

	// suicide = killed self, or died to the world / fall / own explosive
	if (!(attacker == victim || attacker <= 0))
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
		EmitSoundToClient(victim, SOUND);

	return Plugin_Continue;
}
