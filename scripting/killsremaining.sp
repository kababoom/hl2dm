#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

ConVar g_frag;
bool g_fired[3];
int  g_thresh[3] = { 10, 5, 1 };
char g_snd[3][48] = { "killremain/killsremain 10.mp3", "killremain/killsremain 5.mp3", "killremain/killsremain 1.mp3" };
char g_msg[3][32] = { "10 kills remaining", "5 kills remaining", "1 KILL REMAINING!" };

public Plugin myinfo = { name = "Kills Remaining", author = "HagenIT", description = "Announces 10/5/1 kills left (ES kill_cd port)", version = "1.0", url = "" };

public void OnPluginStart() {
    g_frag = FindConVar("mp_fraglimit");
    HookEvent("player_death", Ev_Death);
}
public void OnMapStart() {
    for (int i = 0; i < 3; i++) {
        PrecacheSound(g_snd[i], true);
        char dl[PLATFORM_MAX_PATH]; Format(dl, sizeof dl, "sound/%s", g_snd[i]);
        AddFileToDownloadsTable(dl);
        g_fired[i] = false;
    }
}
public void Ev_Death(Event e, const char[] n, bool db) {
    if (g_frag == null) return;
    int fl = g_frag.IntValue;
    if (fl <= 0) return;
    int att = GetClientOfUserId(e.GetInt("attacker"));
    if (att < 1 || att > MaxClients || !IsClientInGame(att)) return;
    int remaining = fl - GetClientFrags(att);
    for (int i = 0; i < 3; i++)
        if (remaining == g_thresh[i] && !g_fired[i]) {
            EmitSoundToAll(g_snd[i]);
            PrintCenterTextAll("%s", g_msg[i]);
            g_fired[i] = true;
        }
}
