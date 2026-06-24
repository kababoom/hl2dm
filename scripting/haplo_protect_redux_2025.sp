#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "2.4"

public Plugin myinfo = 
{
    name = "haplo_protect_redux_2025",
    author = "[S-UK] Haplo & Gemini",
    description = "Protects Humans from spawnkilling and while chatting near a wall.",
    version = PLUGIN_VERSION,
    url = ""
};

// ConVars
ConVar g_cvColor;
ConVar g_cvMoveThreshold;
ConVar g_cvChatProtectEnabled;
ConVar g_cvWallTime;

// Globals
int g_iOriginalHealth[MAXPLAYERS+1];
bool g_bSpawnGrace[MAXPLAYERS+1];
bool g_bIsSpawnProtected[MAXPLAYERS+1];
bool g_bIsWallProtected[MAXPLAYERS+1];
int g_iTimeLookingAtWall[MAXPLAYERS+1];

public void OnPluginStart()
{
    // --- ConVars ---
    g_cvColor = CreateConVar("sm_spawnprotect_color", "255 0 0 255", "Render color R G B A for spawn protection.");
    g_cvMoveThreshold = CreateConVar("sm_spawnprotect_move_threshold", "50.0", "How fast the player has to be moving to lose spawn protection.");
    g_cvChatProtectEnabled = CreateConVar("sm_chatprotect_enabled", "1", "Enable/disable chat protection.");
    g_cvWallTime = CreateConVar("sm_chatprotect_wall_time", "3", "Time in seconds a player must face a wall to get chat protection.");
    
    AutoExecConfig(true, "haplo_protect_redux_2025");
    
    // --- Timers ---
    CreateTimer(1.0, Timer_CheckWall, _, TIMER_REPEAT);
    
    // --- Hooks & Init ---
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
            g_bSpawnGrace[i] = false;
            g_bIsSpawnProtected[i] = false;
            g_bIsWallProtected[i] = false;
            g_iTimeLookingAtWall[i] = 0;
            // Clear any lingering god-mode/color left by a replaced protection plugin
            SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
            SetEntityRenderColor(i, 255, 255, 255, 255);
        }
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_SpawnPost, OnSpawnPost);
}

public void OnSpawnPost(int client)
{
    // IGNORE BOTS: Only protect real humans
    if (IsClientInGame(client) && IsPlayerAlive(client) && !IsFakeClient(client))
    {
        EnableSpawnProtection(client);
    }
}

// --- Timers ---

public Action Timer_RemoveGrace(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client))
    {
        g_bSpawnGrace[client] = false;
    }
    return Plugin_Stop;
}

public Action Timer_CheckWall(Handle timer)
{
    if (!g_cvChatProtectEnabled.BoolValue)
    {
        return Plugin_Continue;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
        {
            if (IsPlayerLookingAtWall(i))
            {
                g_iTimeLookingAtWall[i]++;
                if (g_iTimeLookingAtWall[i] >= g_cvWallTime.IntValue && !g_bIsSpawnProtected[i] && !g_bIsWallProtected[i])
                {
                    EnableWallProtection(i);
                }
            }
            else
            {
                g_iTimeLookingAtWall[i] = 0;
                if (g_bIsWallProtected[i])
                {
                    DisableProtection(i, "stopped looking at wall");
                }
            }
        }
    }
    return Plugin_Continue;
}

// --- Protection Logic ---

void EnableSpawnProtection(int client)
{
    g_bIsSpawnProtected[client] = true;
    EnableProtection(client, "spawn");
    
    // Set spawn grace period
    g_bSpawnGrace[client] = true;
    CreateTimer(0.5, Timer_RemoveGrace, GetClientUserId(client));
}

void EnableWallProtection(int client)
{
    g_bIsWallProtected[client] = true;
    EnableProtection(client, "chat");
}

void EnableProtection(int client, const char[] reason)
{
    // 1. Enable Godmode
    SetEntProp(client, Prop_Data, "m_takedamage", 0, 1); 
    
    // 2. Set Color
    int r, g, b, a;
    GetColor(g_cvColor, r, g, b, a);
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, r, g, b, a);
    
    // 3. Store health and set to 500
    g_iOriginalHealth[client] = GetClientHealth(client);
    SetEntityHealth(client, 500);
    
    PrintToChat(client, "\x04[Protect]\x01 You are now protected (%s).", reason);
}

void DisableProtection(int client, const char[] reason)
{
    if (!g_bIsSpawnProtected[client] && !g_bIsWallProtected[client])
    {
        return; // Not protected
    }

    // 1. Disable Godmode
    SetEntProp(client, Prop_Data, "m_takedamage", 2, 1); // 2 = DAMAGE_YES
    
    // 2. Restore Color
    SetEntityRenderColor(client, 255, 255, 255, 255);
    
    // 3. Restore health
    if (g_iOriginalHealth[client] > 0)
    {
        SetEntityHealth(client, g_iOriginalHealth[client]);
        g_iOriginalHealth[client] = 0;
    }
    
    g_bIsSpawnProtected[client] = false;
    g_bIsWallProtected[client] = false;
    
    PrintToChat(client, "\x04[Protect]\x01 Protection expired due to %s.", reason);
}

// --- Event Hooks ---

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (victim > 0 && victim <= MaxClients && IsClientInGame(victim))
    {
        if (g_bIsSpawnProtected[victim] || g_bIsWallProtected[victim])
        {
            if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && attacker != victim)
            {
                // Reflect damage
                SDKHooks_TakeDamage(attacker, inflictor, attacker, damage, damagetype);
            }
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (IsClientInGame(client) && IsPlayerAlive(client) && (g_bIsSpawnProtected[client] || g_bIsWallProtected[client]))
    {
        if (g_bSpawnGrace[client])
        {
            return Plugin_Continue;
        }

        if (buttons & IN_ATTACK)
        {
            DisableProtection(client, "shooting");
            return Plugin_Continue;
        }

        if (GetVectorLength(vel) > g_cvMoveThreshold.FloatValue)
        {
            DisableProtection(client, "movement");
        }
    }
    return Plugin_Continue;
}

// --- Helper Functions ---

bool IsPlayerLookingAtWall(int client)
{
    float vAngles[3], vStart[3], vEnd[3];
    GetClientEyeAngles(client, vAngles);
    GetClientEyePosition(client, vStart);
    
    float distance = 32.0; // How far to check for a wall
    vEnd[0] = vStart[0] + distance * Cosine(DegToRad(vAngles[0])) * Cosine(DegToRad(vAngles[1]));
    vEnd[1] = vStart[1] + distance * Cosine(DegToRad(vAngles[0])) * Sine(DegToRad(vAngles[1]));
    vEnd[2] = vStart[2] + -distance * Sine(DegToRad(vAngles[0]));

    TR_TraceRayFilter(vStart, vEnd, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_Simple, client);

    if (TR_DidHit(INVALID_HANDLE))
    {
        char sClassName[64];
        int hit_entity = TR_GetEntityIndex(INVALID_HANDLE);
        GetEdictClassname(hit_entity, sClassName, sizeof(sClassName));

        if (StrEqual(sClassName, "worldspawn"))
        {
            return true;
        }
    }
    
    return false;
}

public bool TraceFilter_Simple(int entity, int contentsMask, any data)
{
    if (entity == data)
    {
        return false;
    }
    return true;
}

void GetColor(ConVar cvar, int &r, int &g, int &b, int &a)
{
    char sColor[32];
    char sPieces[4][8];
    cvar.GetString(sColor, sizeof(sColor));
    ExplodeString(sColor, " ", sPieces, 4, 8);
    r = StringToInt(sPieces[0]);
    g = StringToInt(sPieces[1]);
    b = StringToInt(sPieces[2]);
    a = StringToInt(sPieces[3]);
}