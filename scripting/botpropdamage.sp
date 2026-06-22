#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

/* Bot Prop Damage
 * Makes BOTS take damage from gravity-gunned / thrown physics props.
 * The HL2DM engine applies physics-impact damage to real players but skips
 * fake clients, so bots shrug off thrown crates.
 *
 * Two detection paths (deduped by a per-prop cooldown):
 *   1. StartTouch  — precise, for props that actually register a collision.
 *   2. Path sweep  — every sample we measure each prop's speed from position
 *                    deltas (vphysics doesn't update m_vecAbsVelocity) and, for
 *                    fast props, test whether the segment it just travelled
 *                    passed through a bot. This catches fast punts that tunnel
 *                    through the hitbox in one tick (the "straight through" bug).
 *
 * Real players are intentionally NOT touched (engine already damages them).
 */

#define SAMPLE 0.1   // velocity sample interval (s)

ConVar g_cEnable, g_cMinSpeed, g_cDmgPer100, g_cMaxDmg, g_cCooldown, g_cRadius, g_cDebug;
float g_lastHit[2049];
bool  g_tracked[2049];
bool  g_primed[2049];
float g_pos[2049][3];
float g_speed[2049];
bool  g_isOrb[2049];

public Plugin myinfo =
{
	name        = "Bot Prop Damage",
	author      = "HagenIT",
	description = "Bots take damage from thrown physics props + AR2 orbs (engine skips fake clients)",
	version     = "1.3",
	url         = ""
};

public void OnPluginStart()
{
	g_cEnable    = CreateConVar("sm_botpropdmg_enable",   "1",   "Enable bot prop damage (1/0)");
	g_cMinSpeed  = CreateConVar("sm_botpropdmg_minspeed", "250", "Min prop speed (u/s) before it deals damage");
	g_cDmgPer100 = CreateConVar("sm_botpropdmg_dmgper100","15",  "Damage dealt per 100 u/s of prop speed");
	g_cMaxDmg    = CreateConVar("sm_botpropdmg_maxdamage","120", "Max damage per single hit");
	g_cCooldown  = CreateConVar("sm_botpropdmg_cooldown", "0.5", "Per-prop cooldown between hits (s)");
	g_cRadius    = CreateConVar("sm_botpropdmg_radius",   "45",  "Hit radius (u) of the path sweep around a bot");
	g_cDebug     = CreateConVar("sm_botpropdmg_debug",    "0",   "Log every prop->bot impact (1/0)");
	AutoExecConfig(true, "botpropdamage");

	CreateTimer(SAMPLE, Timer_TrackSpeed, _, TIMER_REPEAT);

	int e = -1;
	while ((e = FindEntityByClassname(e, "prop_physics*")) != -1)
		TrackProp(e);
}

void TrackProp(int e)
{
	if (e < 0 || e > 2048)
		return;
	SDKHook(e, SDKHook_StartTouch, OnPropTouch);
	g_tracked[e] = true;
	g_primed[e]  = false;
	g_speed[e]   = 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "prop_physics", false) == 0 || StrEqual(classname, "func_physbox", false))
		TrackProp(entity);
	else if (StrContains(classname, "combine_ball", false) != -1)
		HookOrb(entity);
}

public void OnEntityDestroyed(int entity)
{
	if (entity >= 0 && entity <= 2048)
	{
		g_tracked[entity] = false;
		g_primed[entity]  = false;
		g_speed[entity]   = 0.0;
		g_lastHit[entity] = 0.0;
		g_isOrb[entity]   = false;
	}
}

public Action Timer_TrackSpeed(Handle t)
{
	float minspeed = g_cMinSpeed.FloatValue;
	float radius   = g_cRadius.FloatValue;

	for (int e = MaxClients + 1; e <= 2048; e++)
	{
		if (!g_tracked[e])
			continue;
		if (!IsValidEntity(e))
		{
			g_tracked[e] = false;
			continue;
		}
		float cur[3];
		GetEntPropVector(e, Prop_Data, "m_vecAbsOrigin", cur);
		if (!g_primed[e])
		{
			g_pos[e] = cur;
			g_primed[e] = true;
			continue;
		}
		float prev[3];
		prev = g_pos[e];
		g_speed[e] = GetVectorDistance(prev, cur) / SAMPLE;
		g_pos[e] = cur;

		// path sweep: did this fast prop's travel segment pass through a bot?
		if (g_speed[e] >= minspeed)
		{
			for (int b = 1; b <= MaxClients; b++)
			{
				if (!IsClientInGame(b) || !IsPlayerAlive(b) || !IsFakeClient(b))
					continue;
				float bp[3];
				GetClientAbsOrigin(b, bp);
				bp[2] += 36.0; // feet -> torso centre
				if (DistPointSeg(prev, cur, bp) <= radius)
					ApplyHit(e, b, "sweep");
			}
		}
	}
	return Plugin_Continue;
}

public void OnPropTouch(int ent, int other)
{
	if (other < 1 || other > MaxClients)
		return;
	if (!IsClientInGame(other) || !IsPlayerAlive(other) || !IsFakeClient(other))
		return;
	if (g_isOrb[ent])
		ApplyOrbHit(ent, other);
	else
		ApplyHit(ent, other, "touch");
}

void ApplyHit(int prop, int bot, const char[] via)
{
	if (!g_cEnable.BoolValue)
		return;
	if (prop < 0 || prop > 2048)
		return;

	float speed = g_speed[prop];

	if (g_cDebug.BoolValue && speed >= 50.0)
		LogMessage("[botpropdmg] %s bot=%N speed=%.0f (min=%.0f)", via, bot, speed, g_cMinSpeed.FloatValue);

	if (speed < g_cMinSpeed.FloatValue)
		return;

	float now = GetGameTime();
	if (now - g_lastHit[prop] < g_cCooldown.FloatValue)
		return;
	g_lastHit[prop] = now;

	int attacker = 0;
	if (HasEntProp(prop, Prop_Data, "m_hPhysicsAttacker"))
		attacker = GetEntPropEnt(prop, Prop_Data, "m_hPhysicsAttacker");
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker))
		attacker = 0;

	float dmg = (speed / 100.0) * g_cDmgPer100.FloatValue;
	if (dmg > g_cMaxDmg.FloatValue)
		dmg = g_cMaxDmg.FloatValue;

	SDKHooks_TakeDamage(bot, prop, attacker, dmg, DMG_CRUSH, -1, NULL_VECTOR, NULL_VECTOR);

	if (g_cDebug.BoolValue)
		LogMessage("[botpropdmg] HIT(%s) bot=%N speed=%.0f dmg=%.0f attacker=%d", via, bot, speed, dmg, attacker);
}

float DistPointSeg(const float a[3], const float b[3], const float p[3])
{
	float ab[3], ap[3];
	SubtractVectors(b, a, ab);
	SubtractVectors(p, a, ap);
	float ab2 = GetVectorDotProduct(ab, ab);
	float t = (ab2 > 0.0) ? (GetVectorDotProduct(ap, ab) / ab2) : 0.0;
	if (t < 0.0) t = 0.0;
	else if (t > 1.0) t = 1.0;
	float closest[3];
	closest[0] = a[0] + ab[0] * t;
	closest[1] = a[1] + ab[1] * t;
	closest[2] = a[2] + ab[2] * t;
	return GetVectorDistance(closest, p);
}

void HookOrb(int e)
{
	if (e < 0 || e > 2048)
		return;
	SDKHook(e, SDKHook_StartTouch, OnPropTouch);
	SDKHook(e, SDKHook_Touch, OnPropTouch);
	g_isOrb[e] = true;
}

void ApplyOrbHit(int orb, int bot)
{
	if (!g_cEnable.BoolValue)
		return;
	if (orb < 0 || orb > 2048)
		return;
	float now = GetGameTime();
	if (now - g_lastHit[orb] < g_cCooldown.FloatValue)
		return;
	g_lastHit[orb] = now;

	int owner = 0;
	if (HasEntProp(orb, Prop_Send, "m_hOwnerEntity"))
		owner = GetEntPropEnt(orb, Prop_Send, "m_hOwnerEntity");
	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
		owner = 0;

	// orb contact = lethal dissolve (same as a real player takes), credited to the firer
	SDKHooks_TakeDamage(bot, orb, owner, 1000.0, DMG_DISSOLVE, -1, NULL_VECTOR, NULL_VECTOR);

	if (g_cDebug.BoolValue)
		LogMessage("[botpropdmg] ORB killed bot=%N owner=%d", bot, owner);
}
