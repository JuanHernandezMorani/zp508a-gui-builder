#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <zp50_core>
#include <zp50_items>
#include <zp50_class_nemesis>

#define DEF_LIGHT "g"

new item_md, md_used, cvar_duration

public plugin_init()
{
    register_plugin("[ZP50] Midnight's Darkness", "1.3", "Catastrophe")
    register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
    
    cvar_duration = register_cvar("zp_midnight_duration", "0.0")
  
}
public plugin_precache( )
{
    item_md = zp_items_register("Midnight's Darkness", 65)
    
    precache_sound("ambience/alien_hollow.wav")

}

public zp_fw_items_select_pre(player, itemid, ig)
{
    if (itemid == item_md)
    {
        if (md_used)
        {
            return ZP_ITEM_NOT_AVAILABLE
        }
        else if(!zp_core_is_zombie(player) || zp_class_nemesis_get(player))
        {
            return ZP_ITEM_DONT_SHOW
        }
        else
        {
        return ZP_ITEM_AVAILABLE
        }

    }
    return ZP_ITEM_AVAILABLE
}

public zp_fw_items_select_post(player, itemid)
{
    if (itemid == item_md)
    {
            client_print(player, print_chat, "[ZP] You bought Midnight's Darkness, Everything goes dark now.")
            set_hudmessage(255, 10, 10, -1.0, -1.0, 2, 6.0, 12.0)
            show_hudmessage(0 , "The clock struck twelve and here comes the wrath of zombies")
            set_task(10.0, "md_start")
    }
    return PLUGIN_CONTINUE
}

public event_round_start()
{
    md_used = false
    
    server_cmd("zp_lighting %s", DEF_LIGHT)
   
}

public md_start()
{    
    md_used = true
    
    server_cmd("zp_lighting a")  
    
    client_cmd(0, "spk sound/ambience/alien_hollow.wav")

    if(get_pcvar_float(cvar_duration) > 0)
    {
    set_task(get_pcvar_float(cvar_duration), "md_end")
    }
}

public md_end()
{
    md_used = false
    
    server_cmd("zp_lighting %s", DEF_LIGHT)
}
