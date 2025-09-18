#include <amxmodx>
#include <zp50_core>
#include <hamsandwich>
#include <cs_ham_bots_api>
#include <zp50_colorchat> 
#include <zp50_ammopacks>
#include <zp50_class_survivor>


new cvar_reward, cvar_multiplier, cvar_end_time, cvar_survivor, g_iMaxPlayers

new damage[33], combo_level[33], reward[33]

public plugin_init()
{

      register_plugin("[ZP50] Addon: Damage Combo", "1.1", "catastrophe")
 
      register_event("HLTV", "event_newround", "a", "1=0", "2=0")

      RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
      RegisterHamBots(Ham_TakeDamage, "fw_TakeDamage")
 
      cvar_multiplier = register_cvar("zp_combo_multiplier", "150")
      cvar_end_time = register_cvar("zp_combo_end_time", "4.0")
      cvar_reward = register_cvar("zp_combo_reward", "3")
      cvar_survivor = register_cvar("zp_combo_survivor", "0")

      g_iMaxPlayers = get_maxplayers()

} 

public event_newround()
{
       for (new i = 0; i <= g_iMaxPlayers; i++)
	{
		
	    combo_level[i] = 0 
            damage[i] = 0
            reward[i] = 0
                 
        }  
}


public zp_user_infected_post(id, infector)
{

       combo_level[id] = 0 
       damage[id] = 0
       reward[id] = 0

}

public fw_TakeDamage(victim, inflictor, attacker, Float:idamage, damage_bits)
{

    if(is_user_connected(victim) && is_user_connected(attacker) && is_user_alive(victim) && zp_core_is_zombie(victim) && !zp_core_is_zombie(attacker))
    {	
                if(zp_class_survivor_get(attacker) && get_pcvar_num(cvar_survivor) == 0)
                return; 

                remove_task(attacker+672)   
                                
                new fdamage = floatround(idamage)

		damage[attacker] += fdamage
                check(attacker)
                set_task(get_pcvar_float(cvar_end_time), "ca", attacker+672) 
  

    }
   
}

public check(id)
{  

   if(is_user_connected(id) && is_user_alive(id))       
   {
                  if(combo_level[id] == 0)
                  {
                  combo_level[id]++
                  }

                  
                  while(damage[id] >= combo_level[id]*combo_level[id]*get_pcvar_num(cvar_multiplier))
                  {                                      
                     damage[id] = 0 
                     combo_level[id]++
                     reward[id] += get_pcvar_num(cvar_reward)*(combo_level[id]-1) 
                  }

                  

                  set_hudmessage(255, 0, 0, 0.30, 0.60, 1, get_pcvar_float(cvar_end_time), get_pcvar_float(cvar_end_time))
                  show_hudmessage(id, "[Combo : %d]^n[Damage: %d/%d]", combo_level[id], damage[id], combo_level[id]*combo_level[id]*get_pcvar_num(cvar_multiplier))

   }
   

}

public ca(id)
{
    id -= 672;
   
    if(!is_user_connected(id) && !is_user_alive(id))
    return;  

    set_hudmessage(255, 0, 0, 0.30, 0.60, 1, 3.0, 3.0) 
    show_hudmessage(id, "Combo %d Ended^nYour earned %d Ammo packs", combo_level[id], reward[id]) 
    zp_ammopacks_set(id, zp_ammopacks_get(id) + reward[id])       


    combo_level[id] = 0 
    damage[id] = 0
    reward[id] = 0
      
   
}

