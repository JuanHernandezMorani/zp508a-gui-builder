/*================================================================================
	
	----------------------------
	-*- [ZP] Pain Shock Free -*-
	----------------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
================================================================================*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cs_ham_bots_api>
#include <zp50_core>
#define LIBRARY_NEMESIS "zp50_class_nemesis"
#include <zp50_class_nemesis>
#define LIBRARY_DRAGON "zp50_class_dragon"
#include <zp50_class_dragon>
#define LIBRARY_ASSASSIN "zp50_class_assassin"
#include <zp50_class_assassin>
#define LIBRARY_NIGHTCRAWLER "zp50_class_nightcrawler"
#include <zp50_class_nightcrawler>
#define LIBRARY_SURVIVOR "zp50_class_survivor"
#include <zp50_class_survivor>
#define LIBRARY_SNIPER "zp50_class_sniper"
#include <zp50_class_sniper>
#define LIBRARY_PLASMA "zp50_class_plasma"
#include <zp50_class_plasma>
#define LIBRARY_KNIFER "zp50_class_knifer"
#include <zp50_class_knifer>

// CS Player PData Offsets (win32)
const OFFSET_PAINSHOCK = 108 // ConnorMcLeod

new cvar_painshockfree_zombie, cvar_painshockfree_human, cvar_painshockfree_nemesis, cvar_painshockfree_dragon, cvar_painshockfree_survivor,
cvar_painshockfree_assassin, cvar_painshockfree_nightcrawler, cvar_painshockfree_sniper, cvar_painshockfree_knifer, cvar_painshockfree_plasma

public plugin_init()
{
	register_plugin("[ZP] Pain Shock Free", ZP_VERSION_STRING, "ZP Dev Team")
	
	cvar_painshockfree_zombie = register_cvar("zp_painshockfree_zombie", "1") // 1-all // 2-first only // 3-last only
	cvar_painshockfree_human = register_cvar("zp_painshockfree_human", "0") // 1-all // 2-last only
	
	// Nemesis Class loaded?
	if (LibraryExists(LIBRARY_NEMESIS, LibType_Library))
		cvar_painshockfree_nemesis = register_cvar("zp_painshockfree_nemesis", "0")

	// Dragon Class loaded?
	if (LibraryExists(LIBRARY_DRAGON, LibType_Library))
		cvar_painshockfree_dragon = register_cvar("zp_painshockfree_dragon", "0")

	// Assassin Class loaded?
	if (LibraryExists(LIBRARY_ASSASSIN, LibType_Library))
		cvar_painshockfree_assassin = register_cvar("zp_painshockfree_assassin", "0")

	// Nightcrawler Class loaded?
	if (LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library))
		cvar_painshockfree_nightcrawler = register_cvar("zp_painshockfree_nightcrawler", "0")
	
	// Survivor Class loaded?
	if (LibraryExists(LIBRARY_SURVIVOR, LibType_Library))
		cvar_painshockfree_survivor = register_cvar("zp_painshockfree_survivor", "1")

	// Sniper Class loaded?
	if (LibraryExists(LIBRARY_SNIPER, LibType_Library))
		cvar_painshockfree_sniper = register_cvar("zp_painshockfree_sniper", "1")

                // Plasma Class loaded?
	if (LibraryExists(LIBRARY_PLASMA, LibType_Library))
		cvar_painshockfree_plasma = register_cvar("zp_painshockfree_plasma", "1")

                // Knifer Class loaded?
	if (LibraryExists(LIBRARY_KNIFER, LibType_Library))
		cvar_painshockfree_knifer = register_cvar("zp_painshockfree_knifer", "1")
	
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage_Post", 1)
	RegisterHamBots(Ham_TakeDamage, "fw_TakeDamage_Post", 1)
}

public plugin_natives()
{
	set_module_filter("module_filter")
	set_native_filter("native_filter")
}
public module_filter(const module[])
{
	if (equal(module, LIBRARY_NEMESIS) || equal(module, LIBRARY_DRAGON) || equal(module, LIBRARY_ASSASSIN) || equal(module, LIBRARY_NIGHTCRAWLER) || equal(module, LIBRARY_SURVIVOR) || equal(module, LIBRARY_SNIPER) || equal(module, LIBRARY_PLASMA) || equal(module, LIBRARY_KNIFER))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}
public native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED;
		
	return PLUGIN_CONTINUE;
}

// Ham Take Damage Post Forward
public fw_TakeDamage_Post(victim)
{
	// Is zombie?
	if (zp_core_is_zombie(victim))
	{
		// Nemesis Class loaded?
		if (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_nemesis)) return;
		}
		// Dragon Class loaded?
		else if (LibraryExists(LIBRARY_DRAGON, LibType_Library) && zp_class_dragon_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_dragon)) return;
		}
		// Assassin Class loaded?
		else if (LibraryExists(LIBRARY_ASSASSIN, LibType_Library) && zp_class_assassin_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_assassin)) return;
		}
		// Assassin Class loaded?
		else if (LibraryExists(LIBRARY_NIGHTCRAWLER, LibType_Library) && zp_class_nightcrawler_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_nightcrawler)) return;
		}
		else
		{
			// Check if zombie should be pain shock free
			switch (get_pcvar_num(cvar_painshockfree_zombie))
			{
				case 0: return;
				case 2: if (!zp_core_is_first_zombie(victim)) return;
				case 3: if (!zp_core_is_last_zombie(victim)) return;
			}
		}
	}
	else
	{
		// Survivor Class loaded?
		if (LibraryExists(LIBRARY_SURVIVOR, LibType_Library) && zp_class_survivor_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_survivor)) return;
		}
		// Sniper Class loaded?
		else if (LibraryExists(LIBRARY_SNIPER, LibType_Library) && zp_class_sniper_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_sniper)) return;
		}
                                // Plasma Class loaded?
		else if (LibraryExists(LIBRARY_PLASMA, LibType_Library) && zp_class_plasma_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_plasma)) return;
		}
                                // Knifer Class loaded?
		else if (LibraryExists(LIBRARY_KNIFER, LibType_Library) && zp_class_knifer_get(victim))
		{
			if (!get_pcvar_num(cvar_painshockfree_knifer)) return;
		}
		else
		{
			// Check if human should be pain shock free
			switch (get_pcvar_num(cvar_painshockfree_human))
			{
				case 0: return;
				case 2: if (!zp_core_is_last_human(victim)) return;
			}
		}
	}
	
	// Set pain shock free offset
	set_pdata_float(victim, OFFSET_PAINSHOCK, 1.0)
}
