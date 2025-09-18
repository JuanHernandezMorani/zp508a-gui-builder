/*===============================================================================
	
	---------------------------
	-*- [ZP] Admin Commands -*-
	---------------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
===============================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <hamsandwich>
#include <amx_settings_api>
#include <zp50_gamemodes>
#define LIBRARY_NEMESIS "zp50_class_nemesis"
#include <zp50_class_nemesis>
#define LIBRARY_ASSASSIN "zp50_class_assassin"
#include <zp50_class_assassin>
#define LIBRARY_DRAGON "zp50_class_dragon"
#include <zp50_class_dragon>
#define LIBRARY_NIGHTCRAWLER "zp50_class_nightcrawler"
#include <zp50_class_nightcrawler>
#define LIBRARY_SURVIVOR "zp50_class_survivor"
#include <zp50_class_survivor>
#define LIBRARY_SNIPER "zp50_class_sniper"
#include <zp50_class_sniper>
#define LIBRARY_KNIFER "zp50_class_knifer"
#include <zp50_class_knifer>
#define LIBRARY_PLASMA "zp50_class_plasma"
#include <zp50_class_plasma>
#include <zp50_colorchat>
#include <zp50_log>

// Settings file
new const ZP_SETTINGS_FILE[] = "zombieplague.ini"

#define ACCESSFLAG_MAX_LENGTH 2

// Access flags
new g_access_make_zombie[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_human[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_respawn_players[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_nemesis[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_assassin[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_dragon[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_nightcrawler[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_survivor[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_sniper[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_knifer[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_plasma[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_start_game_mode[ACCESSFLAG_MAX_LENGTH] = "d"

new g_MaxPlayers
new g_GameModeInfectionID, g_GameModeNemesisID, g_GameModeAssassinID, g_GameModeDragonID, g_GameModeNightcrawlerID, g_GameModeSurvivorID, g_GameModeSniperID, g_GameModeKniferID, g_GameModePlasmaID

new cvar_amx_show_activity
new cvar_deathmatch
new cvar_log_admin_commands

public plugin_init()
{
	register_plugin("[ZP] Admin Commands", ZP_VERSION_STRING, "ZP Dev Team")
	
	// Admin commands
	register_concmd("zp_zombie", "cmd_zombie", _, "<target> - Turn someone into a Zombie", 0)
	register_concmd("zp_human", "cmd_human", _, "<target> - Turn someone back to Human", 0)
	register_concmd("zp_respawn", "cmd_respawn", _, "<target> - Respawn someone", 0)
	register_concmd("zp_start_game_mode", "cmd_start_game_mode", _, "<game mode id> - Start specific game mode", 0)
	
	// Nemesis Class loaded?
	if (LibraryExists(LIBRARY_NEMESIS, LibType_Library))
		register_concmd("zp_nemesis", "cmd_nemesis", _, "<target> - Turn someone into a Nemesis", 0)

	// Assassin Class loaded?
	if (LibraryExists(LIBRARY_ASSASSIN, LibType_Library))
		register_concmd("zp_assassin", "cmd_assassin", _, "<target> - Turn someone into a Assassin", 0)

	// Dragon Class loaded?
	if (LibraryExists(LIBRARY_DRAGON, LibType_Library))
		register_concmd("zp_dragon", "cmd_dragon", _, "<target> - Turn someone into a Dragon", 0)
	
	// Nightcrawler Class loaded?
	if (LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library))
		register_concmd("zp_nightcrawler", "cmd_nightcrawler", _, "<target> - Turn someone into a Nightcrawler", 0)

	// Survivor Class loaded?
	if (LibraryExists(LIBRARY_SURVIVOR, LibType_Library))
		register_concmd("zp_survivor", "cmd_survivor", _, "<target> - Turn someone into a Survivor", 0)	

	// Sniper Class loaded?
	if (LibraryExists(LIBRARY_SNIPER, LibType_Library))
		register_concmd("zp_sniper", "cmd_sniper", _, "<target> - Turn someone into a Sniper", 0)

	// Knifer Class loaded?
	if (LibraryExists(LIBRARY_KNIFER, LibType_Library))
		register_concmd("zp_knifer", "cmd_knifer", _, "<target> - Turn someone into a Knifer", 0)

	// Plasma Class loaded?
	if (LibraryExists(LIBRARY_PLASMA, LibType_Library))
		register_concmd("zp_plasma", "cmd_plasma", _, "<target> - Turn someone into a Plasma", 0)
	
	g_MaxPlayers = get_maxplayers()
	
	cvar_log_admin_commands = register_cvar("zp_log_admin_commands", "1")
}

public plugin_precache()
{
	// Load from external file, save if not found
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE ZOMBIE", g_access_make_zombie, charsmax(g_access_make_zombie)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE ZOMBIE", g_access_make_zombie)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE HUMAN", g_access_make_human, charsmax(g_access_make_human)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE HUMAN", g_access_make_human)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE NEMESIS", g_access_make_nemesis, charsmax(g_access_make_nemesis)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE NEMESIS", g_access_make_nemesis)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE ASSASSIN", g_access_make_assassin, charsmax(g_access_make_assassin)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE ASSASSIN", g_access_make_assassin)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE DRAGON", g_access_make_dragon, charsmax(g_access_make_dragon)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE DRAGON", g_access_make_dragon)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE NIGHTCRAWLER", g_access_make_nightcrawler, charsmax(g_access_make_nightcrawler)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE NIGHTCRAWLER", g_access_make_nightcrawler)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE SURVIVOR", g_access_make_survivor, charsmax(g_access_make_survivor)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE SURVIVOR", g_access_make_survivor)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE SNIPER", g_access_make_sniper, charsmax(g_access_make_sniper)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE SNIPER", g_access_make_sniper)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE KNIFER", g_access_make_knifer, charsmax(g_access_make_knifer)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE KNIFER", g_access_make_knifer)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE PLASMA", g_access_make_plasma, charsmax(g_access_make_plasma)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "MAKE PLASMA", g_access_make_plasma)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "RESPAWN PLAYERS", g_access_respawn_players, charsmax(g_access_respawn_players)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "RESPAWN PLAYERS", g_access_respawn_players)
	if (!amx_load_setting_string(ZP_SETTINGS_FILE, "Access Flags", "START GAME MODE", g_access_start_game_mode, charsmax(g_access_start_game_mode)))
		amx_save_setting_string(ZP_SETTINGS_FILE, "Access Flags", "START GAME MODE", g_access_start_game_mode)
}

public plugin_natives()
{
	register_library("zp50_admin_commands")
	register_native("zp_admin_commands_zombie", "native_admin_commands_zombie")
	register_native("zp_admin_commands_human", "native_admin_commands_human")
	register_native("zp_admin_commands_nemesis", "native_admin_commands_nemesis")
	register_native("zp_admin_commands_assassin", "native_admin_commands_assassin")
	register_native("zp_admin_commands_dragon", "native_admin_commands_dragon")
	register_native("zp_admin_commands_nightcrawler", "native_admin_commands_crawler")
	register_native("zp_admin_commands_survivor", "native_admin_commands_survivor")
	register_native("zp_admin_commands_sniper", "native_admin_commands_sniper")
	register_native("zp_admin_commands_knifer", "native_admin_commands_knifer")
	register_native("zp_admin_commands_plasma", "native_admin_commands_plasma")
	register_native("zp_admin_commands_respawn", "native_admin_commands_respawn")
	register_native("zp_admin_commands_start_mode", "_admin_commands_start_mode")
	
	set_module_filter("module_filter")
	set_native_filter("native_filter")
}
public module_filter(const module[])
{
	if (equal(module, LIBRARY_NEMESIS) || equal(module, LIBRARY_ASSASSIN) || equal(module, LIBRARY_DRAGON) || equal(module, LIBRARY_NIGHTCRAWLER) || equal(module, LIBRARY_SURVIVOR) || equal(module, LIBRARY_SNIPER) || equal(module, LIBRARY_KNIFER) || equal(module, LIBRARY_PLASMA))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}
public native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public plugin_cfg()
{
	cvar_amx_show_activity = get_cvar_pointer("amx_show_activity")
	cvar_deathmatch = get_cvar_pointer("zp_deathmatch")
	g_GameModeInfectionID = zp_gamemodes_get_id("Infection Mode")
	g_GameModeNemesisID = zp_gamemodes_get_id("Nemesis Mode")
	g_GameModeAssassinID = zp_gamemodes_get_id("Assassin Mode")
	g_GameModeDragonID = zp_gamemodes_get_id("Dragon Mode")
	g_GameModeNightcrawlerID = zp_gamemodes_get_id("Nightcrawler Mode")
	g_GameModeSurvivorID = zp_gamemodes_get_id("Survivor Mode")
	g_GameModeSniperID = zp_gamemodes_get_id("Sniper Mode")
	g_GameModeKniferID = zp_gamemodes_get_id("Knifer Mode")
	g_GameModePlasmaID = zp_gamemodes_get_id("Plasma Mode")
}

public native_admin_commands_zombie(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	command_zombie(id_admin, player)
	return true;
}

public native_admin_commands_human(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	command_human(id_admin, player)
	return true;
}

public native_admin_commands_nemesis(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Nemesis class not present
	if (!LibraryExists(LIBRARY_NEMESIS, LibType_Library))
		return false;
	
	command_nemesis(id_admin, player)
	return true;
}

public native_admin_commands_assassin(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Assassin class not present
	if (!LibraryExists(LIBRARY_ASSASSIN, LibType_Library))
		return false;
	
	command_assassin(id_admin, player)
	return true;
}

public native_admin_commands_dragon(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Dragon class not present
	if (!LibraryExists(LIBRARY_DRAGON, LibType_Library))
		return false;
	
	command_dragon(id_admin, player)
	return true;
}


public native_admin_commands_crawler(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Nightcrawler class not present
	if (!LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library))
		return false;
	
	command_nightcrawler(id_admin, player)
	return true;
}

public native_admin_commands_survivor(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Survivor class not present
	if (!LibraryExists(LIBRARY_SURVIVOR, LibType_Library))
		return false;
	
	command_survivor(id_admin, player)
	return true;
}

public native_admin_commands_sniper(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Sniper class not present
	if (!LibraryExists(LIBRARY_SNIPER, LibType_Library))
		return false;
	
	command_sniper(id_admin, player)
	return true;
}

public native_admin_commands_knifer(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Knifer class not present
	if (!LibraryExists(LIBRARY_KNIFER, LibType_Library))
		return false;
	
	command_knifer(id_admin, player)
	return true;
}

public native_admin_commands_plasma(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_alive(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Plasma class not present
	if (!LibraryExists(LIBRARY_PLASMA, LibType_Library))
		return false;
	
	command_plasma(id_admin, player)
	return true;
}

public native_admin_commands_respawn(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new player = get_param(2)
	
	if (!is_user_connected(player))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", player)
		return false;
	}
	
	// Respawn allowed for player?
	if (!allowed_respawn(player))
		return false;
	
	command_respawn(id_admin, player)
	return true;
}

public _admin_commands_start_mode(plugin_id, num_params)
{
	new id_admin = get_param(1)
	
	if (!is_user_connected(id_admin))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id_admin)
		return false;
	}
	
	new game_mode_id = get_param(2)
	
	// Invalid game mode id
	if (!(0 <= game_mode_id < zp_gamemodes_get_count()))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid game mode id (%d).", game_mode_id)
		return false;
	}
	
	command_start_mode(id_admin, game_mode_id)
	return true;
}

// zp_zombie [target]
public cmd_zombie(id, level, cid)
{
	// Check for access flag - Make Zombie
	if (!cmd_access(id, read_flags(g_access_make_zombie), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be zombie
	if (zp_core_is_zombie(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_ZOMBIE", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_zombie(id, player)
	return PLUGIN_HANDLED;
}

// zp_human [target]
public cmd_human(id, level, cid)
{
	// Check for access flag - Make Human
	if (!cmd_access(id, read_flags(g_access_make_human), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be human
	if (!zp_core_is_zombie(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_HUMAN", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_human(id, player)
	return PLUGIN_HANDLED;
}

// zp_nemesis [target]
public cmd_nemesis(id, level, cid)
{
	// Check for access flag - Make Nemesis
	if (!cmd_access(id, read_flags(g_access_make_nemesis), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be nemesis
	if (zp_class_nemesis_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_NEMESIS", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_nemesis(id, player)
	return PLUGIN_HANDLED;
}

// zp_assassin [target]
public cmd_assassin(id, level, cid)
{
	// Check for access flag - Make assassin
	if (!cmd_access(id, read_flags(g_access_make_assassin), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be nemesis
	if (zp_class_assassin_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_ASSASSIN", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_assassin(id, player)
	return PLUGIN_HANDLED;
}

// zp_dragon [target]
public cmd_dragon(id, level, cid)
{
	// Check for access flag - Make dragon
	if (!cmd_access(id, read_flags(g_access_make_dragon), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be dragon
	if (zp_class_dragon_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_DRAGON", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_dragon(id, player)
	return PLUGIN_HANDLED;
}

// zp_nightcrawler [target]
public cmd_nightcrawler(id, level, cid)
{
	// Check for access flag - Make nightcrawler
	if (!cmd_access(id, read_flags(g_access_make_nightcrawler), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be nightcrawler
	if (zp_class_nightcrawler_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_NIGHTCRAWLER", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_nightcrawler(id, player)
	return PLUGIN_HANDLED;
}

// zp_survivor [target]
public cmd_survivor(id, level, cid)
{
	// Check for access flag - Make Survivor
	if (!cmd_access(id, read_flags(g_access_make_survivor), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be survivor
	if (zp_class_survivor_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_SURVIVOR", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_survivor(id, player)
	return PLUGIN_HANDLED;
}

// zp_sniper [target]
public cmd_sniper(id, level, cid)
{
	// Check for access flag - Make sniper
	if (!cmd_access(id, read_flags(g_access_make_sniper), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be sniper
	if (zp_class_sniper_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_SNIPER", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_sniper(id, player)
	return PLUGIN_HANDLED;
}

// zp_knifer [target]
public cmd_knifer(id, level, cid)
{
	// Check for access flag - Make knifer
	if (!cmd_access(id, read_flags(g_access_make_knifer), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be knifer
	if (zp_class_knifer_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_KNIFER", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_knifer(id, player)
	return PLUGIN_HANDLED;
}

// zp_plasma [target]
public cmd_plasma(id, level, cid)
{
	// Check for access flag - Make sniper
	if (!cmd_access(id, read_flags(g_access_make_plasma), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, (CMDTARGET_ONLY_ALIVE | CMDTARGET_ALLOW_SELF))
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be plasma
	if (zp_class_plasma_get(player))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "ALREADY_PLASMA", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_plasma(id, player)
	return PLUGIN_HANDLED;
}


// zp_respawn [target]
public cmd_respawn(id, level, cid)
{
	// Check for access flag - Respawn
	if (!cmd_access(id, read_flags(g_access_respawn_players), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], player
	read_argv(1, arg, charsmax(arg))
	player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
	
	// Invalid target
	if (!player) return PLUGIN_HANDLED;
	
	// Target not allowed to be respawned
	if (!allowed_respawn(id))
	{
		new player_name[32]
		get_user_name(player, player_name, charsmax(player_name))
		client_print(id, print_console, "[ZP] %L (%s).", id, "CANT_RESPAWN", player_name)
		return PLUGIN_HANDLED;
	}
	
	command_respawn(id, player)
	return PLUGIN_HANDLED;
}

// zp_gamemodes_start [game mode id]
public cmd_start_game_mode(id, level, cid)
{
	// Check for access flag - Start Game Mode
	if (!cmd_access(id, read_flags(g_access_start_game_mode), cid, 2))
		return PLUGIN_HANDLED;
	
	// Retrieve arguments
	new arg[32], game_mode_id
	read_argv(1, arg, charsmax(arg))
	game_mode_id = str_to_num(arg)
	
	// Invalid game mode id
	if (!(0 <= game_mode_id < zp_gamemodes_get_count()))
	{
		client_print(id, print_console, "[ZP] %L (%d).", id, "INVALID_GAME_MODE", game_mode_id)
		return PLUGIN_HANDLED;
	}
	
	command_start_mode(id, game_mode_id)
	return PLUGIN_HANDLED;
}

// Checks if a player is allowed to respawn
allowed_respawn(id)
{
	if (is_user_alive(id))
		return false;
	
	new CsTeams:team = cs_get_user_team(id)
	
	if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED)
		return false;
	
	return true;
}

// Admin Command. zp_zombie
command_zombie(id, player)
{
	// Prevent infecting last human
	if (zp_core_is_last_human(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_HUMAN")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// Infection mode disabled
		if (g_GameModeInfectionID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start infection game mode with this target player
		if (!zp_gamemodes_start(g_GameModeInfectionID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player infect himself
		zp_core_infect(player, player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_INFECT")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_INFECT")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_INFECT", GetPlayingCount())
	}
}

// Admin Command. zp_human
command_human(id, player)
{
	// Prevent infecting last zombie
	if (zp_core_is_last_zombie(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_ZOMBIE")
		return;
	}
	
	// No game mode currently in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
		return;
	}
	
	// Make player cure himself
	zp_core_cure(player, player)
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_DISINFECT")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_DISINFECT")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_DISINFECT", GetPlayingCount())
	}
}

// Admin Command. zp_nemesis
command_nemesis(id, player)
{
	// Prevent infecting last human
	if (zp_core_is_last_human(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_HUMAN")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// Nemesis mode disabled
		if (g_GameModeNemesisID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start nemesis game mode with this target player
		if (!zp_gamemodes_start(g_GameModeNemesisID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player nemesis
		zp_class_nemesis_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_NEMESIS")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_NEMESIS")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_NEMESIS", GetPlayingCount())
	}
}

// Admin Command. zp_assassin
command_assassin(id, player)
{
	// Prevent infecting last human
	if (zp_core_is_last_human(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_HUMAN")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// assassin mode disabled
		if (g_GameModeAssassinID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start assassin game mode with this target player
		if (!zp_gamemodes_start(g_GameModeAssassinID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player assassin
		zp_class_assassin_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_ASSASSIN")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_ASSASSIN")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_ASSASSIN", GetPlayingCount())
	}
}

// Admin Command. zp_dragon
command_dragon(id, player)
{
	// Prevent infecting last human
	if (zp_core_is_last_human(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_HUMAN")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// assassin mode disabled
		if (g_GameModeDragonID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start dragon game mode with this target player
		if (!zp_gamemodes_start(g_GameModeDragonID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player dragon
		zp_class_dragon_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_DRAGON")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_DRAGON")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_DRAGON", GetPlayingCount())
	}
}

// Admin Command. zp_nightcrawler
command_nightcrawler(id, player)
{
	// Prevent infecting last human
	if (zp_core_is_last_human(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_HUMAN")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// assassin mode disabled
		if (g_GameModeNightcrawlerID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start nightcrawler game mode with this target player
		if (!zp_gamemodes_start(g_GameModeNightcrawlerID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player nightcrawler
		zp_class_nightcrawler_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_NIGHTCRAWLER")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_NIGHTCRAWLER")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_NIGHTCRAWLER", GetPlayingCount())
	}
}


// Admin Command. zp_survivor
command_survivor(id, player)
{
	// Prevent infecting last zombie
	if (zp_core_is_last_zombie(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_ZOMBIE")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// Survivor mode disabled
		if (g_GameModeSurvivorID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start survivor game mode with this target player
		if (!zp_gamemodes_start(g_GameModeSurvivorID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player survivor
		zp_class_survivor_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_SURVIVAL")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_SURVIVAL")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_SURVIVAL", GetPlayingCount())
	}
}

// Admin Command. zp_sniper
command_sniper(id, player)
{
	// Prevent infecting last zombie
	if (zp_core_is_last_zombie(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_ZOMBIE")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// sniper mode disabled
		if (g_GameModeSniperID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start sniper game mode with this target player
		if (!zp_gamemodes_start(g_GameModeSniperID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player sniper
		zp_class_sniper_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_SNIPER")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_SNIPER")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_SNIPER", GetPlayingCount())
	}
}

// Admin Command. zp_knifer
command_knifer(id, player)
{
	// Prevent infecting last zombie
	if (zp_core_is_last_zombie(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_ZOMBIE")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// knifer mode disabled
		if (g_GameModeKniferID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start knifer game mode with this target player
		if (!zp_gamemodes_start(g_GameModeKniferID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player knifer
		zp_class_knifer_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_KNIFER")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_KNIFER")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_KNIFER", GetPlayingCount())
	}
}

// Admin Command. zp_sniper
command_plasma(id, player)
{
	// Prevent infecting last zombie
	if (zp_core_is_last_zombie(player))
	{
		zp_colored_print(id, "%L", id, "CMD_CANT_LAST_ZOMBIE")
		return;
	}
	
	// Check if a game mode is in progress
	if (zp_gamemodes_get_current() == ZP_NO_GAME_MODE)
	{
		// plasma mode disabled
		if (g_GameModePlasmaID == ZP_INVALID_GAME_MODE)
		{
			zp_colored_print(id, "%L", id, "CMD_ONLY_AFTER_GAME_MODE")
			return;
		}
		
		// Start plasma game mode with this target player
		if (!zp_gamemodes_start(g_GameModePlasmaID, player))
		{
			zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
			return;
		}
	}
	else
	{
		// Make player plasma
		zp_class_plasma_set(player)
	}
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_PLASMA")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_PLASMA")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_PLASMA", GetPlayingCount())
	}
}

// Admin Command. zp_respawn
command_respawn(id, player)
{
	// Deathmatch module active?
	if (cvar_deathmatch)
	{
		// Respawn as zombie?
		if (get_pcvar_num(cvar_deathmatch) == 2 || (get_pcvar_num(cvar_deathmatch) == 3 && random_num(0, 1)) || (get_pcvar_num(cvar_deathmatch) == 4 && zp_core_get_zombie_count() < GetAliveCount()/2))
		{
			// Only allow respawning as zombie after a game mode started
			if (zp_gamemodes_get_current() != ZP_NO_GAME_MODE) zp_core_respawn_as_zombie(player, true)
		}
	}
	
	// Respawn player!
	respawn_player_manually(player)
	
	// Get user names
	new admin_name[32], player_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	get_user_name(player, player_name, charsmax(player_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %s %L", player_name, LANG_PLAYER, "CMD_RESPAWN")
			case 2: zp_colored_print(0, "ADMIN %s - %s %L", admin_name, player_name, LANG_PLAYER, "CMD_RESPAWN")
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %s %L (Players: %d)", admin_name, authid, ip, player_name, LANG_SERVER, "CMD_RESPAWN", GetPlayingCount())
	}
}

// Respawn Player Manually (called after respawn checks are done)
respawn_player_manually(id)
{
	// Respawn!
	ExecuteHamB(Ham_CS_RoundRespawn, id)
}

// Admin Command. zp_start_game_mode
command_start_mode(id, game_mode_id)
{
	// Attempt to start game mode
	if (!zp_gamemodes_start(game_mode_id))
	{
		zp_colored_print(id, "%L", id, "GAME_MODE_CANT_START")
		return;
	}
	
	// Get user names
	new admin_name[32], mode_name[32]
	get_user_name(id, admin_name, charsmax(admin_name))
	zp_gamemodes_get_name(game_mode_id, mode_name, charsmax(mode_name))
	
	// Show activity?
	if (cvar_amx_show_activity)
	{
		switch (get_pcvar_num(cvar_amx_show_activity))
		{
			case 1: zp_colored_print(0, "ADMIN - %L: %s", LANG_PLAYER, "CMD_START_GAME_MODE", mode_name)
			case 2: zp_colored_print(0, "ADMIN %s - %L: %s", admin_name, LANG_PLAYER, "CMD_START_GAME_MODE", mode_name)
		}
	}
	
	// Log to Zombie Plague log file?
	if (get_pcvar_num(cvar_log_admin_commands))
	{
		new authid[32], ip[16]
		get_user_authid(id, authid, charsmax(authid))
		get_user_ip(id, ip, charsmax(ip), 1)
		zp_log("ADMIN %s <%s><%s> - %L: %s (Players: %d)", admin_name, authid, ip, LANG_SERVER, "CMD_START_GAME_MODE", mode_name, GetPlayingCount())
	}
}

// Get Playing Count -returns number of users playing-
GetPlayingCount()
{
	new iPlaying, id, CsTeams:team
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (!is_user_connected(id))
			continue;
		
		team = cs_get_user_team(id)
		
		if (team != CS_TEAM_SPECTATOR && team != CS_TEAM_UNASSIGNED)
			iPlaying++
	}
	
	return iPlaying;
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
