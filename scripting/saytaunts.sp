#include <sourcemod>
#pragma semicolon 1
#pragma newdecls required

/* SayTaunts — when a player types a keyword in chat, the server fires back a
 * witty one-liner (e.g. "wtf" -> "WTF? You died, that's WTF!"). Keyword/reply
 * pairs live in configs/saytaunts.cfg (matched as a case-insensitive substring,
 * like the old Mattie ES player_say.cfg this is ported from). Global cooldown
 * so it can't be spammed. The player's own message still shows normally. */

#define MAXT 64

ConVar g_enable, g_cooldown;
char  g_keyword[MAXT][64];
char  g_response[MAXT][192];
int   g_count;
float g_last;

public Plugin myinfo =
{
	name        = "SayTaunts",
	author      = "HagenIT",
	description = "Server fires a witty reply when a player types a keyword in chat",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_enable   = CreateConVar("sm_saytaunts_enable",   "1",   "Enable chat-keyword taunts (1/0)");
	g_cooldown = CreateConVar("sm_saytaunts_cooldown", "3.0", "Minimum seconds between taunts");
	AutoExecConfig(true, "saytaunts");
	AddCommandListener(OnSay, "say");
	AddCommandListener(OnSay, "say_team");
	LoadTaunts();
}

public void OnConfigsExecuted()
{
	LoadTaunts();   // pick up edits on a map change / config reload
}

void LoadTaunts()
{
	g_count = 0;
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/saytaunts.cfg");

	KeyValues kv = new KeyValues("SayTaunts");
	if (kv.ImportFromFile(path) && kv.GotoFirstSubKey(false))
	{
		do
		{
			if (g_count >= MAXT)
				break;
			kv.GetSectionName(g_keyword[g_count], 64);
			kv.GetString(NULL_STRING, g_response[g_count], 192);
			for (int i = 0; g_keyword[g_count][i] != '\0'; i++)
				g_keyword[g_count][i] = CharToLower(g_keyword[g_count][i]);
			if (g_keyword[g_count][0] != '\0' && g_response[g_count][0] != '\0')
				g_count++;
		}
		while (kv.GotoNextKey(false));
	}
	delete kv;
}

public Action OnSay(int client, const char[] command, int args)
{
	if (!g_enable.BoolValue || client < 1 || client > MaxClients)
		return Plugin_Continue;

	char text[256];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	if (text[0] == '\0')
		return Plugin_Continue;

	for (int i = 0; text[i] != '\0'; i++)
		text[i] = CharToLower(text[i]);

	for (int t = 0; t < g_count; t++)
	{
		if (StrContains(text, g_keyword[t]) != -1)
		{
			float now = GetGameTime();
			if (now - g_last < g_cooldown.FloatValue)
				return Plugin_Continue;
			g_last = now;
			RequestFrame(Frame_Reply, t);   // next frame, so the player's own line prints first
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public void Frame_Reply(any t)
{
	if (t >= 0 && t < g_count)
		PrintToChatAll("%s", g_response[t]);
}
