/*                    [ZP] Addon: Critical Hit
				by !Morte
	
	#Description :
			Make a random critical hit when you are shooting an a enemy
	
	#Cvars : 
			zp_criticalhit_damage "3.0" // Damage Multiplier
			
	#Credits : 
			meTaLiCroSS: From his "custom form" :P

	#Changelog : 
			v1.0: Plugin Release
			v1.1: Added some sounds and effects
			v1.2: Code fix, delete some redundant things and change some other things
*/

#include < amxmodx >
#include < hamsandwich >
#include < fakemeta >
#include < fun >
#include < zombieplague >

new const sound_critical[] = "critical_hit/critical_hit.wav"

new cvar_criticaldamage
new gSyncHud

public plugin_precache( ) engfunc( EngFunc_PrecacheSound, sound_critical )

public plugin_init( )
{
	register_plugin( "Critical Hits", "1.2", "!Morte" )
	
	cvar_criticaldamage = register_cvar( "zp_criticalhit_damage", "3.0" )
	
	RegisterHam( Ham_TakeDamage, "player", "fw_TakeDamage" )
	
	gSyncHud = CreateHudSyncObj( );
}

public fw_TakeDamage( victim, inflictor, attacker, Float:damage, damage_type )
{	
	if( !zp_get_user_zombie( attacker ) )
	{
		if( random_num( 0, 100 ) < random_num( 0, 100 ) < random_num( 0, 100 ) )
		{
			SetHamParamFloat( 4, damage *= get_pcvar_float( cvar_criticaldamage ) )
			
			client_cmd( attacker, "spk ^"%s^"", sound_critical )
			
			set_hudmessage( 0, 255, 0, -1.0, -1.0, 0, 6.0, 1.1, 0.0, 0.0, 1 )
			ShowSyncHudMsg( attacker, gSyncHud, "%d^nCritical Hit!", floatround( damage ) )
		}
		
		SetHamParamFloat( 4, damage )
	}
	
	return HAM_IGNORED;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1034\\ f0\\ fs16 \n\\ par }
*/
