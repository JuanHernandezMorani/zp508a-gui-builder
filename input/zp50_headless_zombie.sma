#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <cs_ham_bots_api>
#include <zp50_class_zombie>
#include <zp50_core>

new const zombieclass1_name[] = "Headless Zombie"
new const zombieclass1_info[] = "No Head shots !"
new const zombieclass1_models[][] = { "zombie_source" }
new const zombieclass1_clawmodels[][] = { "models/zombie_plague/v_knife_zombie.mdl" }
const zombieclass1_health = 1800
const Float:zombieclass1_speed = 1.00
const Float:zombieclass1_gravity = 0.9
const Float:zombieclass1_knockback = 1.0


new g_ZombieClassID

public plugin_init()
{
       register_plugin("[ZP] Class: Headless Zombie", "1.0", "Catastrophe")
      
       RegisterHam(Ham_TraceAttack, "player", "fw_traceattack")
       RegisterHamBots(Ham_TraceAttack, "fw_traceattack")
}

public plugin_precache()
{
	
	
	new index
	
	g_ZombieClassID = zp_class_zombie_register(zombieclass1_name, zombieclass1_info, zombieclass1_health, zombieclass1_speed, zombieclass1_gravity)
	zp_class_zombie_register_kb(g_ZombieClassID, zombieclass1_knockback)
	for (index = 0; index < sizeof zombieclass1_models; index++)
		zp_class_zombie_register_model(g_ZombieClassID, zombieclass1_models[index])
	for (index = 0; index < sizeof zombieclass1_clawmodels; index++)
		zp_class_zombie_register_claw(g_ZombieClassID, zombieclass1_clawmodels[index]) 
        
}

public fw_traceattack(victim, attacker, Float:damage, direction[3], traceresult, dmgbits)
{
        if(!is_user_alive(victim) || zp_class_zombie_get_current(victim) != g_ZombieClassID)
        return

	if(get_tr2(traceresult, TR_iHitgroup, HIT_HEAD))
	{
		set_tr2(traceresult, TR_iHitgroup, LEFTLEG)
	}
}