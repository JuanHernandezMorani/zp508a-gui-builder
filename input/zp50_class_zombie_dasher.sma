/*================================================================================
	
	-----------------------------------
	-*- [ZP] Class: Zombie: Dasher -*-
	-----------------------------------
	
	This plugin is part of Zombie Plague Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
================================================================================*/

#include <amxmodx>
#include <zp50_class_zombie>
#include <engine>
#include <fakemeta_util>
#include <hamsandwich>
#include <zp50_colorchat>


// Classic Zombie Attributes
new const zombieclass1_name[] = "Dasher Zombie"
new const zombieclass1_info[] = "Has Dash Ability"
new const zombieclass1_models[][] = { "zombie_source" }
new const zombieclass1_clawmodels[][] = { "models/zombie_plague/v_knife_zombie.mdl" }
const zombieclass1_health = 1800
const Float:zombieclass1_speed = 1.05
const Float:zombieclass1_gravity = 0.9
const Float:zombieclass1_knockback = 1.0

// Skill: Mahadash
#define MAHADASH_DAMAGE 95.0
// End Of Skill: Mahadash

new g_ZombieClassID, cvar_dash_cd, _gclassid
new bool:g_cd[33], g_mahadashing[33]

public plugin_precache()
{
	register_plugin("[ZP] Class: Dasher Zombie", "1.0", "Catastrophe")
        register_clcmd("drop","do_mahadash")
        register_touch("player", "*", "fw_dash_touch")
	
	new index
	
	g_ZombieClassID = zp_class_zombie_register(zombieclass1_name, zombieclass1_info, zombieclass1_health, zombieclass1_speed, zombieclass1_gravity)
	zp_class_zombie_register_kb(g_ZombieClassID, zombieclass1_knockback)
	for (index = 0; index < sizeof zombieclass1_models; index++)
		zp_class_zombie_register_model(g_ZombieClassID, zombieclass1_models[index])
	for (index = 0; index < sizeof zombieclass1_clawmodels; index++)
		zp_class_zombie_register_claw(g_ZombieClassID, zombieclass1_clawmodels[index])
        cvar_dash_cd = register_cvar("zp_dash_cd","30.0")
       
}

public plugin_cfg()
{

       _gclassid = zp_class_zombie_get_id("Dasher Zombie")

}

// ================== Madadash =======================
public do_mahadash(ent)
{
	if(!pev_valid(ent) || g_cd[ent] || zp_class_zombie_get_current(ent) != _gclassid || !zp_core_is_zombie(ent))
		return	
	
	
        g_cd[ent] = true
        g_mahadashing[ent] = true

	set_task(0.1, "mahadash_now", ent)
        zp_colored_print(ent, "^x04[ZP Dasher Zombie] ^x01You just use your dash now u will be able to use it ^x03%f^x01 seconds later",get_pcvar_float(cvar_dash_cd))
    
        set_task(get_pcvar_float(cvar_dash_cd),"resetcd",ent)
        set_task(1.0,"resetmd",ent)
 
 
}

public mahadash_now(ent)
{
	
	if(!pev_valid(ent))
		return
	
	static Float:Origin[3]
	get_position(ent, 1000.0, 0.0, 0.0, Origin)
	
	hook_ent2(ent, Origin, 2000.0)
}

public fw_dash_touch(ent, id)
{
	if(!pev_valid(id) || !g_mahadashing[ent] || zp_class_zombie_get_current(ent) != _gclassid || !zp_core_is_zombie(ent))
		return

	
	if(is_user_alive(id))
	{
		ExecuteHam(Ham_TakeDamage, id, 0, id, MAHADASH_DAMAGE, DMG_SLASH)
		shake_screen(id)
		
		static Float:Velocity[3]
		Velocity[0] = random_float(1000.0, 2000.0)
		Velocity[1] = random_float(1000.0, 2000.0)
		Velocity[2] = random_float(1000.0, 2000.0)
		
		set_pev(id, pev_velocity, Velocity)
	}
}

public resetcd(id)
{

       g_cd[id] = false
       zp_colored_print(id, "^x04[ZP Dasher Zombie]^x01 You can use your dash again now !!")
   
}

public resetmd(id)
{

       g_mahadashing[id] = false
       
   
}

stock shake_screen(id)
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenShake"),{0,0,0}, id)
	write_short(1<<14)
	write_short(1<<13)
	write_short(1<<13)
	message_end()
}

stock get_position(ent, Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(ent, pev_origin, vOrigin)
	pev(ent, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(ent, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	
	pev(ent, pev_origin, EntOrigin)
	
	static Float:distance_f
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	
	if (distance_f > 60.0)
	{
		new Float:fl_Time = distance_f / speed
		
		fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
		fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time
	} else {
		fl_Velocity[0] = 0.0
		fl_Velocity[1] = 0.0
		fl_Velocity[2] = 0.0
	}

	entity_set_vector(ent, EV_VEC_velocity, fl_Velocity)
}