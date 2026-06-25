#include <sourcemod>
#include <sdkhooks>
#pragma semicolon 1
#pragma newdecls required

/* BotDamageScale — softens how hard bots hit human players. Scales only
 * bot->human damage (default 0.5 = half); bot-vs-bot and human damage are
 * untouched. Helps with the "bot rounds a corner and instantly melts you" case. */

ConVar g_scale;

public Plugin myinfo =
{
	name        = "Bot Damage Scale",
	author      = "HagenIT",
	description = "Scales damage bots deal to human players (default half)",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_scale = CreateConVar("sm_botdamage_scale", "0.5",
		"Multiplier for damage BOTS deal to human players (0.5 = half, 1.0 = off/normal)",
		_, true, 0.0, true, 1.0);
	AutoExecConfig(true, "botdamagescale");

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// attacker must be a bot, victim must be a human
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || !IsFakeClient(attacker))
		return Plugin_Continue;
	if (victim < 1 || victim > MaxClients || IsFakeClient(victim))
		return Plugin_Continue;

	float scale = g_scale.FloatValue;
	if (scale >= 1.0)
		return Plugin_Continue;

	damage *= scale;
	return Plugin_Changed;
}
