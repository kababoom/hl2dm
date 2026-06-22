#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

#define MAXT 150
char g_trig[MAXT][64];
ArrayList g_snd[MAXT];
int g_count;
ConVar g_enable;

public Plugin myinfo = { name = "SaySounds", author = "HagenIT", description = "Chat-trigger sounds (ported from ES sh_say)", version = "1.0", url = "" };

public void OnPluginStart() {
    g_enable = CreateConVar("sm_saysounds_enable", "1", "Enable say sounds");
    AddCommandListener(OnSay, "say");
    AddCommandListener(OnSay, "say_team");
    LoadCfg();
}

void LoadCfg() {
    for (int i = 0; i < g_count; i++) if (g_snd[i] != null) { delete g_snd[i]; g_snd[i] = null; }
    g_count = 0;
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof path, "configs/saysounds.cfg");
    KeyValues kv = new KeyValues("SaySounds");
    if (!kv.ImportFromFile(path)) { delete kv; LogError("saysounds.cfg not found"); return; }
    if (kv.GotoFirstSubKey()) {
        do {
            kv.GetSectionName(g_trig[g_count], 64);
            for (int k = 0; g_trig[g_count][k]; k++) g_trig[g_count][k] = CharToLower(g_trig[g_count][k]);
            ArrayList list = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
            if (kv.GotoFirstSubKey(false)) {
                do {
                    char s[PLATFORM_MAX_PATH];
                    kv.GetString(NULL_STRING, s, sizeof s);
                    if (s[0]) list.PushString(s);
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
            g_snd[g_count] = list;
            g_count++;
        } while (kv.GotoNextKey() && g_count < MAXT);
    }
    delete kv;
    LogMessage("SaySounds loaded %d triggers", g_count);
}

public void OnMapStart() {
    for (int i = 0; i < g_count; i++) {
        int n = g_snd[i].Length;
        for (int j = 0; j < n; j++) {
            char s[PLATFORM_MAX_PATH]; g_snd[i].GetString(j, s, sizeof s);
            PrecacheSound(s, true);
            char dl[PLATFORM_MAX_PATH]; Format(dl, sizeof dl, "sound/%s", s);
            AddFileToDownloadsTable(dl);
        }
    }
}

public Action OnSay(int client, const char[] cmd, int args) {
    if (client < 1 || !g_enable.BoolValue) return Plugin_Continue;
    char msg[192]; GetCmdArgString(msg, sizeof msg);
    StripQuotes(msg); TrimString(msg);
    for (int i = 0; msg[i]; i++) msg[i] = CharToLower(msg[i]);
    for (int i = 0; i < g_count; i++) {
        if (StrEqual(msg, g_trig[i])) {
            int n = g_snd[i].Length;
            if (n > 0) {
                char s[PLATFORM_MAX_PATH];
                g_snd[i].GetString(GetRandomInt(0, n - 1), s, sizeof s);
                EmitSoundToAll(s);
            }
            return Plugin_Continue;
        }
    }
    return Plugin_Continue;
}
