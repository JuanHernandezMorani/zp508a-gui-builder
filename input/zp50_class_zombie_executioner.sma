/*================================================================================
	
		**********************************************************
		*********** [Zombie Plague Executioner 1.1.0] ************
		**********************************************************
	
	----------------------
	-*- Licensing Info -*-
	----------------------
	
	Zombie Plague Executioner
	by schmurgel1983(@msn.com)
	Copyright (C) 2010-2011 Stefan "schmurgel1983" Focke
	
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	
	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
	Public License for more details.
	
	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
	
	In addition, as a special exception, the author gives permission to
	link the code of this program with the Half-Life Game Engine ("HL
	Engine") and Modified Game Libraries ("MODs") developed by Valve,
	L.L.C ("Valve"). You must obey the GNU General Public License in all
	respects for all of the code used other than the HL Engine and MODs
	from Valve. If you modify this file, you may extend this exception
	to your version of the file, but you are not obligated to do so. If
	you do not wish to do so, delete this exception statement from your
	version.
	
	No warranties of any kind. Use at your own risk.
	
	-------------------
	-*- Description -*-
	-------------------
	
	This Zombie can attacks faster with knife as normal.
	Attack speed can be change by cvar.
	
	---------------------
	-*- Configuration -*-
	---------------------
	
	zp_executioner_pri 1 // Allow faster primary attack (slash) [0-disabled / 1-enabled]
	zp_executioner_pri_speed 0.33 // primary attack speed (0.5 = reduces attack speed by a half)
	zp_executioner_sec 1 // Allow faster secondary attack (stab) [0-disabled / 1-enabled]
	zp_executioner_sec_speed 0.33 // secondary attack speed (0.5 = reduces attack speed by a half)
	zp_executioner_nemesis 0 // Allow nemesis to faster attack [0-disabled / 1-enabled]
	
	--------------------
	-*- Requirements -*-
	--------------------
	
	* Mods: Counter-Strike 1.6 or Condition-Zero
	* AMXX: Version 1.8.0 or later
	* Module: fakemeta, hamsandwich
	
	-----------------
	-*- Changelog -*-
	-----------------
	
	* v1.0.0:
	   - Initial release Privat (26th Jul 2010)
	   - Initial release Alliedmodders (5th Feb 2011)
	
	* v1.1.0: (11th Feb 2011)
	   - Added: more cvars, split primary and secondary attack
	
=================================================================================*/

#include <amxmodx>
#include <fakemeta>

#if AMXX_VERSION_NUM < 180
	#assert AMX Mod X v1.8.0 or later library required!
#endif

#include <hamsandwich>

/*================================================================================
 [Zombie Plague 5.0 Includes]
=================================================================================*/

#include <zp50_class_zombie>
#define LIBRARY_NEMESIS "zp50_class_nemesis"
#include <zp50_class_nemesis>

/*================================================================================
 [Constants, Offsets, Macros]
=================================================================================*/

// Plugin Version
new const PLUGIN_VERSION[] = "1.1.0 (zp50)"

// Executioner Zombie
new const zclass_name[] = { "Executioner Zombie" }
new const zclass_info[] = { "Faster Attack" }
new const zclass_model[][] = { "zombie_source" }
new const zclass_clawmodel[][] = { "models/zombie_plague/v_knife_zombie.mdl" }
const zclass_health = 1500
const Float:zclass_speed = 1.0
const Float:zclass_gravity = 1.0
const Float:zclass_knockback = 1.0

// weapon const
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX_WEAPONS = 4
const m_flNextPrimaryAttack = 46
const m_flNextSecondaryAttack = 47

/*================================================================================
 [Global Variables]
=================================================================================*/

// Player vars
new g_bExecutioner[33] // is Executioner Zombie

// Game vars
new g_iExecutionerIndex // index from the class
new g_iMaxPlayers // max player counter

// Cvar Pointer
new cvar_Primary, cvar_PrimarySpeed, cvar_Secondary, cvar_SecondarySpeed, cvar_Nemesis

public plugin_precache()
{
	register_plugin("[ZP] Zombie Class : Executioner", PLUGIN_VERSION, "schmurgel1983")
	
	new index
	g_iExecutionerIndex = zp_class_zombie_register(zclass_name, zclass_info, zclass_health, zclass_speed, zclass_gravity)
	zp_class_zombie_register_kb(g_iExecutionerIndex, zclass_knockback)
	for (index = 0; index < sizeof zclass_model; index++)
		zp_class_zombie_register_model(g_iExecutionerIndex, zclass_model[index])
	for (index = 0; index < sizeof zclass_clawmodel; index++)
		zp_class_zombie_register_claw(g_iExecutionerIndex, zclass_clawmodel[index])
}

public plugin_init()
{
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_event("DeathMsg", "event_player_death", "a")
	
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fwd_Knife_PriAtk_Post", 1)
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fwd_Knife_SecAtk_Post", 1)
	
	cvar_Primary = register_cvar("zp_executioner_pri", "1")
	cvar_PrimarySpeed = register_cvar("zp_executioner_pri_speed", "0.33")
	cvar_Secondary = register_cvar("zp_executioner_sec", "1")
	cvar_SecondarySpeed = register_cvar("zp_executioner_sec_speed", "0.33")
	cvar_Nemesis = register_cvar("zp_executioner_nemesis", "0")
	
	register_cvar("Executioner_version", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY)
	set_cvar_string("Executioner_version", PLUGIN_VERSION)
	
	g_iMaxPlayers = get_maxplayers()
}

public client_putinserver(id) g_bExecutioner[id] = false

public client_disconnected(id) g_bExecutioner[id] = false

public plugin_natives()
{
	set_module_filter("module_filter")
	set_native_filter("native_filter")
}

public module_filter(const module[])
{
	if (equal(module, LIBRARY_NEMESIS))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

/*================================================================================
 [Main Forwards]
=================================================================================*/

public event_round_start()
{
	for (new id = 1; id <= g_iMaxPlayers; id++)
		g_bExecutioner[id] = false
}

public event_player_death() g_bExecutioner[read_data(2)] = false

public fwd_Knife_PriAtk_Post(ent)
{
	if (!get_pcvar_num(cvar_Primary))
		return HAM_IGNORED;
	
	static owner
	owner = ham_cs_get_weapon_ent_owner(ent)
	
	if (!g_bExecutioner[owner])
		return HAM_IGNORED
	
	static Float:Speed, Float:Primary, Float:Secondary
	Speed = get_pcvar_float(cvar_PrimarySpeed)
	Primary = get_pdata_float(ent, m_flNextPrimaryAttack, OFFSET_LINUX_WEAPONS) * Speed
	Secondary = get_pdata_float(ent, m_flNextSecondaryAttack, OFFSET_LINUX_WEAPONS) * Speed
	
	if (Primary > 0.0 && Secondary > 0.0)
	{
		set_pdata_float(ent, m_flNextPrimaryAttack, Primary, OFFSET_LINUX_WEAPONS)
		set_pdata_float(ent, m_flNextSecondaryAttack, Secondary, OFFSET_LINUX_WEAPONS)
	}
	
	return HAM_IGNORED;
}

public fwd_Knife_SecAtk_Post(ent)
{
	if (!get_pcvar_num(cvar_Secondary))
		return HAM_IGNORED;
	
	static owner
	owner = ham_cs_get_weapon_ent_owner(ent)
	
	if (!g_bExecutioner[owner])
		return HAM_IGNORED
	
	static Float:Speed, Float:Primary, Float:Secondary
	Speed = get_pcvar_float(cvar_SecondarySpeed)
	Primary = get_pdata_float(ent, m_flNextPrimaryAttack, OFFSET_LINUX_WEAPONS) * Speed
	Secondary = get_pdata_float(ent, m_flNextSecondaryAttack, OFFSET_LINUX_WEAPONS) * Speed
	
	if (Primary > 0.0 && Secondary > 0.0)
	{
		set_pdata_float(ent, m_flNextPrimaryAttack, Primary, OFFSET_LINUX_WEAPONS)
		set_pdata_float(ent, m_flNextSecondaryAttack, Secondary, OFFSET_LINUX_WEAPONS)
	}
	
	return HAM_IGNORED;
}

public zp_fw_core_infect_post(id, attacker)
{
	if (zp_class_zombie_get_current(id) == g_iExecutionerIndex)
	{
		if (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && zp_class_nemesis_get(id) && !get_pcvar_num(cvar_Nemesis)) return
		
		g_bExecutioner[id] = true
	}
}

public  zp_fw_core_cure_post(id) g_bExecutioner[id] = false

/*================================================================================
 [Stocks]
=================================================================================*/

stock ham_cs_get_weapon_ent_owner(entity)
{
	if (pev_valid(entity) != 2)
		return 0;
	
	return get_pdata_cbase(entity, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS);
}
