#include <sourcemod>
#pragma semicolon 1
#pragma newdecls required

StringMap g_self, g_kill;
char g_defSelf[192], g_defKill[192];

public Plugin myinfo = { name = "DeathMessages", author = "HagenIT", description = "Custom kill-feed text (MacDGuy ES port)", version = "1.0", url = "" };

public void OnPluginStart() { HookEvent("player_death", Ev_Death); LoadCfg(); }

void LoadCfg() {
    if (g_self != null) delete g_self;
    if (g_kill != null) delete g_kill;
    g_self = new StringMap(); g_kill = new StringMap();
    strcopy(g_defSelf, sizeof g_defSelf, "%1 committed suicide");
    strcopy(g_defKill, sizeof g_defKill, "%2 killed %1");
    char path[PLATFORM_MAX_PATH]; BuildPath(Path_SM, path, sizeof path, "configs/deathmessages.cfg");
    KeyValues kv = new KeyValues("DeathMessages");
    if (!kv.ImportFromFile(path)) { delete kv; LogError("deathmessages.cfg missing"); return; }
    kv.GetString("default_self", g_defSelf, sizeof g_defSelf, g_defSelf);
    kv.GetString("default_kill", g_defKill, sizeof g_defKill, g_defKill);
    if (kv.JumpToKey("self")) {
        if (kv.GotoFirstSubKey(false)) {
            do { char w[64], t[192]; kv.GetSectionName(w, sizeof w); kv.GetString(NULL_STRING, t, sizeof t); g_self.SetString(w, t); } while (kv.GotoNextKey(false));
            kv.GoBack();
        }
        kv.GoBack();
    }
    if (kv.JumpToKey("kill")) {
        if (kv.GotoFirstSubKey(false)) {
            do { char w[64], t[192]; kv.GetSectionName(w, sizeof w); kv.GetString(NULL_STRING, t, sizeof t); g_kill.SetString(w, t); } while (kv.GotoNextKey(false));
            kv.GoBack();
        }
        kv.GoBack();
    }
    delete kv;
}
public void Ev_Death(Event e, const char[] n, bool db) {
    int vic = GetClientOfUserId(e.GetInt("userid"));
    int att = GetClientOfUserId(e.GetInt("attacker"));
    if (vic < 1 || vic > MaxClients) return;
    char weapon[64]; e.GetString("weapon", weapon, sizeof weapon);
    char vn[64]; GetClientName(vic, vn, sizeof vn);
    char msg[256];
    if (att < 1 || att == vic) {
        if (!g_self.GetString(weapon, msg, sizeof msg)) strcopy(msg, sizeof msg, g_defSelf);
        ReplaceString(msg, sizeof msg, "%1", vn);
    } else {
        char an[64]; GetClientName(att, an, sizeof an);
        if (!g_kill.GetString(weapon, msg, sizeof msg)) strcopy(msg, sizeof msg, g_defKill);
        ReplaceString(msg, sizeof msg, "%2", an);
        ReplaceString(msg, sizeof msg, "%1", vn);
    }
    PrintToChatAll("%s", msg);
}
