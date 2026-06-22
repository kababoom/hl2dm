#include <sourcemod>
#pragma semicolon 1
#pragma newdecls required

/* Tag Watch — LOG ONLY (no kick).
 * Records every non-bot player whose name contains the watched clan tag,
 * with their SteamID and whether they already hold the tag-protection flag
 * (Custom1 'o' / Root 'z'). Used to build a complete [S-UK] member whitelist
 * before enforcement is ever turned on. Writes to addons/sourcemod/logs/tagwatch.log
 */

ConVar g_cEnable;
ConVar g_cTag;
char g_logPath[PLATFORM_MAX_PATH];
char g_lastLogged[MAXPLAYERS + 1][128];

public Plugin myinfo =
{
	name        = "Tag Watch",
	author      = "HagenIT",
	description = "Log-only: records players using the clan tag to build a whitelist (no kick)",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_cEnable = CreateConVar("sm_tagwatch_enable", "1", "Enable tag-watch logging (1=on/0=off)");
	g_cTag    = CreateConVar("sm_tagwatch_tag", "S-UK", "Case-insensitive substring watched in player names");
	BuildPath(Path_SM, g_logPath, sizeof(g_logPath), "logs/tagwatch.log");
	AutoExecConfig(true, "tagwatch");
}

public void OnClientPostAdminCheck(int client)
{
	CheckClient(client, "connect");
}

public void OnClientSettingsChanged(int client)
{
	CheckClient(client, "rename");
}

public void OnClientDisconnect(int client)
{
	g_lastLogged[client][0] = '\0';
}

void CheckClient(int client, const char[] via)
{
	if (!g_cEnable.BoolValue)
		return;
	if (client <= 0 || client > MaxClients)
		return;
	if (!IsClientConnected(client) || !IsClientInGame(client))
		return;
	if (IsFakeClient(client))
		return;

	char name[128];
	GetClientName(client, name, sizeof(name));

	char tag[64];
	g_cTag.GetString(tag, sizeof(tag));
	if (tag[0] == '\0' || StrContains(name, tag, false) == -1)
		return;

	// don't re-log the same exact name for the same client (avoids settings-change spam)
	if (StrEqual(name, g_lastLogged[client]))
		return;
	strcopy(g_lastLogged[client], sizeof(g_lastLogged[]), name);

	char steamid[32];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
		strcopy(steamid, sizeof(steamid), "STEAM_PENDING");

	bool whitelisted = false;
	AdminId aid = GetUserAdmin(client);
	if (aid != INVALID_ADMIN_ID)
		whitelisted = (GetAdminFlag(aid, Admin_Custom1) || GetAdminFlag(aid, Admin_Root));

	LogToFileEx(g_logPath, "name=\"%s\" steamid=%s whitelisted=%s via=%s", name, steamid, whitelisted ? "YES" : "NO", via);
}
