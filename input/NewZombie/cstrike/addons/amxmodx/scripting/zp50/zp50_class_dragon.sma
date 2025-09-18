/*===============================================================================
	
	---------------------------
	-*- [ZP] Class: Dragon -*-
	---------------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
================================================================================*/

#include <amxmodx>
#include <fun>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <amx_settings_api>
#include <cs_maxspeed_api>
#include <cs_player_models_api>
#include <zp50_colorchat>
#include <cs_weap_models_api>
#include <cs_ham_bots_api>
#include <zp50_core>
#define LIBRARY_GRENADE_FROST "zp50_grenade_frost"
#include <zp50_grenade_frost>
#define LIBRARY_GRENADE_FIRE "zp50_grenade_fire"
#include <zp50_grenade_fire>

// Settings file
new const ZP_SETTINGS_FILE[] = "zombieplague.ini"

// Default models
new const models_dragon_player[][] = { "zombie_source" }
new const models_dragon_claw[][] = { "models/zombie_plague/v_knife_zombie.mdl" }
new const CVAR_DRAGONFLY_SPEED[]  = "zp_dragon_fly_speed"

#define PLAYERMODEL_MAX_LENGTH 32
#define MODEL_MAX_LENGTH 64

// Custom models
new Array:g_models_dragon_player
new Array:g_models_dragon_claw

#define TASK_AURA 100
#define ID_AURA (taskid - TASK_AURA)

#define flag_get(%1,%2) (%1 & (1 << (%2 & 31)))
#define flag_get_boolean(%1,%2) (flag_get(%1,%2) ? true : false)
#define flag_set(%1,%2) %1 |= (1 << (%2 & 31))
#define flag_unset(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_MaxPlayers
new g_IsDragon

new cvar_dragon_health, cvar_dragon_base_health, cvar_dragon_speed, cvar_dragon_gravity
new cvar_dragon_glow
new cvar_dragon_aura, cvar_dragon_aura_color_R, cvar_dragon_aura_color_G, cvar_dragon_aura_color_B
new cvar_dragon_damage, cvar_dragon_kill_explode
new cvar_dragon_grenade_frost, cvar_dragon_grenade_fire

//new arrays for freez ability
new frostsprite, pcvar_dragon_freez_distance, pcvar_dragon_freez_cooldown, pcvar_dragon_freez_time
new Bloqueado[33]
new Float:gLastUseCmd[ 33 ]

public plugin_init()
{
	register_plugin("[ZP] Class: Dragon", ZP_VERSION_STRING, "ZP Dev Team")
	
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHamBots(Ham_TakeDamage, "fw_TakeDamage")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	RegisterHamBots(Ham_Killed, "fw_PlayerKilled")
	register_forward(FM_ClientDisconnect, "fw_ClientDisconnect_Post", 1)
	register_forward(FM_CmdStart, "fw_Start")
	
	g_MaxPlayers = get_maxplayers()
	
	cvar_dragon_health = register_cvar("zp_dragon_health", "0")
	cvar_dragon_base_health = register_cvar("zp_dragon_base_health", "2000")
	cvar_dragon_speed = register_cvar("zp_dragon_speed", "1.05")
	cvar_dragon_gravity = register_cvar("zp_dragon_gravity", "0.5")
	cvar_dragon_glow = register_cvar("zp_dragon_glow", "1")
	cvar_dragon_aura = register_cvar("zp_dragon_aura", "1")
	cvar_dragon_aura_color_R = register_cvar("zp_dragon_aura_color_R", "150")
	cvar_dragon_aura_color_G = register_cvar("zp_dragon_aura_color_G", "0")
	cvar_dragon_aura_color_B = register_cvar("zp_dragon_aura_color_B", "0")
	cvar_dragon_damage = register_cvar("zp_dragon_damage", "2.0")
	cvar_dragon_kill_explode = register_cvar("zp_dragon_kill_explode", "1")
	cvar_dragon_grenade_frost = register_cvar("zp_dragon_grenade_frost", "0")
	cvar_dragon_grenade_fire = register_cvar("zp_dragon_grenade_fire", "1")
	register_cvar(CVAR_DRAGONFLY_SPEED    , "300")
	pcvar_dragon_freez_distance = register_cvar("zp_dragon_freez_distance", "1000")
	pcvar_dragon_freez_cooldown = register_cvar("zp_dragon_freez_cooldown", "10.0")
	pcvar_dragon_freez_time = register_cvar("zp_dragon_freez_time", "5.0")
                
}

public plugin_precache()
{
	// Initialize arrays
	g_models_dragon_player = ArrayCreate(PLAYERMODEL_MAX_LENGTH, 1)
	g_models_dragon_claw = ArrayCreate(MODEL_MAX_LENGTH, 1)
	
	// Load from external file
	amx_load_setting_string_arr(ZP_SETTINGS_FILE, "Player Models", "DRAGON", g_models_dragon_player)
	amx_load_setting_string_arr(ZP_SETTINGS_FILE, "Weapon Models", "V_KNIFE DRAGON", g_models_dragon_claw)
	
	// If we couldn't load from file, use and save default ones
	new index
	if (ArraySize(g_models_dragon_player) == 0)
	{
		for (index = 0; index < sizeof models_dragon_player; index++)
			ArrayPushString(g_models_dragon_player, models_dragon_player[index])
		
		// Save to external file
		amx_save_setting_string_arr(ZP_SETTINGS_FILE, "Player Models", "DRAGON", g_models_dragon_player)
	}
	if (ArraySize(g_models_dragon_claw) == 0)
	{
		for (index = 0; index < sizeof models_dragon_claw; index++)
			ArrayPushString(g_models_dragon_claw, models_dragon_claw[index])
		
		// Save to external file
		amx_save_setting_string_arr(ZP_SETTINGS_FILE, "Weapon Models", "V_KNIFE DRAGON", g_models_dragon_claw)
	}
	
	// Precache models
	new player_model[PLAYERMODEL_MAX_LENGTH], model[MODEL_MAX_LENGTH], model_path[128]
	for (index = 0; index < ArraySize(g_models_dragon_player); index++)
	{
		ArrayGetString(g_models_dragon_player, index, player_model, charsmax(player_model))
		formatex(model_path, charsmax(model_path), "models/player/%s/%s.mdl", player_model, player_model)
		precache_model(model_path)
		// Support modelT.mdl files
		formatex(model_path, charsmax(model_path), "models/player/%s/%sT.mdl", player_model, player_model)
		if (file_exists(model_path)) precache_model(model_path)
	}
	for (index = 0; index < ArraySize(g_models_dragon_claw); index++)
	{
		ArrayGetString(g_models_dragon_claw, index, model, charsmax(model))
		precache_model(model)
		frostsprite = precache_model( "sprites/frost_explode.spr" )
	}
}

public plugin_natives()
{
	register_library("zp50_class_dragon")
	register_native("zp_class_dragon_get", "native_class_dragon_get")
	register_native("zp_class_dragon_set", "native_class_dragon_set")
	register_native("zp_class_dragon_get_count", "native_class_dragon_get_count")
	
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
	if (flag_get(g_IsDragon, id))
	{
		// Remove dragon glow
		if (get_pcvar_num(cvar_dragon_glow))
			set_user_rendering(id)
		
		// Remove dragon aura
		if (get_pcvar_num(cvar_dragon_aura))
			remove_task(id+TASK_AURA)
	}
}



public fw_ClientDisconnect_Post(id)
{
	// Reset flags AFTER disconnect (to allow checking if the player was dragon before disconnecting)
	flag_unset(g_IsDragon, id)
}

public zp_user_infected_post(player, infector)
{
    if(flag_get(g_IsDragon, player))
    {
        zp_colored_print( player, " Press ^x04[R]^x01 to Freez humans!, Hold ^x04[Jump]^x01 to fly!" )
    }
}



public use_cmd(player)
{
    
    if(!flag_get(g_IsDragon, player))
        return PLUGIN_HANDLED
    
    if( get_gametime( ) - gLastUseCmd[ player ] < get_pcvar_float( pcvar_dragon_freez_cooldown ) )
        return PLUGIN_HANDLED
    
    
    gLastUseCmd[ player ] = get_gametime( )
    
    new target, body
    get_user_aiming( player, target, body, get_pcvar_num( pcvar_dragon_freez_distance ) )
    
    if( is_user_alive( target ) && !zp_core_is_zombie( target ) )
    {
        sprite_control( player )
        zp_grenade_frost_set( target, true )
        Bloqueado[target] = true
        set_task( get_pcvar_float( pcvar_dragon_freez_time ), "unfrozen_user", target )
    }
    else
    {
        sprite_control( player )
    }
    return PLUGIN_HANDLED
}

public unfrozen_user( target )
{
    zp_grenade_frost_set( target, false )
    Bloqueado[target] = false
}


public te_spray( args[ ] )
{
    message_begin( MSG_BROADCAST,SVC_TEMPENTITY )
    write_byte( 120 ) // Throws a shower of sprites or models
    write_coord( args[ 0 ] ) // start pos
    write_coord( args[ 1 ] )
    write_coord( args[ 2 ] )
    write_coord( args[ 3 ] ) // velocity
    write_coord( args[ 4 ] )
    write_coord( args[ 5 ] )
    write_short( frostsprite ) // spr
    write_byte( 8 ) // count
    write_byte( 70 ) // speed
    write_byte( 100 ) //(noise)
    write_byte( 5 ) // (rendermode)
    message_end( )
    
    return PLUGIN_CONTINUE
}

public sqrt( num )
{
    new div = num
    new result = 1
    while( div > result )
    {
        div = ( div + result ) / 2
        result = num / div
    }
    return div
}


public sprite_control( player )
{
    new vec[ 3 ]
    new aimvec[ 3 ]
    new velocityvec[ 3 ]
    new length
    new speed = 10
    
    get_user_origin( player, vec )
    get_user_origin( player, aimvec, 2 )
    
    velocityvec[ 0 ] = aimvec[ 0 ] - vec[ 0 ]
    velocityvec[ 1 ] = aimvec[ 1 ] - vec[ 1 ]
    velocityvec[ 2 ] = aimvec[ 2 ] - vec[ 2 ]
    length = sqrt( velocityvec[ 0 ] * velocityvec[ 0 ] + velocityvec[ 1 ] * velocityvec[ 1 ] + velocityvec[ 2 ] * velocityvec[ 2 ] )
    velocityvec[ 0 ] = velocityvec[ 0 ] * speed / length
    velocityvec[ 1 ] = velocityvec[ 1 ] * speed / length
    velocityvec[ 2 ] = velocityvec[ 2 ] * speed / length
    
    new args[ 8 ]
    args[ 0 ] = vec[ 0 ]
    args[ 1 ] = vec[ 1 ]
    args[ 2 ] = vec[ 2 ]
    args[ 3 ] = velocityvec[ 0 ]
    args[ 4 ] = velocityvec[ 1 ]
    args[ 5 ] = velocityvec[ 2 ]
    
    set_task( 0.1, "te_spray", 0, args, 8, "a", 2 )
    
}



public fw_Start(id, uc_handle, seed)
{
    new button = get_uc(uc_handle,UC_Buttons)
    
    if(Bloqueado[id] && !zp_core_is_zombie(id) && (button & IN_ATTACK || button & IN_ATTACK2))
        set_uc(uc_handle,UC_Buttons,(button & ~IN_ATTACK) & ~IN_ATTACK2)
    
    if((button & IN_RELOAD))
        use_cmd(id)
}  


public client_putinserver(id)
{
	if(is_user_connected(id))
	{
		set_task(5.0, "unfrozen_user", id)
	}
}

// Ham Take Damage Forward
public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	// Non-player damage or self damage
	if (victim == attacker || !is_user_alive(attacker))
		return HAM_IGNORED;
	
	// Dragon attacking human
	if (flag_get(g_IsDragon, attacker) && !zp_core_is_zombie(victim))
	{
		// Ignore dragon damage override if damage comes from a 3rd party entity
		// (to prevent this from affecting a sub-plugin's rockets e.g.)
		if (inflictor == attacker)
		{
			// Set dragon damage
			SetHamParamFloat(4, damage * get_pcvar_float(cvar_dragon_damage))
			return HAM_HANDLED;
		}
	}
	
	return HAM_IGNORED;
}

// Ham Player Killed Forward
public fw_PlayerKilled(victim, attacker, shouldgib)
{
	if (flag_get(g_IsDragon, victim))
	{
		// Dragon explodes!
		if (get_pcvar_num(cvar_dragon_kill_explode))
			SetHamParamInteger(3, 2)
		
		// Remove dragon aura
		if (get_pcvar_num(cvar_dragon_aura))
			remove_task(victim+TASK_AURA)
	}
}



public client_PreThink(id) 
{
	if(!flag_get(g_IsDragon, id)) return PLUGIN_CONTINUE
	
	
	new Float:fAim[3] , Float:fVelocity[3];
	VelocityByAim(id , get_cvar_num(CVAR_DRAGONFLY_SPEED) , fAim);
	
	if((get_user_button(id) & IN_JUMP))
	{
		fVelocity[0] = fAim[0];
		fVelocity[1] = fAim[1];
		fVelocity[2] = fAim[2];

		set_user_velocity(id , fVelocity);
	}
	return PLUGIN_CONTINUE;
}


public zp_fw_grenade_frost_pre(id)
{
	// Prevent frost for Dragon
	if (flag_get(g_IsDragon, id) && !get_pcvar_num(cvar_dragon_grenade_frost))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public zp_fw_grenade_fire_pre(id)
{
	// Prevent burning for Dragon
	if (flag_get(g_IsDragon, id) && !get_pcvar_num(cvar_dragon_grenade_fire))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public zp_fw_core_spawn_post(id)
{
	if (flag_get(g_IsDragon, id))
	{
		// Remove dragon glow
		if (get_pcvar_num(cvar_dragon_glow))
			set_user_rendering(id)
		
		// Remove dragon aura
		if (get_pcvar_num(cvar_dragon_aura))
			remove_task(id+TASK_AURA)
		
		// Remove dragon flag
		flag_unset(g_IsDragon, id)
	}
}

public zp_fw_core_cure(id, attacker)
{
	if (flag_get(g_IsDragon, id))
	{
		// Remove dragon glow
		if (get_pcvar_num(cvar_dragon_glow))
			set_user_rendering(id)
		
		// Remove dragon aura
		if (get_pcvar_num(cvar_dragon_aura))
			remove_task(id+TASK_AURA)
		
		// Remove dragon flag
		flag_unset(g_IsDragon, id)
	}
}

public zp_fw_core_infect_post(id, attacker)
{
	// Apply dragon attributes?
	if (!flag_get(g_IsDragon, id))
		return;
	
	// Health
	if (get_pcvar_num(cvar_dragon_health) == 0)
		set_user_health(id, get_pcvar_num(cvar_dragon_base_health) * GetAliveCount())
	else
		set_user_health(id, get_pcvar_num(cvar_dragon_health))
	
	// Gravity
	set_user_gravity(id, get_pcvar_float(cvar_dragon_gravity))
	
	// Speed
	cs_set_player_maxspeed_auto(id, get_pcvar_float(cvar_dragon_speed))
	
	// Apply dragon player model
	new player_model[PLAYERMODEL_MAX_LENGTH]
	ArrayGetString(g_models_dragon_player, random_num(0, ArraySize(g_models_dragon_player) - 1), player_model, charsmax(player_model))
	cs_set_player_model(id, player_model)
	
	// Apply dragon claw model
	new model[MODEL_MAX_LENGTH]
	ArrayGetString(g_models_dragon_claw, random_num(0, ArraySize(g_models_dragon_claw) - 1), model, charsmax(model))
	cs_set_player_view_model(id, CSW_KNIFE, model)	
	
	// Dragon glow
	if (get_pcvar_num(cvar_dragon_glow))
		set_user_rendering(id, kRenderFxGlowShell, 0, 50, 200, kRenderNormal, 25)
	
	// Dragon aura task
	if (get_pcvar_num(cvar_dragon_aura))
		set_task(0.1, "dragon_aura", id+TASK_AURA, _, _, "b")
}

public native_class_dragon_get(plugin_id, num_params)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id)
		return -1;
	}
	
	return flag_get_boolean(g_IsDragon, id);
}

public native_class_dragon_set(plugin_id, num_params)
{
	new id = get_param(1)
	
	if (!is_user_alive(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id)
		return false;
	}
	
	if (flag_get(g_IsDragon, id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Player already a dragon (%d)", id)
		return false;
	}
	
	flag_set(g_IsDragon, id)
	zp_core_force_infect(id)
	return true;
}

public native_class_dragon_get_count(plugin_id, num_params)
{
	return GetDragonCount();
}

// Dragon aura task
public dragon_aura(taskid)
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
	write_byte(get_pcvar_num(cvar_dragon_aura_color_R)) // r
	write_byte(get_pcvar_num(cvar_dragon_aura_color_G)) // g
	write_byte(get_pcvar_num(cvar_dragon_aura_color_B)) // b
	write_byte(2) // life
	write_byte(0) // decay rate
	message_end()
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

// Get Dragon Count -returns alive dragon number-
GetDragonCount()
{
	new iDragon, id
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (is_user_alive(id) && flag_get(g_IsDragon, id))
			iDragon++
	}
	
	return iDragon;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ fbidis\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ ltrpar\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
