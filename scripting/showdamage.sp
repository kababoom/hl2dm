/* Show Damage — HL2:DM build.
 *
 * Inspired by "Show Damage" by exvel, stickz, malt (github.com/stickz/Redstone,
 * GPL v2+). That plugin reads the `player_hurt` game event — which HL2:DM does
 * NOT fire reliably — so this build detects damage via `SDKHooks_OnTakeDamage`
 * instead (the method our botdamagescale / botpropdamage plugins already use on
 * these servers). Accumulates the damage you deal each tick and shows it as
 * "-<dmg>  (<victim>: <hp> HP)" (or "<victim> killed!"), one update per batch so
 * multi-pellet hits read as a single number. Default output is the chat area.
 */
#include <sourcemod>
#include <sdkhooks>
#pragma semicolon 1
#pragma newdecls required

ConVar g_enabled, g_ff, g_ownDmg, g_area;
int  g_damage[MAXPLAYERS + 1];
int  g_lastVictim[MAXPLAYERS + 1];   // userid of the most recent victim in the batch
bool g_block[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name        = "Show Damage",
	author      = "exvel, stickz, malt (HL2DM/SDKHooks build: HagenIT)",
	description = "Shows the damage you deal + the victim's remaining health",
	version     = "1.3",
	url         = "https://github.com/stickz/Redstone"
};

public void OnPluginStart()
{
	g_enabled = CreateConVar("sm_show_damage",           "1", "Enable show-damage (0/1)", _, true, 0.0, true, 1.0);
	g_ff      = CreateConVar("sm_show_damage_ff",        "1", "Show team / friendly-fire damage too (0/1) — keep 1 for FFA deathmatch", _, true, 0.0, true, 1.0);
	g_ownDmg  = CreateConVar("sm_show_damage_own_dmg",   "0", "Show your own self damage, e.g. fall / explosion (0/1)", _, true, 0.0, true, 1.0);
	g_area    = CreateConVar("sm_show_damage_text_area", "3", "Where to show it: 1 = center, 2 = hint, 3 = chat", _, true, 1.0, true, 3.0);
	AutoExecConfig(true, "showdamage");

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

	// hook clients already connected (covers a mid-map plugin reload)
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientPutInServer(int client)
{
	g_block[client] = false;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_block[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_enabled.BoolValue || damage <= 0.0)
		return Plugin_Continue;
	if (attacker < 1 || attacker > MaxClients || IsFakeClient(attacker) || !IsClientInGame(attacker))
		return Plugin_Continue;

	if (victim >= 1 && victim <= MaxClients)
	{
		if (victim == attacker && !g_ownDmg.BoolValue)
			return Plugin_Continue;
		if (GetClientTeam(victim) == GetClientTeam(attacker) && !g_ff.BoolValue)
			return Plugin_Continue;
	}

	g_damage[attacker] += RoundToNearest(damage);
	g_lastVictim[attacker] = (victim >= 1 && victim <= MaxClients) ? GetClientUserId(victim) : 0;

	if (!g_block[attacker])
	{
		CreateTimer(0.01, Timer_ShowDamage, GetClientUserId(attacker));
		g_block[attacker] = true;
	}
	return Plugin_Continue;
}

public Action Timer_ShowDamage(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Stop;

	g_block[client] = false;

	if (g_damage[client] > 0)
	{
		char msg[128];
		int victim = GetClientOfUserId(g_lastVictim[client]);
		if (victim >= 1 && victim <= MaxClients && IsClientInGame(victim))
		{
			char vname[MAX_NAME_LENGTH];
			GetClientName(victim, vname, sizeof(vname));
			if (IsPlayerAlive(victim))
				Format(msg, sizeof(msg), "-%d  (%s: %d HP)", g_damage[client], vname, GetClientHealth(victim));
			else
				Format(msg, sizeof(msg), "-%d  (%s killed!)", g_damage[client], vname);
		}
		else
			Format(msg, sizeof(msg), "-%d", g_damage[client]);

		switch (g_area.IntValue)
		{
			case 1: PrintCenterText(client, "%s", msg);
			case 2: PrintHintText(client,   "%s", msg);
			case 3: PrintToChat(client,     "%cFFFFFF%s", 0x07, msg);   // 0x07 + RRGGBB = white
		}

		g_damage[client] = 0;
		g_lastVictim[client] = 0;
	}
	return Plugin_Stop;
}
