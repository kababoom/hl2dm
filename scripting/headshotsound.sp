#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* HeadshotSound — on a .357 magnum hit that deals headshot-level damage (a body
 * magnum shot is ~40, a headshot ~225) it plays the "Headshot!" announce
 * (quake/headshot.mp3, already shipped by the quakesounds pack) and suppresses
 * the normal hitsound for that one hit via a sound hook, so it's INSTEAD of the
 * hitsound, not on top of it. The hitsound lives in a separate (source-less)
 * plugin, hence the sound-hook approach. */

#define HSND      "quake/headshot.mp3"
#define HSNDFILE  "sound/quake/headshot.mp3"

ConVar g_enable, g_minDmg, g_all;
float  g_suppress[MAXPLAYERS + 1];   // block the hitsound to this shooter until this time

public Plugin myinfo =
{
	name        = "HeadshotSound",
	author      = "HagenIT",
	description = "Plays a headshot sound (instead of the hitsound) on a magnum headshot",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_enable = CreateConVar("sm_headshotsound_enable",    "1",   "Enable the magnum headshot sound (1/0)");
	g_minDmg = CreateConVar("sm_headshotsound_mindamage", "150", "Min .357 damage to count as a headshot (body ~40, headshot ~225)");
	g_all    = CreateConVar("sm_headshotsound_all",       "0",   "1 = whole server hears it, 0 = only the shooter");
	AutoExecConfig(true, "headshotsound");

	AddNormalSoundHook(SoundHook);
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnMapStart()
{
	PrecacheSound(HSND, true);
	AddFileToDownloadsTable(HSNDFILE);
}

public void OnClientPutInServer(int client)
{
	g_suppress[client] = 0.0;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_enable.BoolValue || attacker < 1 || attacker > MaxClients || IsFakeClient(attacker) || !IsClientInGame(attacker))
		return Plugin_Continue;
	if (damage < g_minDmg.FloatValue)
		return Plugin_Continue;

	int wep = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if (wep <= 0)
		return Plugin_Continue;
	char cls[32];
	GetEntityClassname(wep, cls, sizeof(cls));
	if (!StrEqual(cls, "weapon_357"))
		return Plugin_Continue;

	// magnum headshot: announce it + tell the sound hook to swallow the hitsound that follows
	g_suppress[attacker] = GetGameTime() + 0.4;
	PrecacheSound(HSND, true);
	if (g_all.BoolValue)
		EmitSoundToAll(HSND);
	else
		EmitSoundToClient(attacker, HSND);

	return Plugin_Continue;
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (StrContains(sample, "buttons/hit.wav", false) == -1)   // only the hitsound
		return Plugin_Continue;

	int n = 0;
	bool changed = false;
	for (int i = 0; i < numClients; i++)
	{
		int c = clients[i];
		if (c >= 1 && c <= MaxClients && GetGameTime() < g_suppress[c])
		{
			changed = true;   // drop this recipient (he just headshotted -> hears the headshot sound instead)
			continue;
		}
		clients[n++] = clients[i];
	}
	if (changed)
	{
		numClients = n;
		return (n == 0) ? Plugin_Stop : Plugin_Changed;
	}
	return Plugin_Continue;
}
