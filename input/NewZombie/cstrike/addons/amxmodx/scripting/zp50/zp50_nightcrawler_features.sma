/*================================================================================
	
	--------------------------
	-*- [ZP] NightCrawler Features -*-
	--------------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
================================================================================*/

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fun>
#include <zp50_core>
#include <zp50_class_nightcrawler>

new g_MsgSetFOV



public plugin_init()
{
	register_plugin("[ZP] NightCrawler", ZP_VERSION_STRING, "ZP Dev Team")
	g_MsgSetFOV = get_user_msgid("SetFOV")
	RegisterHam(Ham_TakeDamage, "player", "OnNightCrawlerDamagePost")
}



public zp_fw_core_infect_post(id, attacker)
{
	if(zp_class_nightcrawler_get(id))
	{
		message_begin(MSG_ONE, g_MsgSetFOV, _, id)
		write_byte(90)
		message_end()

		set_user_footsteps(id, 1)
	}

}


public OnNightCrawlerDamagePost(victim, inflictor, attacker, Float:damage, dmgtype)
{
	if(zp_class_nightcrawler_get(victim) && dmgtype & DMG_FALL)
		return HAM_SUPERCEDE;
		
	

	return HAM_IGNORED;

}