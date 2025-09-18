#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fun>
#include <cs_ham_bots_api>
#include <zp50_class_zombie>
#include <zp50_core>
#include <zp50_colorchat>

new const zombieclass1_name[] = "Half blooded Zombie"
new const zombieclass1_info[] = "Take 50% damage and skill !"
new const zombieclass1_models[][] = { "zombie_source" }
new const zombieclass1_clawmodels[][] = { "models/zombie_plague/v_knife_zombie.mdl" }
const zombieclass1_health = 1800
const Float:zombieclass1_speed = 1.00
const Float:zombieclass1_gravity = 0.9
const Float:zombieclass1_knockback = 1.0

new using_skill[33]
new skill_cd[33]
new cvar_cd
new cvar_duration


new g_ZombieClassID

public plugin_init()
{
       register_plugin("[ZP] Class: Half blooded Zombie", "1.0", "Catastrophe")
      
       RegisterHam(Ham_TakeDamage, "player", "Fw_TakeDamage")
       RegisterHamBots(Ham_TakeDamage, "Fw_TakeDamage")

       register_clcmd("drop", "skill")

       cvar_cd = register_cvar("zp_hbz_skill_cd", "60.0")
       cvar_duration = register_cvar("zp_hbz_skill_duration", "5.0")
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

        set_task(1.0, "advertise")
        
}

public advertise()
{
       for (new i = 1; i <get_maxplayers(); i++)
       {
           if(is_user_alive(i) && zp_core_is_zombie(i) && zp_class_zombie_get_current(i) == g_ZombieClassID)
           {
           zp_colored_print(i, "Press G to use your skill^x03 Half blood houl !!")
           set_task(30.0, "newadd", i)
           }
       }
}

public newadd(i)
{
           if(is_user_alive(i) && zp_core_is_zombie(i) && zp_class_zombie_get_current(i) == g_ZombieClassID)
           {
              zp_colored_print(i, "Press G to use your skill^x03 Half blood houl !!")
              set_task(30.0, "newadd", i)
           }
 
}

public Fw_TakeDamage(victim, inflictor, attacker, Float:damage, dmgbits)
{
        if(!is_user_alive(victim) || !is_user_alive(attacker) || !zp_core_is_zombie(victim) || zp_core_is_zombie(attacker) || zp_class_zombie_get_current(victim) != g_ZombieClassID)
        return

        if(using_skill[victim])        
        { 
	SetHamParamFloat(4, 0.0)
        ExecuteHam(Ham_TakeDamage, attacker, 0, victim, 1.0, DMG_BULLET)
        }

        else
        {
        SetHamParamFloat(4, damage*0.5)
        }
}

public client_putinserver(id)
{
       skill_cd[id] = false
       using_skill[id] = false
}

public client_disconnect(id)
{
       skill_cd[id] = false
       using_skill[id] = false
}


public zp_fw_core_spawn_post(id)
{

       skill_cd[id] = false
       using_skill[id] = false
       set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderNormal, 16) 

}

public zp_fw_core_cure_post(id)
{

       skill_cd[id] = false
       using_skill[id] = false
       set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderNormal, 16) 

}

public zp_fw_core_infect_post(id)
{

       skill_cd[id] = false
       using_skill[id] = false
       set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderNormal, 16) 

}

public skill(id)
{
       if(!is_user_alive(id) || !zp_core_is_zombie(id) || zp_class_zombie_get_current(id) != g_ZombieClassID)
       return

       if(using_skill[id])
       {
       zp_colored_print(id, "Half blood houl already in^x03 use !")
       return
       }

       if(skill_cd[id])
       {
       zp_colored_print(id, "Half blood houl in^x03 cooldown !")
       return
       }

       skill_cd[id] = true
       using_skill[id] = true
       ScreenFade(id, get_pcvar_float(cvar_duration), 255, 100, 0, 120)
       set_user_rendering(id, kRenderFxGlowShell, 255, 100, 0, kRenderNormal, 16)

       zp_colored_print(id, "Half blood houl used you are^x03 invulnerable for %.f seconds", get_pcvar_float(cvar_duration)) 

       set_task(get_pcvar_float(cvar_duration), "removeskill", id)
       set_task(get_pcvar_float(cvar_cd), "removeskillcd", id)
 
}

public removeskill(id)
{
       using_skill[id] = false
       set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderNormal, 16)   
       zp_colored_print(id, "Half blood houl^x03 ended !") 
}

public removeskillcd(id)
{
       skill_cd[id] = false
       zp_colored_print(id, "Half blood houl is ready to use^x03 Press G !") 
}

stock ScreenFade(plr, Float:fDuration, red, green, blue, alpha)
{
    new i = plr ? plr : get_maxplayers();
    if( !i )
    {
        return 0;
    }
    
    message_begin(plr ? MSG_ONE : MSG_ALL, get_user_msgid( "ScreenFade"), {0, 0, 0}, plr);
    write_short(floatround(4096.0 * fDuration, floatround_round));
    write_short(floatround(4096.0 * fDuration, floatround_round));
    write_short(4096);
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(alpha);
    message_end();
    
    return 1;
}