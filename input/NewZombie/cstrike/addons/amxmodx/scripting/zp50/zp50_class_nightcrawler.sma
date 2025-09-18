/*================================================================================
	
	---------------------------
	-*- [ZP] Class: Nightcrawler -*-
	---------------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
===============================================================================*/

#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <xs>
#include <amx_settings_api>
#include <cs_maxspeed_api>
#include <cs_player_models_api>
#include <cs_weap_models_api>
#include <cs_ham_bots_api>
#include <zp50_core>
#define LIBRARY_GRENADE_FROST "zp50_grenade_frost"
#include <zp50_grenade_frost>
#define LIBRARY_GRENADE_FIRE "zp50_grenade_fire"
#include <zp50_grenade_fire>
#include <zp50_colorchat>

// Settings file
new const ZP_SETTINGS_FILE[] = "zombieplague.ini"

// Default models
new const models_nightcrawler_player[][] = { "zombie_source" }
new const models_nightcrawler_claw[][] = { "models/zombie_plague/v_knife_zombie.mdl" }
new const SOUND_TELEPORT[] = { "nc_teleport.wav" }
#define P_CLAW "models/p_nightcrawler.mdl"

#define PLAYERMODEL_MAX_LENGTH 32
#define MODEL_MAX_LENGTH 64
#define OFFSET_WEAPONOWNER 41
#define OFFSET_LINUX_WEAPONS 4
#define PDATA_SAFE 2

// Custom models
new Array:g_models_nightcrawler_player
new Array:g_models_nightcrawler_claw

#define TASK_AURA 100
#define ID_AURA (taskid - TASK_AURA)

#define flag_get(%1,%2) (%1 & (1 << (%2 & 31)))
#define flag_get_boolean(%1,%2) (flag_get(%1,%2) ? true : false)
#define flag_set(%1,%2) %1 |= (1 << (%2 & 31))
#define flag_unset(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_MaxPlayers
new g_IsNightcrawler
new Float:g_wallorigin[32][3]
new g_LimitTeleport[33]
new Float:g_flNextBlink[33]

new cvar_crawler_health, cvar_crawler_base_health, cvar_crawler_speed, cvar_crawler_gravity
new cvar_crawler_glow
new cvar_crawler_aura, cvar_crawler_aura_color_R, cvar_crawler_aura_color_G, cvar_crawler_aura_color_B
new cvar_crawler_damage, cvar_crawler_kill_explode
new cvar_crawler_grenade_frost, cvar_crawler_grenade_fire, cvar_crawler_teleport_limit, cvar_crawler_teleport_cooldown, cvar_crawler_teleport_range, cvar_crawler_invisiblity_amount

public plugin_init()
{
	register_plugin("[ZP] Class: NightCrawler", ZP_VERSION_STRING, "ZP Dev Team")
	
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHamBots(Ham_TakeDamage, "fw_TakeDamage")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHamBots(Ham_Killed, "fw_PlayerKilled")
	register_forward(FM_ClientDisconnect, "fw_ClientDisconnect_Post", 1)
	register_forward(FM_Touch, "fwd_touch")
	register_forward(FM_PlayerPreThink, "fwd_playerprethink")
	register_forward(FM_CmdStart, "OnNightCrawlerCMD")
	
	g_MaxPlayers = get_maxplayers()
	
	cvar_crawler_health = register_cvar("zp_nightcrawler_health", "0")
	cvar_crawler_base_health = register_cvar("zp_nightcrawler_base_health", "2000")
	cvar_crawler_speed = register_cvar("zp_nightcrawler_speed", "1.05")
	cvar_crawler_gravity = register_cvar("zp_nightcrawler_gravity", "0.5")
	cvar_crawler_glow = register_cvar("zp_nightcrawler_glow", "1")
	cvar_crawler_aura = register_cvar("zp_nightcrawler_aura", "1")
	cvar_crawler_aura_color_R = register_cvar("zp_nightcrawler_aura_color_R", "150")
	cvar_crawler_aura_color_G = register_cvar("zp_nightcrawler_aura_color_G", "0")
	cvar_crawler_aura_color_B = register_cvar("zp_nightcrawler_aura_color_B", "0")
	cvar_crawler_damage = register_cvar("zp_nightcrawler_damage", "2.0")
	cvar_crawler_kill_explode = register_cvar("zp_nightcrawler_kill_explode", "1")
	cvar_crawler_grenade_frost = register_cvar("zp_nightcrawler_grenade_frost", "0")
	cvar_crawler_grenade_fire = register_cvar("zp_nightcrawler_grenade_fire", "1")
	cvar_crawler_invisiblity_amount = register_cvar("zp_nightcrawler_invisiblity_amount", "15")
	cvar_crawler_teleport_limit = register_cvar("zp_nightcrawler_teleport_limit", "3")
	cvar_crawler_teleport_cooldown = register_cvar("zp_nightcrawler_teleport_cooldown", "10.0")
	cvar_crawler_teleport_range = register_cvar("zp_nightcrawler_teleport_range", "2000")
}

public plugin_precache()
{
	// Initialize arrays
	g_models_nightcrawler_player = ArrayCreate(PLAYERMODEL_MAX_LENGTH, 1)
	g_models_nightcrawler_claw = ArrayCreate(MODEL_MAX_LENGTH, 1)
	
	// Load from external file
	amx_load_setting_string_arr(ZP_SETTINGS_FILE, "Player Models", "NIGHTCRAWLER", g_models_nightcrawler_player)
	amx_load_setting_string_arr(ZP_SETTINGS_FILE, "Weapon Models", "V_KNIFE NIGHTCRAWLER", g_models_nightcrawler_claw)
	
	// If we couldn't load from file, use and save default ones
	new index
	if (ArraySize(g_models_nightcrawler_player) == 0)
	{
		for (index = 0; index < sizeof models_nightcrawler_player; index++)
			ArrayPushString(g_models_nightcrawler_player, models_nightcrawler_player[index])
		
		// Save to external file
		amx_save_setting_string_arr(ZP_SETTINGS_FILE, "Player Models", "NIGHTCRAWLER", g_models_nightcrawler_player)
	}
	if (ArraySize(g_models_nightcrawler_claw) == 0)
	{
		for (index = 0; index < sizeof models_nightcrawler_claw; index++)
			ArrayPushString(g_models_nightcrawler_claw, models_nightcrawler_claw[index])
		
		// Save to external file
		amx_save_setting_string_arr(ZP_SETTINGS_FILE, "Weapon Models", "V_KNIFE NIGHTCRAWLER", g_models_nightcrawler_claw)
	}
	
	// Precache models
	new player_model[PLAYERMODEL_MAX_LENGTH], model[MODEL_MAX_LENGTH], model_path[128]
	for (index = 0; index < ArraySize(g_models_nightcrawler_player); index++)
	{
		ArrayGetString(g_models_nightcrawler_player, index, player_model, charsmax(player_model))
		formatex(model_path, charsmax(model_path), "models/player/%s/%s.mdl", player_model, player_model)
		precache_model(model_path)
		// Support modelT.mdl files
		formatex(model_path, charsmax(model_path), "models/player/%s/%sT.mdl", player_model, player_model)
		if (file_exists(model_path)) precache_model(model_path)
	}
	for (index = 0; index < ArraySize(g_models_nightcrawler_claw); index++)
	{
		ArrayGetString(g_models_nightcrawler_claw, index, model, charsmax(model))
		precache_model(model)
	}
	
	precache_sound(SOUND_TELEPORT)
	precache_model(P_CLAW)
}

public plugin_natives()
{
	register_library("zp50_class_nightcrawler")
	register_native("zp_class_nightcrawler_get", "native_class_crawler_get")
	register_native("zp_class_nightcrawler_set", "native_class_crawler_set")
	register_native("zp_class_nightcrawler_get_count", "native_class_crawler_get_count")
	
	set_module_filter("module_filter")
	set_native_filter("native_filter")
}
public module_filter(const module[])
{
	if (equal(module, LIBRARY_GRENADE_FROST) || equal(module, LIBRARY_GRENADE_FIRE))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}
public native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED;
		
	return PLUGIN_CONTINUE;
}

public client_disconnect(id)
{
	if (flag_get(g_IsNightcrawler, id))
	{
		// Remove nightcrawler glow
		if (get_pcvar_num(cvar_crawler_glow))
			set_user_rendering(id)
		
		// Remove nightcrawler aura
		if (get_pcvar_num(cvar_crawler_aura))
			remove_task(id+TASK_AURA)
	}
}

public fw_ClientDisconnect_Post(id)
{
	// Reset flags AFTER disconnect (to allow checking if the player was nightcrawler before disconnecting)
	flag_unset(g_IsNightcrawler, id)
}

// Ham Take Damage Forward
public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	// Non-player damage or self damage
	if (victim == attacker || !is_user_alive(attacker))
		return HAM_IGNORED;
	
	// Nightcrawler attacking human
	if(flag_get(g_IsNightcrawler, attacker) && !zp_core_is_zombie(victim))
	{
		// Ignore nightcrawler damage override if damage comes from a 3rd party entity
		// (to prevent this from affecting a sub-plugin's rockets e.g.)
		if (inflictor == attacker)
		{
			// Set nightcrawler damage
			SetHamParamFloat(4, damage * get_pcvar_float(cvar_crawler_damage))
			return HAM_HANDLED;
		}

	}

	if(flag_get(g_IsNightcrawler, victim) && !zp_core_is_zombie(attacker) && is_user_alive(attacker))
	{
		set_user_rendering(victim)
		set_task(1.3, "RestoreInvisiblity", victim)
	}

	
	return HAM_IGNORED;
}


public RestoreInvisiblity(id)
{
	if(!is_user_alive(id) || !flag_get(g_IsNightcrawler, id)) return;
	set_user_rendering(id, kRenderFxGlowShell, 20, 20, 20, kRenderTransAlpha, get_pcvar_num(cvar_crawler_invisiblity_amount))
}
	

// Ham Player Killed Forward
public fw_PlayerKilled(victim, attacker, shouldgib)
{
	if (flag_get(g_IsNightcrawler, victim))
	{
		// Nightcrawler explodes!
		if (get_pcvar_num(cvar_crawler_kill_explode))
			SetHamParamInteger(3, 2)
		
		// Remove nightcrawler aura
		if (get_pcvar_num(cvar_crawler_aura))
			remove_task(victim+TASK_AURA)

		g_LimitTeleport[victim] = 0
	}
}



public fwd_touch(id, world)
{
	if(!is_user_alive(id) || !flag_get(g_IsNightcrawler, id))
		return FMRES_IGNORED
		
	pev(id, pev_origin, g_wallorigin[id])

	return FMRES_IGNORED
}

public wallclimb(id, button)
{
	static Float:origin[3]
	pev(id, pev_origin, origin)

	if(get_distance_f(origin, g_wallorigin[id]) > 7.0)
		return FMRES_IGNORED  // if not near wall
	
	if(fm_get_entity_flags(id) & FL_ONGROUND)
		return FMRES_IGNORED
		
	if(button & IN_FORWARD)
	{
		static Float:velocity[3]
		velocity_by_aim(id, 120, velocity)
		fm_set_user_velocity(id, velocity)
	}
	else if(button & IN_BACK)
	{
		static Float:velocity[3]
		velocity_by_aim(id, -120, velocity)
		fm_set_user_velocity(id, velocity)
	}
	return FMRES_IGNORED
}	

public fwd_playerprethink(id) 
{
	if(!flag_get(g_IsNightcrawler, id)) 
		return FMRES_IGNORED
	
	new button = fm_get_user_button(id)
	
	if(button & IN_USE) //Use button = climb
		wallclimb(id, button)

	return FMRES_IGNORED
}


public OnNightCrawlerCMD(id, handle)
{
	if (!is_user_alive(id) || get_gametime() < g_flNextBlink[id] || !flag_get(g_IsNightcrawler, id)) return
	
	static button
	button = get_uc(handle, UC_Buttons)
	if (button & IN_RELOAD && g_LimitTeleport[id] < get_pcvar_num(cvar_crawler_teleport_limit))
	{
		
		if (teleport(id))
		{
			emit_sound(id, CHAN_STATIC, SOUND_TELEPORT, 1.0, ATTN_NORM, 0, PITCH_NORM)
			g_LimitTeleport[id]++
			zp_colored_print(id, "You have ^x04%d^x01 more Teleports!", get_pcvar_num(cvar_crawler_teleport_limit) - g_LimitTeleport[id])
			g_flNextBlink[id] = get_gametime() + get_pcvar_float(cvar_crawler_teleport_cooldown)
			
			remove_task(id)
			set_task(get_pcvar_float(cvar_crawler_teleport_cooldown), "show_blink", id)
		}
		else
		{
			g_flNextBlink[id] = get_gametime() + 1.0
			
			zp_colored_print(id, " Found no reliable teleportation position.")
		}
		
	}
}

public show_blink(id)
{
	if (!is_user_connected(id) || !flag_get(g_IsNightcrawler, id) || !is_user_alive(id) || (g_LimitTeleport[id] >= get_pcvar_num(cvar_crawler_teleport_limit))) return
	
	
	zp_colored_print(id, "Teleport ability is ready. Press ^x04[R]^x01 button.")
	zp_colored_print(id, "To climb the walls, Press ^x04[E]^x01 button.")
	
	
}


bool:teleport(id)
{
	new	Float:vOrigin[3], Float:vNewOrigin[3],
	Float:vNormal[3], Float:vTraceDirection[3],
	Float:vTraceEnd[3]
	
	pev(id, pev_origin, vOrigin)
	
	velocity_by_aim(id, get_pcvar_num(cvar_crawler_teleport_range), vTraceDirection)
	xs_vec_add(vTraceDirection, vOrigin, vTraceEnd)
	
	engfunc(EngFunc_TraceLine, vOrigin, vTraceEnd, DONT_IGNORE_MONSTERS, id, 0)
	
	new Float:flFraction
	get_tr2(0, TR_flFraction, flFraction)
	if (flFraction < 1.0)
	{
		get_tr2(0, TR_vecEndPos, vTraceEnd)
		get_tr2(0, TR_vecPlaneNormal, vNormal)
	}
	
	xs_vec_mul_scalar(vNormal, 40.0, vNormal) // do not decrease the 40.0
	xs_vec_add(vTraceEnd, vNormal, vNewOrigin)
	
	if (is_player_stuck(id, vNewOrigin))
		return false;
	
	emit_sound(id, CHAN_STATIC, SOUND_TELEPORT, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	engfunc(EngFunc_SetOrigin, id, vNewOrigin)
	
	
	
	return true;
}



public zp_fw_grenade_frost_pre(id)
{
	// Prevent frost for Nightcrawler
	if (flag_get(g_IsNightcrawler, id) && !get_pcvar_num(cvar_crawler_grenade_frost))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public zp_fw_grenade_fire_pre(id)
{
	// Prevent burning for Nightcrawler
	if (flag_get(g_IsNightcrawler, id) && !get_pcvar_num(cvar_crawler_grenade_fire))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public zp_fw_core_spawn_post(id)
{
	if (flag_get(g_IsNightcrawler, id))
	{
		// Remove nightcrawler glow
		if (get_pcvar_num(cvar_crawler_glow))
			set_user_rendering(id)
		
		// Remove nightcrawler aura
		if (get_pcvar_num(cvar_crawler_aura))
			remove_task(id+TASK_AURA)
		
		// Remove nightcrawler flag
		flag_unset(g_IsNightcrawler, id)
	}
}

public zp_fw_core_cure(id, attacker)
{
	if (flag_get(g_IsNightcrawler, id))
	{
		// Remove nightcrawler glow
		if (get_pcvar_num(cvar_crawler_glow))
			set_user_rendering(id)
		
		// Remove nightcrawler aura
		if (get_pcvar_num(cvar_crawler_aura))
			remove_task(id+TASK_AURA)
		
		// Remove nightcrawler flag
		flag_unset(g_IsNightcrawler, id)
	}
}

public zp_fw_core_infect_post(id, attacker)
{
	// Apply Nightcrawler attributes?
	if (!flag_get(g_IsNightcrawler, id))
		return;
	
	// Health
	if (get_pcvar_num(cvar_crawler_health) == 0)
		set_user_health(id, get_pcvar_num(cvar_crawler_base_health) * GetAliveCount())
	else
		set_user_health(id, get_pcvar_num(cvar_crawler_health))
	
	// Gravity
	set_user_gravity(id, get_pcvar_float(cvar_crawler_gravity))
	
	// Speed
	cs_set_player_maxspeed_auto(id, get_pcvar_float(cvar_crawler_speed))

	g_LimitTeleport[id] = 0
	
	// Apply nightcrawler player model
	new player_model[PLAYERMODEL_MAX_LENGTH]
	ArrayGetString(g_models_nightcrawler_player, random_num(0, ArraySize(g_models_nightcrawler_player) - 1), player_model, charsmax(player_model))
	cs_set_player_model(id, player_model)
	
	// Apply nightcrawler claw model
	new model[MODEL_MAX_LENGTH]
	ArrayGetString(g_models_nightcrawler_claw, random_num(0, ArraySize(g_models_nightcrawler_claw) - 1), model, charsmax(model))
	cs_set_player_view_model(id, CSW_KNIFE, model)	
	cs_set_player_weap_model(id, CSW_KNIFE, P_CLAW)
	
	// Nightcrawler glow
	if (get_pcvar_num(cvar_crawler_glow))
		set_user_rendering(id, kRenderFxGlowShell, 20, 20, 20, kRenderTransAlpha, get_pcvar_num(cvar_crawler_invisiblity_amount))
	
	// Nightcrawler aura task
	if (get_pcvar_num(cvar_crawler_aura))
		set_task(0.1, "nightcrawler_aura", id+TASK_AURA, _, _, "b")
}

public native_class_crawler_get(plugin_id, num_params)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id)
		return -1;
	}
	
	return flag_get_boolean(g_IsNightcrawler, id);
}

public native_class_crawler_set(plugin_id, num_params)
{
	new id = get_param(1)
	
	if (!is_user_alive(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id)
		return false;
	}
	
	if (flag_get(g_IsNightcrawler, id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Player already a nightcrawler (%d)", id)
		return false;
	}
	
	flag_set(g_IsNightcrawler, id)
	zp_core_force_infect(id)
	return true;
}

public native_class_crawler_get_count(plugin_id, num_params)
{
	return GetNightcrawlerCount();
}

// Nightcrawler aura task
public nightcrawler_aura(taskid)
{
	// Get player's origin
	static origin[3]
	get_user_origin(ID_AURA, origin)
	
	// Colored Aura
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_DLIGHT) // TE id
	write_coord(origin[0]) // x
	write_coord(origin[1]) // y
	write_coord(origin[2]) // z
	write_byte(20) // radius
	write_byte(get_pcvar_num(cvar_crawler_aura_color_R)) // r
	write_byte(get_pcvar_num(cvar_crawler_aura_color_G)) // g
	write_byte(get_pcvar_num(cvar_crawler_aura_color_B)) // b
	write_byte(2) // life
	write_byte(0) // decay rate
	message_end()
}


stock is_player_stuck(id, Float:originF[3])
{
	engfunc(EngFunc_TraceHull, originF, originF, 0, (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0)
	
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

// Get Alive Count -returns alive players number-
GetAliveCount()
{
	new iAlive, id
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
	}
	
	return iAlive;
}

// Get Nightcrawler Count -returns alive nightcrawler number-
GetNightcrawlerCount()
{
	new iNightcrawler, id
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (is_user_alive(id) && flag_get(g_IsNightcrawler, id))
			iNightcrawler++
	}
	
	return iNightcrawler;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ fbidis\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ ltrpar\\ lang1065\\ f0\\ fs16 \n\\ par }
*/
