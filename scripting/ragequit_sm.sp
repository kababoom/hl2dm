#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

#define SND "ragequit/ragequit.mp3"
ConVar g_delay;
float g_death[MAXPLAYERS+1];

public Plugin myinfo = { name = "RageQuit", author = "HagenIT", description = "Sound + msg when a player rage-quits (ported from ES)", version = "1.1", url = "" };

public void OnPluginStart() {
    g_delay = CreateConVar("sm_ragequit_maxdelay", "10.0", "Max seconds death->disconnect to count as ragequit");
    HookEvent("player_death", Ev_Death);
    HookEvent("player_disconnect", Ev_Disc);
}
public void OnMapStart() {
    PrecacheSound(SND, true);
    AddFileToDownloadsTable("sound/ragequit/ragequit.mp3");
}
public void OnClientConnected(int c) { g_death[c] = 0.0; }
public void Ev_Death(Event e, const char[] n, bool db) {
    int v = GetClientOfUserId(e.GetInt("userid"));
    if (v >= 1 && v <= MaxClients && !IsFakeClient(v)) g_death[v] = GetGameTime();
}
public void Ev_Disc(Event e, const char[] n, bool db) {
    int c = GetClientOfUserId(e.GetInt("userid"));
    if (c < 1 || c > MaxClients) return;
    char reason[128]; e.GetString("reason", reason, sizeof reason);
    char nm[64]; e.GetString("name", nm, sizeof nm);
    bool recent = (g_death[c] > 0.0 && (GetGameTime() - g_death[c]) <= g_delay.FloatValue);
    bool manual = (StrContains(reason, "Client Disconnect", false) != -1 || StrContains(reason, "timed out", false) != -1 || StrContains(reason, "by user", false) != -1);
    if (recent) {
        LogMessage("[ragequit] %s disconnected %.1fs after death | reason=\"%s\" | manual=%d | FIRED=%d",
            nm, GetGameTime() - g_death[c], reason, manual, (recent && manual));
    }
    if (recent && manual) {
        PrintToChatAll("\x04%s\x01 RAGE-QUIT the server! \x04LOL", nm);
        EmitSoundToAll(SND);
    }
    g_death[c] = 0.0;
}
