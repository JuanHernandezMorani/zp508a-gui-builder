/*================================================================================
	
	--------------------------------
	-*- [ZP] Game Mode: plasma -*-
	--------------------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
================================================================================*/

#include <amxmodx>
#include <amx_settings_api>
#include <zp50_gamemodes>
#include <zp50_class_plasma>
#include <zp50_deathmatch>

// Settings file
new const ZP_SETTINGS_FILE[] = "zombieplague.ini"

// Default sounds
new const sound_plasma[][] = { "zombie_plague/survivor1.wav" , "zombie_plague/survivor2.wav" }

#define SOUND_MAX_LENGTH 64

new Array:g_sound_plasma

// HUD messages
#define HUD_EVENT_X -1.0
#define HUD_EVENT_Y 0.17
#define HUD_EVENT_R 20
#define HUD_EVENT_G 20
#define HUD_EVENT_B 255

new g_MaxPlayers
new g_HudSync
new g_TargetPlayer

new cvar_plasma_chance, cvar_plasma_min_players
new cvar_plasma_show_hud, cvar_plasma_sounds
new cvar_plasma_allow_respawn

public plugin_precache()
{
	// Register game mode at precache (plugin gets paused after this)
	register_plugin("[ZP] Game Mode: Plasma", ZP_VERSION_STRING, "ZP Dev Team")
	zp_gamemodes_register("Plasma Mode")
	
	// Create the HUD Sync Objects
	g_HudSync = CreateHudSyncObj()
	
	g_MaxPlayers = get_maxplayers()
	
	cvar_plasma_chance = register_cvar("zp_plasma_chance", "20")
	cvar_plasma_min_players = register_cvar("zp_plasma_min_players", "0")
	cvar_plasma_show_hud = register_cvar("zp_plasma_show_hud", "1")
	cvar_plasma_sounds = register_cvar("zp_plasma_sounds", "1")
	cvar_plasma_allow_respawn = register_cvar("zp_plasma_allow_respawn", "0")
	
	// Initialize arrays
	g_sound_plasma = ArrayCreate(SOUND_MAX_LENGTH, 1)
	
	// Load from external file
	amx_load_setting_string_arr(ZP_SETTINGS_FILE, "Sounds", "ROUND PLASMA", g_sound_plasma)
	
	// If we couldn't load custom sounds from file, use and save default ones
	new index
	if (ArraySize(g_sound_plasma) == 0)
	{
		for (index = 0; index < sizeof sound_plasma; index++)
			ArrayPushString(g_sound_plasma, sound_plasma[index])
		
		// Save to external file
		amx_save_setting_string_arr(ZP_SETTINGS_FILE, "Sounds", "ROUND PLASMA", g_sound_plasma)
	}
	
	// Precache sounds
	new sound[SOUND_MAX_LENGTH]
	for (index = 0; index < ArraySize(g_sound_plasma); index++)
	{
		ArrayGetString(g_sound_plasma, index, sound, charsmax(sound))
		if (equal(sound[strlen(sound)-4], ".mp3"))
		{
			format(sound, charsmax(sound), "sound/%s", sound)
			precache_generic(sound)
		}
		else
			precache_sound(sound)
	}
}

// Deathmatch module's player respawn forward
public zp_fw_deathmatch_respawn_pre(id)
{
	// Respawning allowed?
	if (!get_pcvar_num(cvar_plasma_allow_respawn))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public zp_fw_core_spawn_post(id)
{
	// Always respawn as zombie on plasma rounds
	zp_core_respawn_as_zombie(id, true)
}

public zp_fw_gamemodes_choose_pre(game_mode_id, skipchecks)
{
	if (!skipchecks)
	{
		// Random chance
		if (random_num(1, get_pcvar_num(cvar_plasma_chance)) != 1)
			return PLUGIN_HANDLED;
		
		// Min players
		if (GetAliveCount() < get_pcvar_num(cvar_plasma_min_players))
			return PLUGIN_HANDLED;
	}
	
	// Game mode allowed
	return PLUGIN_CONTINUE;
}

public zp_fw_gamemodes_choose_post(game_mode_id, target_player)
{
	// Pick player randomly?
	g_TargetPlayer = (target_player == RANDOM_TARGET_PLAYER) ? GetRandomAlive(random_num(1, GetAliveCount())) : target_player
}

public zp_fw_gamemodes_start()
{
	// Turn player into plasma
	zp_class_plasma_set(g_TargetPlayer)
	
	// Turn the remaining players into zombies
	new id
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		// Not alive
		if (!is_user_alive(id))
			continue;
		
		// plasma or already a zombie
		if (zp_class_plasma_get(id) || zp_core_is_zombie(id))
			continue;
		
		zp_core_infect(id)
	}
	
	// Play plasma sound
	if (get_pcvar_num(cvar_plasma_sounds))
	{
		new sound[SOUND_MAX_LENGTH]
		ArrayGetString(g_sound_plasma, random_num(0, ArraySize(g_sound_plasma) - 1), sound, charsmax(sound))
		PlaySoundToClients(sound)
	}
	
	if (get_pcvar_num(cvar_plasma_show_hud))
	{
		// Show plasma HUD notice
		new name[32]
		get_user_name(g_TargetPlayer, name, charsmax(name))
		set_hudmessage(HUD_EVENT_R, HUD_EVENT_G, HUD_EVENT_B, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
		ShowSyncHudMsg(0, g_HudSync, "%L", LANG_PLAYER, "NOTICE_PLASMA", name)
	}
}

// Plays a sound on clients
PlaySoundToClients(const sound[])
{
	if (equal(sound[strlen(sound)-4], ".mp3"))
		client_cmd(0, "mp3 play ^"sound/%s^"", sound)
	else
		client_cmd(0, "spk ^"%s^"", sound)
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

// Get Random Alive -returns index of alive player number target_index -
GetRandomAlive(target_index)
{
	new iAlive, id
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
		
		if (iAlive == target_index)
			return id;
	}
	
	return -1;
}