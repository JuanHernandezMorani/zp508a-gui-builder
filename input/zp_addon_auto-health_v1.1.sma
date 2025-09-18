/* =========================================
1. Description
- When you get infect, you will get a calculated health by number of players and number of zombies
- I hope this plugin will make your zombie server balanced about health
	--- I saw much server unbalance... 32 player, 2 zombie but zombie health: 2000 -> Quick Death

2. Calculation
- Health = (Total Player / Total Zombie) * 1000

Example 1: In your server had Total 20 player and 5 zombies
	=> Health = (20 / 5) * 1000
	<=> Health = 4000HP

Example 2: In your server had Total 32 player and 10 zombies
	=> Health = (32 / 10) * 1000
	<=> Health = 3200HP

Example 3: In your server had Total 32 player and 2 zombies
	=> Health = (32 / 2) * 1000
	<=> Health = 16000HP (Just lile first zombie )

3. Cvar
- zp_auto_health 1 // Default: 1

4. Credits
- fengxy | His idea
- Dias | Make this plug
========================================= */

#include <amxmodx>
#include <fun>
#include <zombieplague>

#define PLUGIN "[ZP] Addon: Auto Health"
#define VERSION "1.1"
#define AUTHOR "Dias"

new cvar_auto_health, cvar_stock_health
new g_maxplayers

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    g_maxplayers = get_maxplayers()
    
    cvar_auto_health = register_cvar("zp_auto_health", "1")
    cvar_stock_health = register_cvar("zp_stock_health", "1000")
}

public zp_user_infected_post(id)
{
    // Nemesis? no need la
    if(zp_get_user_nemesis(id)) return;
    
    if(get_pcvar_num(cvar_auto_health))
    {
        new health
        health = (get_player_count() / get_zombie_count()) * get_pcvar_num(cvar_stock_health)
        set_user_health(id, health)
    }
}

get_zombie_count()
{
    new count
    for(new i = 0; i < g_maxplayers; i++)
    {
        if(is_user_connected(i) && zp_get_user_zombie(i))
            count++
    }
    
    return count
}

get_player_count()
{
    new count
    for(new i = 0; i < g_maxplayers; i++)
    {
        if(is_user_connected(i))
            count++
    }
    
    return count
}  
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
