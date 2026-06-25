#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* BotChat — SourcePawn port of the "ace_botchat" EventScript (Ace Rimmer 2006-07,
 * HL2DM edit by Loki 2007). Bots taunt/react with random lines from a replies DB:
 *   - on dying           (per weapon: crossbowdeath/crowbardeath/.../normaldeath)
 *   - on getting a kill  (shotgunkill/pistolkill/nadekill/normalkill)
 *   - on chat keywords   (a player says "gg"/"lol"/"timeleft"/... -> a bot replies)
 *   - greeting on join   (a bot greets; bots welcome a joining human)
 * Each reaction is gated by a 1-in-N chance (sm_botchat_chance). Replies live in
 * configs/botchat_replies.txt (the original es_bot_replies_db.txt, plain KeyValues).
 * Lines may contain event_var(es_attackername) / event_var(es_username) tokens which
 * are substituted with the killer / the triggering player's name.
 */

ConVar g_cEnable, g_cChance, g_cSayReplies;
KeyValues g_kv;

public Plugin myinfo =
{
	name        = "BotChat (ace_botchat port)",
	author      = "HagenIT (from Ace Rimmer / Loki EventScript)",
	description = "Bots taunt on deaths/kills, answer chat keywords, greet on join",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_cEnable     = CreateConVar("sm_botchat_enable",  "1", "Enable bot chatter (1/0)");
	g_cChance     = CreateConVar("sm_botchat_chance",  "8", "1-in-N chance a bot reacts to an event (higher = rarer; ~2x bot count)");
	g_cSayReplies = CreateConVar("sm_botchat_replies", "1", "Bots answer player chat keywords (1/0)");
	AutoExecConfig(true, "botchat");

	LoadDB();

	HookEvent("player_death",    Evt_Death,    EventHookMode_Post);
	HookEvent("player_say",      Evt_Say,      EventHookMode_Post);
	HookEvent("player_activate", Evt_Activate, EventHookMode_Post);
}

void LoadDB()
{
	if (g_kv != null) delete g_kv;
	g_kv = new KeyValues("bot_replies");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/botchat_replies.txt");
	if (!g_kv.ImportFromFile(path))
		LogError("[botchat] could not load %s", path);
}

bool Roll()
{
	int c = g_cChance.IntValue;
	if (c < 1) c = 1;
	return GetRandomInt(1, c) == 1;
}

// pick a random reply line from a trigger section
bool PickReply(const char[] trigger, char[] out, int len)
{
	g_kv.Rewind();
	g_kv.JumpToKey("bot_replies");       // descend into the file's root if ImportFromFile nested it
	if (!g_kv.JumpToKey(trigger))
	{
		g_kv.Rewind();                   // fallback: triggers sit at the absolute root
		if (!g_kv.JumpToKey(trigger))
			return false;
	}
	int count = g_kv.GetNum("count", 0);
	if (count <= 0)
		return false;
	char key[12];
	IntToString(GetRandomInt(1, count), key, sizeof(key));
	g_kv.GetString(key, out, len, "");
	g_kv.Rewind();
	return out[0] != '\0';
}

void Subst(char[] s, int len, int attacker, int user)
{
	char nm[MAX_NAME_LENGTH];
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
	{
		GetClientName(attacker, nm, sizeof(nm));
		ReplaceString(s, len, "event_var(es_attackername)", nm);
	}
	if (user > 0 && user <= MaxClients && IsClientInGame(user))
	{
		GetClientName(user, nm, sizeof(nm));
		ReplaceString(s, len, "event_var(es_username)", nm);
	}
	ReplaceString(s, len, "\"", "");   // never let a quote break the say command
}

void BotSay(int bot, const char[] msg, float delay)
{
	DataPack dp;
	CreateDataTimer(delay, Tmr_Say, dp, TIMER_FLAG_NO_MAPCHANGE);
	dp.WriteCell(GetClientUserId(bot));
	dp.WriteString(msg);
}

public Action Tmr_Say(Handle t, DataPack dp)
{
	dp.Reset();
	int bot = GetClientOfUserId(dp.ReadCell());
	char msg[192];
	dp.ReadString(msg, sizeof(msg));
	if (bot > 0 && IsClientInGame(bot) && IsFakeClient(bot) && msg[0])
		FakeClientCommand(bot, "say %s", msg);
	return Plugin_Stop;
}

int RandomBot()
{
	int bots[MAXPLAYERS + 1];
	int n = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsFakeClient(i))
			bots[n++] = i;
	return (n == 0) ? 0 : bots[GetRandomInt(0, n - 1)];
}

public void Evt_Death(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_cEnable.BoolValue)
		return;
	int victim   = GetClientOfUserId(e.GetInt("userid"));
	int attacker = GetClientOfUserId(e.GetInt("attacker"));
	char weapon[32];
	e.GetString("weapon", weapon, sizeof(weapon));

	// the bot that died reacts
	if (victim > 0 && victim <= MaxClients && IsClientInGame(victim) && IsFakeClient(victim) && Roll())
	{
		char trig[24] = "normaldeath";
		if      (StrEqual(weapon, "crossbow_bolt")) strcopy(trig, sizeof(trig), "crossbowdeath");
		else if (StrEqual(weapon, "combine_ball"))  strcopy(trig, sizeof(trig), "orbdeath");
		else if (StrEqual(weapon, "pistol"))        strcopy(trig, sizeof(trig), "pistoldeath");
		else if (StrEqual(weapon, "stunstick"))     strcopy(trig, sizeof(trig), "stunstickdeath");
		else if (StrEqual(weapon, "crowbar"))       strcopy(trig, sizeof(trig), "crowbardeath");
		else if (StrEqual(weapon, "slam"))          strcopy(trig, sizeof(trig), "slamdeath");
		else if (StrEqual(weapon, "grenade_frag"))  strcopy(trig, sizeof(trig), "nadedeath");
		char msg[192];
		if (PickReply(trig, msg, sizeof(msg)))
		{
			Subst(msg, sizeof(msg), attacker, victim);
			BotSay(victim, msg, 3.0);
		}
	}

	// the bot that got the kill reacts
	if (attacker > 0 && attacker <= MaxClients && attacker != victim && IsClientInGame(attacker) && IsFakeClient(attacker) && Roll())
	{
		char trig[24] = "normalkill";
		if      (StrEqual(weapon, "grenade_frag")) strcopy(trig, sizeof(trig), "nadekill");
		else if (StrEqual(weapon, "pistol"))       strcopy(trig, sizeof(trig), "pistolkill");
		else if (StrEqual(weapon, "shotgun"))      strcopy(trig, sizeof(trig), "shotgunkill");
		char msg[192];
		if (PickReply(trig, msg, sizeof(msg)))
		{
			Subst(msg, sizeof(msg), attacker, victim);
			BotSay(attacker, msg, 3.0);
		}
	}
}

public void Evt_Say(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_cEnable.BoolValue || !g_cSayReplies.BoolValue)
		return;
	int client = GetClientOfUserId(e.GetInt("userid"));
	if (client <= 0 || client > MaxClients)
		return;
	char text[192];
	e.GetString("text", text, sizeof(text));

	// first word is the trigger key
	char first[32];
	strcopy(first, sizeof(first), text);
	int sp = FindCharInString(first, ' ');
	if (sp != -1)
		first[sp] = '\0';
	if (!first[0])
		return;

	char msg[192];
	if (!PickReply(first, msg, sizeof(msg)))   // not a known keyword -> ignore
		return;
	if (!Roll())
		return;
	int bot = RandomBot();
	if (bot > 0)
	{
		Subst(msg, sizeof(msg), client, client);
		BotSay(bot, msg, 1.5);
	}
}

public void Evt_Activate(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_cEnable.BoolValue)
		return;
	int client = GetClientOfUserId(e.GetInt("userid"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return;

	if (IsFakeClient(client))
	{
		// a joining bot greets
		if (Roll())
		{
			char msg[192];
			if (PickReply("greetings", msg, sizeof(msg)))
			{
				Subst(msg, sizeof(msg), client, client);
				BotSay(client, msg, 6.0);
			}
		}
	}
	else
	{
		// a human joined -> a bot welcomes them
		if (Roll())
		{
			int bot = RandomBot();
			char msg[192];
			if (bot > 0 && PickReply("playerconnect", msg, sizeof(msg)))
			{
				Subst(msg, sizeof(msg), client, client);
				BotSay(bot, msg, 5.0);
			}
		}
	}
}
