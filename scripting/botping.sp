#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

ConVar g_min, g_max, g_iv;
Handle g_timer = null;

public Plugin myinfo = { name = "Bot Ping", author = "HagenIT", description = "Fake ping on bots (ported from ES rg_botping)", version = "1.0", url = "" };

public void OnPluginStart() {
    g_min = CreateConVar("sm_botping_min", "50", "Min fake bot ping");
    g_max = CreateConVar("sm_botping_max", "75", "Max fake bot ping");
    g_iv  = CreateConVar("sm_botping_interval", "3.0", "Refresh interval seconds");
    g_iv.AddChangeHook(OnIvChanged);
    StartT();
}
void OnIvChanged(ConVar c, const char[] o, const char[] n) { StartT(); }
void StartT() {
    if (g_timer != null) { KillTimer(g_timer); g_timer = null; }
    float iv = g_iv.FloatValue; if (iv < 0.5) iv = 0.5;
    g_timer = CreateTimer(iv, Timer_Ping, _, TIMER_REPEAT);
}
public Action Timer_Ping(Handle t) {
    int res = GetPlayerResourceEntity();
    if (res < 1) return Plugin_Continue;
    int mn = g_min.IntValue, mx = g_max.IntValue;
    if (mx < mn) mx = mn;
    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && IsFakeClient(i))
            SetEntProp(res, Prop_Send, "m_iPing", GetRandomInt(mn, mx), _, i);
    return Plugin_Continue;
}
