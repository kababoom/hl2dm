#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* NetWatch — per-player connection-quality logger.
 * Samples every 30s: pings, packet loss, choke. Two log streams in
 * addons/sourcemod/logs/netwatch.log:
 *   FLAG    — a live sample over threshold (catch bad moments as they happen)
 *   SESSION — a per-player summary on disconnect (avg + peak), so you can spot
 *             who *consistently* runs high ping / loss / choke and decide whether
 *             it's a bad line or deliberate abuse — then act.
 * Real players only (bots skipped). Tune thresholds via the sm_netwatch_* cvars.
 */

#define SAMPLE 30.0

ConVar g_cEnable, g_cLoss, g_cChoke, g_cPing;
char g_logPath[PLATFORM_MAX_PATH];

int   g_n[MAXPLAYERS + 1];
float g_sumPing[MAXPLAYERS + 1];
float g_sumLoss[MAXPLAYERS + 1];
float g_sumChoke[MAXPLAYERS + 1];
int   g_peakPing[MAXPLAYERS + 1];
float g_peakLoss[MAXPLAYERS + 1];
float g_peakChoke[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name        = "NetWatch",
	author      = "HagenIT",
	description = "Logs per-player ping/loss/choke + session summaries to spot bad / high-ping-abuse connections",
	version     = "1.0",
	url         = ""
};

public void OnPluginStart()
{
	g_cEnable = CreateConVar("sm_netwatch_enable", "1",   "Enable netwatch logging (1/0)");
	g_cLoss   = CreateConVar("sm_netwatch_loss",   "3.0", "Flag a live sample if packet loss %% >= this");
	g_cChoke  = CreateConVar("sm_netwatch_choke",  "5.0", "Flag a live sample if choke %% >= this");
	g_cPing   = CreateConVar("sm_netwatch_ping",   "200", "Flag a live sample if ping (ms) >= this");
	BuildPath(Path_SM, g_logPath, sizeof(g_logPath), "logs/netwatch.log");
	AutoExecConfig(true, "netwatch");
	CreateTimer(SAMPLE, Timer_Sample, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int c) { Reset(c); }

void Reset(int c)
{
	g_n[c] = 0;
	g_sumPing[c] = 0.0; g_sumLoss[c] = 0.0; g_sumChoke[c] = 0.0;
	g_peakPing[c] = 0;  g_peakLoss[c] = 0.0; g_peakChoke[c] = 0.0;
}

public Action Timer_Sample(Handle t)
{
	if (!g_cEnable.BoolValue)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientConnected(i))
			continue;

		float loss  = GetClientAvgLoss(i, NetFlow_Incoming) * 100.0;
		float choke = GetClientAvgChoke(i, NetFlow_Outgoing) * 100.0;
		int   ping  = RoundToNearest(GetClientAvgLatency(i, NetFlow_Outgoing) * 1000.0);

		g_n[i]++;
		g_sumPing[i]  += float(ping);
		g_sumLoss[i]  += loss;
		g_sumChoke[i] += choke;
		if (ping  > g_peakPing[i])  g_peakPing[i]  = ping;
		if (loss  > g_peakLoss[i])  g_peakLoss[i]  = loss;
		if (choke > g_peakChoke[i]) g_peakChoke[i] = choke;

		if (loss >= g_cLoss.FloatValue || choke >= g_cChoke.FloatValue || ping >= g_cPing.IntValue)
		{
			char nm[MAX_NAME_LENGTH], sid[32];
			GetClientName(i, nm, sizeof(nm));
			if (!GetClientAuthId(i, AuthId_Steam2, sid, sizeof(sid))) strcopy(sid, sizeof(sid), "STEAM_PENDING");
			LogToFileEx(g_logPath, "FLAG    \"%s\" %s  ping=%dms loss=%.1f%% choke=%.1f%%", nm, sid, ping, loss, choke);
		}
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int c)
{
	if (IsFakeClient(c) || g_n[c] <= 0)
	{
		Reset(c);
		return;
	}
	char nm[MAX_NAME_LENGTH], sid[32];
	GetClientName(c, nm, sizeof(nm));
	if (!GetClientAuthId(c, AuthId_Steam2, sid, sizeof(sid))) strcopy(sid, sizeof(sid), "STEAM_PENDING");
	float n = float(g_n[c]);
	LogToFileEx(g_logPath, "SESSION \"%s\" %s  avg ping=%dms loss=%.1f%% choke=%.1f%% | peak ping=%dms loss=%.1f%% choke=%.1f%% (%d samples / ~%dmin)",
		nm, sid,
		RoundToNearest(g_sumPing[c] / n), g_sumLoss[c] / n, g_sumChoke[c] / n,
		g_peakPing[c], g_peakLoss[c], g_peakChoke[c],
		g_n[c], RoundToNearest(n * SAMPLE / 60.0));
	Reset(c);
}
