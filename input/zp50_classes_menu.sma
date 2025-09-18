/*==============================================================================
	
	-----------------------
	-*- [ZP] Classes Menu -*-
	-----------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <amx_settings_api>
#include <zp50_core>
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
#include <zp50_admin_commands>
#include <zp50_colorchat>

// Settings file
new const ZP_SETTINGS_FILE[] = "zombieplague.ini"

#define ACCESSFLAG_MAX_LENGTH 2

// Access flags
new g_access_make_nemesis[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_assassin[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_dragon[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_nightcrawler[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_survivor[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_sniper[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_knifer[ACCESSFLAG_MAX_LENGTH] = "d"
new g_access_make_plasma[ACCESSFLAG_MAX_LENGTH] = "d"

// Classes menu actions
enum
{
	ACTION_MAKE_NEMESIS = 0,
	ACTION_MAKE_ASSASSIN,
	ACTION_MAKE_DRAGON,
	ACTION_MAKE_NIGHTCRAWLER,
	ACTION_MAKE_SURVIVOR,
	ACTION_MAKE_SNIPER,
	ACTION_MAKE_KNIFER,
	ACTION_MAKE_PLASMA,
}

// Menu keys
const KEYSMENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

// CS Player PData Offsets (win32)
const OFFSET_CSMENUCODE = 205

#define MAXPLAYERS 32

// For player/mode list menu handlers
#define PL_ACTION g_menu_data[id][0]
#define MENU_PAGE_PLAYERS g_menu_data[id][1]
#define MENU_PAGE_GAME_MODES g_menu_data[id][2]
new g_menu_data[MAXPLAYERS+1][3]

new g_MaxPlayers

public plugin_init()
{
	register_plugin("[ZP] Classes Menu", ZP_VERSION_STRING, "ZP Dev Team")
	
	g_MaxPlayers = get_maxplayers()
	
	register_menu("Classes Menu", KEYSMENU, "menu_classes")
	register_clcmd("say /classesmenu", "clcmd_classesmenu")
	register_clcmd("say classesmenu", "clcmd_classesmenu")
}

public plugin_precache()
{
	// Load from external file, save if not found
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

}

public plugin_natives()
{
	register_library("zp50_classes_menu")
	register_native("zp_classes_menu_show", "native_classes_menu_show")
	
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

public native_classes_menu_show(plugin_id, num_params)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZP] Invalid Player (%d)", id)
		return false;
	}
	
	show_menu_classes(id)
	return true;
}

public client_disconnect(id)
{
	// Reset remembered menu pages
	MENU_PAGE_PLAYERS = 0
}

public clcmd_classesmenu(id)
{
	show_menu_classes(id)
}

// classes Menu
show_menu_classes(id)
{
	static menu[250]
	new len, userflags = get_user_flags(id)
	
	// Title
	len += formatex(menu[len], charsmax(menu) - len, "\y%L:^n^n", id, "MENU_CLASSES_TITLE")
	
	
	// 1. Nemesis command
	if (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && (userflags & read_flags(g_access_make_nemesis)))
		len += formatex(menu[len], charsmax(menu) - len, "\r1.\w %L^n", id, "MENU_ADMIN2")
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d1. %L^n", id, "MENU_ADMIN2")

	// 2. Assassin command
	if (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && (userflags & read_flags(g_access_make_assassin)))
		len += formatex(menu[len], charsmax(menu) - len, "\r2.\w %L^n", id, "MENU_ADMIN3")
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d2. %L^n", id, "MENU_ADMIN3")

	// 3. Dragon command
	if (LibraryExists(LIBRARY_DRAGON, LibType_Library) && (userflags & read_flags(g_access_make_dragon)))
		len += formatex(menu[len], charsmax(menu) - len, "\r3.\w Make Dragon^n", id)
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d3. Make Dragon^n", id)

	// 4. NightCrawler command
	if (LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library) && (userflags & read_flags(g_access_make_nightcrawler)))
		len += formatex(menu[len], charsmax(menu) - len, "\r4.\w Make NightCrawler^n", id)
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d4. Make NightCrawler^n", id)
	
	// 5. Survivor command
	if (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && (userflags & read_flags(g_access_make_survivor)))
		len += formatex(menu[len], charsmax(menu) - len, "\r5.\w %L^n", id, "MENU_ADMIN4")
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d5. %L^n", id, "MENU_ADMIN4")

	// 6. Sniper command
	if (LibraryExists(LIBRARY_SNIPER, LibType_Library) && (userflags & read_flags(g_access_make_sniper)))
		len += formatex(menu[len], charsmax(menu) - len, "\r6.\w %L^n", id, "MENU_ADMIN5")
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d6. %L^n", id, "MENU_ADMIN5")

	// 7. Knifer command
	if (LibraryExists(LIBRARY_KNIFER, LibType_Library) && (userflags & read_flags(g_access_make_knifer)))
		len += formatex(menu[len], charsmax(menu) - len, "\r7.\w Make Knifer^n", id)
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d7. Make Knifer^n", id)

	// 8. Knifer command
	if (LibraryExists(LIBRARY_PLASMA, LibType_Library) && (userflags & read_flags(g_access_make_plasma)))
		len += formatex(menu[len], charsmax(menu) - len, "\r8.\w Make Plasma^n", id)
	else
		len += formatex(menu[len], charsmax(menu) - len, "\d8. Make Plasma^n", id)
	

	
	// 0. Exit
	len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w %L", id, "MENU_EXIT")
	
	// Fix for AMXX custom menus
	set_pdata_int(id, OFFSET_CSMENUCODE, 0)
	show_menu(id, KEYSMENU, menu, -1, "Classes Menu")
}

// Player List Menu
show_menu_player_list(id)
{
	static menu[250], player_name[32]
	new menuid, player, buffer[2], userflags = get_user_flags(id)
	
	// Title
	switch (PL_ACTION)
	{
		case ACTION_MAKE_NEMESIS: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN2")
		case ACTION_MAKE_ASSASSIN: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN3")
		case ACTION_MAKE_DRAGON: formatex(menu, charsmax(menu), "Make Dragon\r", id)
		case ACTION_MAKE_NIGHTCRAWLER: formatex(menu, charsmax(menu), "Make NightCrawler\r", id)
		case ACTION_MAKE_SURVIVOR: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN4")
		case ACTION_MAKE_SNIPER: formatex(menu, charsmax(menu), "%L\r", id, "MENU_ADMIN5")
		case ACTION_MAKE_KNIFER: formatex(menu, charsmax(menu), "Make Knifer\r", id)
		case ACTION_MAKE_PLASMA: formatex(menu, charsmax(menu), "Make Plasma\r", id)
	}
	menuid = menu_create(menu, "menu_player_list")
	
	// Player List
	for (player = 0; player <= g_MaxPlayers; player++)
	{
		// Skip if not connected
		if (!is_user_connected(player))
			continue;
		
		// Get player's name
		get_user_name(player, player_name, charsmax(player_name))
		
		// Format text depending on the action to take
		switch (PL_ACTION)
		{

			case ACTION_MAKE_NEMESIS: // Nemesis command
			{
				if (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && (userflags & read_flags(g_access_make_nemesis)) && is_user_alive(player) && !zp_class_nemesis_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player)) ? "CLASS_ASSASSIN" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player)) ? "CLASS_SNIPER" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ASSASSIN");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SNIPER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			case ACTION_MAKE_ASSASSIN: // Assassin command
			{
				if (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && (userflags & read_flags(g_access_make_assassin)) && is_user_alive(player) && !zp_class_assassin_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player)) ? "CLASS_ASSASSIN" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player)) ? "CLASS_SNIPER" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ASSASSIN");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SNIPER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			case ACTION_MAKE_DRAGON: // Dragon command
			{
				if (LibraryExists(LIBRARY_DRAGON, LibType_Library) && (userflags & read_flags(g_access_make_dragon)) && is_user_alive(player) && !zp_class_dragon_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_dragon_get(player)) ? "CLASS_DRAGON" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player)) ? "CLASS_SNIPER" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_DRAGON, LibType_Library) && zp_class_dragon_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_DRAGON");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SNIPER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			case ACTION_MAKE_NIGHTCRAWLER: // Nightcrawler command
			{
				if (LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library) && (userflags & read_flags(g_access_make_nightcrawler)) && is_user_alive(player) && !zp_class_nightcrawler_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_nightcrawler_get(player)) ? "CLASS_NIGHTCRAWLER" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player)) ? "CLASS_SNIPER" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library) && zp_class_nightcrawler_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NIGHTCRAWLER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SNIPER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			case ACTION_MAKE_SURVIVOR: // Survivor command
			{
				if (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && (userflags & read_flags(g_access_make_survivor)) && is_user_alive(player) && !zp_class_survivor_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player)) ? "CLASS_ASSASSIN" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player)) ? "CLASS_SNIPER" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ASSASSIN");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SNIPER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			case ACTION_MAKE_SNIPER: // Sniper command
			{
				if (LibraryExists(LIBRARY_SNIPER, LibType_Library) && (userflags & read_flags(g_access_make_sniper)) && is_user_alive(player) && !zp_class_sniper_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player)) ? "CLASS_ASSASSIN" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player)) ? "CLASS_SNIPER" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ASSASSIN");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SNIPER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			case ACTION_MAKE_KNIFER: // Knifer command
			{
				if (LibraryExists(LIBRARY_KNIFER, LibType_Library) && (userflags & read_flags(g_access_make_knifer)) && is_user_alive(player) && !zp_class_knifer_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player)) ? "CLASS_ASSASSIN" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_KNIFER, LibType_Library) && zp_class_knifer_get(player)) ? "CLASS_KNIFER" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ASSASSIN");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_KNIFER, LibType_Library) && zp_class_knifer_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_KNIFER");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			case ACTION_MAKE_PLASMA: // Plasma command
			{
				if (LibraryExists(LIBRARY_PLASMA, LibType_Library) && (userflags & read_flags(g_access_make_plasma)) && is_user_alive(player) && !zp_class_plasma_get(player))
				{
					if (zp_core_is_zombie(player))
						formatex(menu, charsmax(menu), "%s \r[%L]", player_name, id, (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player)) ? "CLASS_NEMESIS" : (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player)) ? "CLASS_ASSASSIN" : "CLASS_ZOMBIE")
					else
						formatex(menu, charsmax(menu), "%s \y[%L]", player_name, id, (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player)) ? "CLASS_SURVIVOR" : (LibraryExists(LIBRARY_PLASMA, LibType_Library) && zp_class_plasma_get(player)) ? "CLASS_PLASMA" : "CLASS_HUMAN")
				}
				else
				{
					if( zp_core_is_zombie(player) )
					{
						if( LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(player) )
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_NEMESIS");
						else if(LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ASSASSIN");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_ZOMBIE");
					}
					else
					{
						if( LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_SURVIVOR");
						else if( LibraryExists(LIBRARY_PLASMA, LibType_Library) && zp_class_plasma_get(player))
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_PLASMA");
						else
							formatex(menu, charsmax(menu), "\d%s [%L]", player_name, id, "CLASS_HUMAN");
					}
				}
			}
			
		}
		
		// Add player
		buffer[0] = player
		buffer[1] = 0
		menu_additem(menuid, menu, buffer)
	}
	
	// Back - Next - Exit
	formatex(menu, charsmax(menu), "%L", id, "MENU_BACK")
	menu_setprop(menuid, MPROP_BACKNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_NEXT")
	menu_setprop(menuid, MPROP_NEXTNAME, menu)
	formatex(menu, charsmax(menu), "%L", id, "MENU_EXIT")
	menu_setprop(menuid, MPROP_EXITNAME, menu)
	
	// If remembered page is greater than number of pages, clamp down the value
	MENU_PAGE_PLAYERS = min(MENU_PAGE_PLAYERS, menu_pages(menuid)-1)
	
	// Fix for AMXX custom menus
	set_pdata_int(id, OFFSET_CSMENUCODE, 0)
	menu_display(id, menuid, MENU_PAGE_PLAYERS)
}



// Classes Menu
public menu_classes(id, key)
{
	// Player disconnected?
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	new userflags = get_user_flags(id)
	
	switch (key)
	{
		case ACTION_MAKE_NEMESIS: // Nemesis command
		{
			if (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && (userflags & read_flags(g_access_make_nemesis)))
			{
				// Show player list for classes to pick a target
				PL_ACTION = ACTION_MAKE_NEMESIS
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		case ACTION_MAKE_ASSASSIN: // Assassin command
		{
			if (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && (userflags & read_flags(g_access_make_assassin)))
			{
				// Show player list for Classes to pick a target
				PL_ACTION = ACTION_MAKE_ASSASSIN
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		case ACTION_MAKE_DRAGON: // Dragon command
		{
			if (LibraryExists(LIBRARY_DRAGON, LibType_Library) && (userflags & read_flags(g_access_make_dragon)))
			{
				// Show player list for Classes to pick a target
				PL_ACTION = ACTION_MAKE_DRAGON
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		case ACTION_MAKE_NIGHTCRAWLER: // NightCrawler command
		{
			if (LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library) && (userflags & read_flags(g_access_make_nightcrawler)))
			{
				// Show player list for Classes to pick a target
				PL_ACTION = ACTION_MAKE_NIGHTCRAWLER
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		case ACTION_MAKE_SURVIVOR: // Survivor command
		{
			if (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && (userflags & read_flags(g_access_make_survivor)))
			{
				// Show player list for Classes to pick a target
				PL_ACTION = ACTION_MAKE_SURVIVOR
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		case ACTION_MAKE_SNIPER: // Sniper command
		{
			if (LibraryExists(LIBRARY_SNIPER, LibType_Library) && (userflags & read_flags(g_access_make_sniper)))
			{
				// Show player list for Classes to pick a target
				PL_ACTION = ACTION_MAKE_SNIPER
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		case ACTION_MAKE_KNIFER: // Knifer command
		{
			if (LibraryExists(LIBRARY_KNIFER, LibType_Library) && (userflags & read_flags(g_access_make_knifer)))
			{
				// Show player list for Classes to pick a target
				PL_ACTION = ACTION_MAKE_KNIFER
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		case ACTION_MAKE_PLASMA: // Plasma command
		{
			if (LibraryExists(LIBRARY_PLASMA, LibType_Library) && (userflags & read_flags(g_access_make_plasma)))
			{
				// Show player list for Classes to pick a target
				PL_ACTION = ACTION_MAKE_PLASMA
				show_menu_player_list(id)
			}
			else
			{
				zp_colored_print(id, "%L", id, "CMD_NOT_ACCESS")
				show_menu_classes(id)
			}
		}
		
	}
	
	return PLUGIN_HANDLED;
}

// Player List Menu
public menu_player_list(id, menuid, item)
{
	// Menu was closed
	if (item == MENU_EXIT)
	{
		MENU_PAGE_PLAYERS = 0
		menu_destroy(menuid)
		show_menu_classes(id)
		return PLUGIN_HANDLED;
	}
	
	// Remember player's menu page
	MENU_PAGE_PLAYERS = item / 7
	
	// Retrieve player id
	new buffer[2], dummy, player
	menu_item_getinfo(menuid, item, dummy, buffer, charsmax(buffer), _, _, dummy)
	player = buffer[0]
	
	// Perform action on player
	
	// Get Classes flags
	new userflags = get_user_flags(id)
	
	// Make sure it's still connected
	if (is_user_connected(player))
	{
		// Perform the right action if allowed
		switch (PL_ACTION)
		{
			case ACTION_MAKE_NEMESIS: // Nemesis command
			{
				if (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && (userflags & read_flags(g_access_make_nemesis)) && is_user_alive(player) && !zp_class_nemesis_get(player))
					zp_admin_commands_nemesis(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
			case ACTION_MAKE_ASSASSIN: // Assassin command
			{
				if (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && (userflags & read_flags(g_access_make_assassin)) && is_user_alive(player) && !zp_class_assassin_get(player))
					zp_admin_commands_assassin(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
			case ACTION_MAKE_DRAGON: // Dragon command
			{
				if (LibraryExists(LIBRARY_DRAGON, LibType_Library) && (userflags & read_flags(g_access_make_dragon)) && is_user_alive(player) && !zp_class_dragon_get(player))
					zp_admin_commands_dragon(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
			case ACTION_MAKE_NIGHTCRAWLER: // NightCrawler command
			{
				if (LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library) && (userflags & read_flags(g_access_make_nightcrawler)) && is_user_alive(player) && !zp_class_nightcrawler_get(player))
					zp_admin_commands_nightcrawler(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
			case ACTION_MAKE_SURVIVOR: // Survivor command
			{
				if (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && (userflags & read_flags(g_access_make_survivor)) && is_user_alive(player) && !zp_class_survivor_get(player))
					zp_admin_commands_survivor(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
			case ACTION_MAKE_SNIPER: // Sniper command
			{
				if (LibraryExists(LIBRARY_SNIPER, LibType_Library) && (userflags & read_flags(g_access_make_sniper)) && is_user_alive(player) && !zp_class_sniper_get(player))
					zp_admin_commands_sniper(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
			case ACTION_MAKE_KNIFER: // Knifer command
			{
				if (LibraryExists(LIBRARY_KNIFER, LibType_Library) && (userflags & read_flags(g_access_make_knifer)) && is_user_alive(player) && !zp_class_knifer_get(player))
					zp_admin_commands_knifer(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
			case ACTION_MAKE_PLASMA: // Plasma command
			{
				if (LibraryExists(LIBRARY_PLASMA, LibType_Library) && (userflags & read_flags(g_access_make_plasma)) && is_user_alive(player) && !zp_class_plasma_get(player))
					zp_admin_commands_plasma(id, player)
				else
					zp_colored_print(id, "%L", id, "CMD_NOT")
			}
		}
	}
	else
		zp_colored_print(id, "%L", id, "CMD_NOT")
	
	menu_destroy(menuid)
	show_menu_player_list(id)
	return PLUGIN_HANDLED;
}

