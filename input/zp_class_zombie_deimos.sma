/*

You don't want to be able to remove Sniper or Survivor weapon.

*/

/* ==================================================== 
Name: Deimos Zombie
Type: Zombie Class
Desc: Press +Attack2 to Drop Human Weapon
Edit: Dias Leon
This zombie class made by Petr & 5c0r.
==================================================== */

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <zombie_plague_advance>
#include <fun>
#include <hamsandwich>
#include <fakemeta_util>

#define PLUGIN "[ZP] ZClass: Galaxy"
#define VERSION "1.1"
#define AUTHOR "Petr+5cor"

new const zclass_name[] = { "Galaxy" }
new const zclass_info[] = { "Drop Weapon [MOUSE2]" }
new const zclass_model[] = { "zombie_Galaxy" }
new const zclass_clawmodel[] = { "v_knife_Galaxy.mdl" }
const zclass_health = 6200
const zclass_speed = 260
const Float:zclass_gravity = 0.82
const Float:zclass_knockback = 0.00

new beamSpr, deimos_spr
new const deimos_sound[] = "zombie_plague/Galaxy.wav"

// Cvars
new pcvar_distance
new cvar_cooldown // Cooldown when dropped the weapon of human 

new g_deimos

new g_maxplayers
new is_cooldown[33] = 0
new bool:g_cd[33]
new cvar_nemesis

#define PRIMARY_WEAPONS_BIT_SUM ((1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)) // You can allways add more  

public plugin_precache() 
{ 
    g_deimos = zp_register_zombie_class(zclass_name, zclass_info, zclass_model, zclass_clawmodel, zclass_health, zclass_speed, zclass_gravity, zclass_knockback) 
    beamSpr = precache_model("sprites/lgtning.spr") 
    deimos_spr = precache_model("sprites/deimosexp.spr") 
    precache_sound(deimos_sound) 
} 

public plugin_init()  
{ 
    register_plugin(PLUGIN, VERSION, AUTHOR) 
    pcvar_distance = register_cvar ( "zp_deimos_distance", "1000" ) 
    cvar_cooldown = register_cvar("zp_deimos_shot_cooldown","35") 
    cvar_nemesis = register_cvar("zp_deimos_nemesis", "1") 
    g_maxplayers = get_maxplayers() 
    register_logevent("roundStart", 2, "1=Round_Start") 
    register_forward(FM_CmdStart, "fwd_cmd_start") 
    RegisterHam(Ham_Spawn,"player","fw_PlayerSpawn_Post",1) 
} 

public fw_PlayerSpawn_Post(id) 
{ 
    // Not alive... 
    if(!is_user_alive(id)) 
        return HAM_IGNORED 
    if(cvar_nemesis == 1) 
    { 
        if(zp_get_user_zombie_class(id) == g_deimos && zp_get_user_zombie(id)) 
        { 
            g_cd[id] = true 
        } 
        } else { 
        if(zp_get_user_zombie_class(id) == g_deimos && zp_get_user_zombie(id) && !zp_get_user_nemesis(id)) 
        { 
            g_cd[id] = true 
        }     
    } 
     
    return HAM_IGNORED 
}   

public fwd_cmd_start(id, uc_handle, seed)  
{ 
    if(cvar_nemesis == 1) 
    { 
        if (!is_user_alive(id) || !zp_get_user_zombie(id) || g_cd[id] ) 
            return FMRES_IGNORED 
        } else { 
        if (!is_user_alive(id) || !zp_get_user_zombie(id) || g_cd[id] || zp_get_user_nemesis(id) ) 
            return FMRES_IGNORED 
    } 
     
    if (zp_get_user_zombie_class(id) != g_deimos) 
        return FMRES_IGNORED 
     
    static buttons 
    buttons = get_uc(uc_handle, UC_Buttons) 
     
    // If you press Mouse 2 and the drop weapon function is called
    if(buttons & IN_ATTACK2) { 
        drop_weapon(id) // Here we drop their weapon
        g_cd[id] = true 
    } 
     
    buttons &= ~IN_ATTACK2 
    set_uc(uc_handle, UC_Buttons, buttons) 
     
    return FMRES_HANDLED 
} 

// Here we drop the weapon

drop_weapon(id) 
{ 
    new target, body 
    static Float:start[3] 
    static Float:aim[3] 
     
    pev(id, pev_origin, start) 
    fm_get_aim_origin(id, aim) 
     
    start[2] += 16.0; // raise 
    aim[2] += 16.0; // raise 
    get_user_aiming ( id, target, body, pcvar_distance ) 
    
	// Go if they're alive, not a zombie, not a survivor and not a sniper.
    if( is_user_alive( target ) && !zp_get_user_zombie( target ) && !zp_get_user_survivor( target ) && !zp_get_user_sniper( target ) ) 
    {     
        message_begin(MSG_BROADCAST ,SVC_TEMPENTITY) 
        write_byte(TE_EXPLOSION) 
        engfunc(EngFunc_WriteCoord, aim[0]) 
        engfunc(EngFunc_WriteCoord, aim[1]) 
        engfunc(EngFunc_WriteCoord, aim[2]) 
        write_short(deimos_spr) 
        write_byte(10) 
        write_byte(30) 
        write_byte(4) 
        message_end() 
         
        emit_sound(id, CHAN_WEAPON, deimos_sound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM) 
         
        drop(target) 
    }     
     
    message_begin(MSG_BROADCAST,SVC_TEMPENTITY) 
    write_byte(0) 
    engfunc(EngFunc_WriteCoord,start[0]); 
    engfunc(EngFunc_WriteCoord,start[1]); 
    engfunc(EngFunc_WriteCoord,start[2]); 
    engfunc(EngFunc_WriteCoord,aim[0]); 
    engfunc(EngFunc_WriteCoord,aim[1]); 
    engfunc(EngFunc_WriteCoord,aim[2]); 
    write_short(beamSpr); // sprite index 
    write_byte(0); // start frame 
    write_byte(30); // frame rate in 0.1's 
    write_byte(10); // life in 0.1's 
    write_byte(100); // line width in 0.1's 
    write_byte(10); // noise amplititude in 0.01's 
    write_byte(200); // red 
    write_byte(200); // green 
    write_byte(0); // blue 
    write_byte(100); // brightness 
    write_byte(50); // scroll speed in 0.1's 
    message_end(); 
    set_task( get_pcvar_float(cvar_cooldown), "reset_cooldown2", id ); 
} 

public zp_user_infected_post(id, infector) 
{ 
    if ((zp_get_user_zombie_class(id) == g_deimos) && !zp_get_user_nemesis(id)) 
    { 
        is_cooldown[id] = 0 
        g_cd[id] = false 
    } 
} 

public reset_cooldown2(id) 
{ 
    g_cd[id] = false 
    client_print( id, print_chat, "[ GEEK-GAMING ] Now. You can use your Ability. Press +Attack2" ) 
} 

public zp_user_humanized_post(id) 
{ 
    remove_task(id) 
    is_cooldown[id] = 0 
} 

public roundStart() 
{ 
    for (new i = 1; i <= g_maxplayers; i++) 
    { 
        is_cooldown[i] = 0
        remove_task(i)
    } 
} 

stock drop(id)
{
    new weapons[32], num
    get_user_weapons(id, weapons, num)
    for (new i = 0; i < num; i++) {
        if (PRIMARY_WEAPONS_BIT_SUM & (1<<weapons[i]))
        { 
            static wname[32]
            get_weaponname(weapons[i], wname, sizeof wname - 1)
            engclient_cmd(id, "drop", wname)
        }
    }
}