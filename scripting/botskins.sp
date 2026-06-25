#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* BotSkins — gives each bot a random player model on spawn, so the bots look
 * like a mix of real players instead of one identical model (HRCbot's
 * hrcbot_playermodel only sets ONE model for all bots; "*" = default = combine).
 * Models are precached on map start; a short timer re-applies after spawn so it
 * wins over HRCbot's own model assignment. */

ConVar g_enable;

char g_models[][PLATFORM_MAX_PATH] =
{
	"models/humans/group03/male_01.mdl",
	"models/humans/group03/male_02.mdl",
	"models/humans/group03/male_03.mdl",
	"models/humans/group03/male_04.mdl",
	"models/humans/group03/male_05.mdl",
	"models/humans/group03/male_06.mdl",
	"models/humans/group03/male_07.mdl",
	"models/humans/group03/male_08.mdl",
	"models/humans/group03/male_09.mdl",
	"models/humans/group03/female_01.mdl",
	"models/humans/group03/female_02.mdl",
	"models/humans/group03/female_03.mdl",
	"models/humans/group03/female_04.mdl",
	"models/humans/group03/female_06.mdl",
	"models/humans/group03/female_07.mdl",
	"models/Combine_Super_Soldier.mdl",
	"models/Combine_Soldier.mdl",
	"models/police.mdl"
};

public Plugin myinfo =
{
	name        = "BotSkins",
	author      = "HagenIT",
	description = "Random player model per bot on spawn (variety instead of one model)",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_enable = CreateConVar("sm_botskins_enable", "1", "Give bots a random model on spawn (1/0)");
	AutoExecConfig(true, "botskins");
	HookEvent("player_spawn", Evt_Spawn, EventHookMode_Post);
}

public void OnMapStart()
{
	for (int i = 0; i < sizeof(g_models); i++)
		PrecacheModel(g_models[i], true);
}

public void Evt_Spawn(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_enable.BoolValue)
		return;
	int client = GetClientOfUserId(e.GetInt("userid"));
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsFakeClient(client))
		return;
	// small delay so we apply AFTER HRCbot's own model assignment on spawn
	CreateTimer(0.1, Tmr_SetModel, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Tmr_SetModel(Handle t, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && IsPlayerAlive(client))
		SetEntityModel(client, g_models[GetRandomInt(0, sizeof(g_models) - 1)]);
	return Plugin_Stop;
}
