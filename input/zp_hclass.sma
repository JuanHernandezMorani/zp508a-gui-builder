/* 
Human Classes for zombie plague, invoke menu for classes on J key or by typing /hc in chat
You can edit this plug however it fit your needs.

TO DO list:

Cvars
external comfiguration
More classes
Make user choice remember thru whole map time, just like it was done for zombies
bots support

classes:

Armorer - Gets 20 AP
Pounder - Gets 300 HP
Jumper - Half Gravity applies to him (like leaper zombie)
Frost Soldier - Gets 5 Frost Nades
Firebat - Gets 5 Napalm Nades
Light Handler - Gets 5 Flares and huge light aura
Runner - gets +50 on speed

Sharpshooter - No Recoil for his weapons
Phalanxer - gets Shield&Deagle
Laser Aimer - gets Laser Sight
FeatherFoot - No damage from falls
Leaper - Can do Leap every 4 seconds
Zombie Seeker - gets radar that shows zombies
Doc - gets + 500 HP when infected. HP's are added to current HP amount of his zombie class

Shotgunner - receives both shotguns along with initial weaponry
SubMachine Kid - receives SMG's along with initial weaponry (ump45, mp5navy and p90)
Blinder - receives one flashbang grenade when infected
Wicked One - becomes invulnerable for 5 seconds right after infection
Thief - steals random number of ammo packs from infector, just before infection
Armored Later - if he gets infected, he will receive 100 armor as a zombie 
Stealth Warrior - gets semi-visibility

Man Of Despair - deals +10% Damage
Deceiver - Blinding zombies who looks at him
Tremor Maker - Shakes zombies screen who looks at him
Pistolero - gets all handguns along with initial weaponry
Blaster - gets C4, that makes 500 dmg when dropped and zombie steps on it
Medic - gets one extra antidote, 10 seconds after infection (cannot choose another class when humanized)
Samurai - gets faster knife attack rate + double damage for knife (will add model change support, for katana)

Mutant  - becomes nemesis for 10 seconds if he gets infected. After 10 secs, he will be transformed to a regular zombie
Spy - can see zombies health and ammo packs and # of zombies remained
Tough Guy - gets M249 para machinegun
Seer - Gets nightvision goggles
Last man - will become survivor if he is only remaining human
Slapper - Slaps zombies who even looks at him
Gambler - gets random class, can be any

Pogo Jumper - can use his weapons as a pogo stick 
Ghost Stalker - can go thru walls for 15 seconds upon infection
Sniper - gets awp & scout with increased damage
Cameraman - gets 3rd person camera view 
Wiseman - Can be infected only with headshot
KnockBacker - His weapons gets bigger knockback
Hacker - Ejects cd tray of zombies who looks at him

Disemboweler - Disembowels victims 
Leecher - Heals 5% HP of damage dealt
Collector - can pick up multiple weapons
Aurelius - Have aura that slows down zombies
Stealth Giver - Give aura of semi-visibility, but are a bit slower
Neutralizer - Neutralizes any ing grenade that is thrown near him and can't get infected by inf nade
Smoker - Gets smoke grenade when infected


*/

#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fun>
#include <xs>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>

#define TASK_AURA 547
#define IsPlayer(%1)	(1<=%1<=g_iMaxPlayers)
#define IsPogo(%1)	(g_bIsPogo & (1<<(%1 & 31)))
#define SetPogo(%1)	(g_bIsPogo |= (1<<(%1 & 31)))
#define RemovePogo(%1)	(g_bIsPogo &= ~(1<<(%1 & 31)))

new const g_GunEvents[][] = 
{
        "events/awp.sc",
        "events/g3sg1.sc",
        "events/ak47.sc",
        "events/scout.sc",
        "events/m249.sc",
        "events/m4a1.sc",
        "events/sg552.sc",
        "events/aug.sc",
        "events/sg550.sc",
        "events/m3.sc",
        "events/xm1014.sc",
        "events/usp.sc",
        "events/mac10.sc",
        "events/ump45.sc",
        "events/fiveseven.sc",
        "events/p90.sc",
        "events/deagle.sc",
        "events/p228.sc",
        "events/glock18.sc",
        "events/mp5n.sc",
        "events/tmp.sc",
        "events/elite_left.sc",
        "events/elite_right.sc",
        "events/galil.sc",
        "events/famas.sc"
};


const WEAPONS_BITSUM = (1<<CSW_KNIFE|1<<CSW_HEGRENADE|1<<CSW_FLASHBANG|1<<CSW_SMOKEGRENADE|1<<CSW_C4)
const PRIMARY_WEAPONS_BITSUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BITSUM = (1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)|(1<<CSW_P228)|(1<<CSW_USP)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)

const m_pPlayer = 		41
const m_flNextPrimaryAttack = 	46
const m_flNextSecondaryAttack =	47
const m_flTimeWeaponIdle = 	48 

new g_GunEventBits
new g_FMPrecacheEvent
new g_iMaxPlayers

new g_TouchGroundEnt
new g_bIsPogo

new sprite, boomsprite, g_msgHostageAdd, g_msgHostageDel, g_SayText, g_class, gmsgFade, gmsgShake, g_status_sync

new Float: cl_pushangle[33][3]
new Float:g_lastLeaptime[33]


new g_iCurrentWeapon[33]
new bool:got_class[33]

new bool:g_flare[33]
new bool:g_fire[33]
new bool:g_frost[33]
new bool:g_jumper[33]
new bool:g_phalanx[33]
new bool:g_armor[33]
new bool:g_pound[33]
new bool:g_stealth[33]
new bool:g_norecoil[33]
new bool:g_nofalldamage[33]
new bool:g_speed[33]
new bool:g_laser[33] 
new bool:g_leap[33]
new bool:g_radar[33]
new bool:g_doc[33]
new bool:g_shg[33]
new bool:g_smg[33]
new bool:g_blinder[33]
new bool:g_mad[33]
new bool:g_aps[33]
new bool:g_az[33]
new bool:g_dmgx[33]
new bool:g_blaster[33]
new bool:g_medic[33]
new bool:g_gunner[33]
new bool:g_samurai[33]
new bool:g_tremor[33]
new bool:g_flasher[33]
new bool:g_mutant[33]
new bool:g_spy[33]
new bool:g_heavy[33]
new bool:g_nvg[33]
new bool:g_srv[33]
new bool:g_dis[33]

new bool:g_pogo[33]
new bool:g_cam[33]
new bool:g_ghost[33]
new bool:g_snip[33]
new bool:g_gore[33]
new bool:g_leech[33]
new bool:g_cd[33]
new bool:g_head[33]
new bool:g_knock[33]
new bool:g_collector[33]
new bool:g_aurel[33]
new bool:g_sthg[33]
new bool:g_neut[33]
new bool:g_smoker[33]


public plugin_init()
{		
	register_plugin("[ZP] Addon: Human Classes", "1.6", "fiendshard")
	g_class = zp_register_extra_item("Buy One More Class", 10, ZP_TEAM_HUMAN)
	register_event("StatusValue", "showStatus", "be", "1=2", "2!0")
	register_event("Damage", "Event_Damage", "b", "2!0", "3=0", "4!0")
	register_event("HLTV", "NewRound", "a", "1=0", "2=0")
	register_event("DeathMsg", "DeathMsg", "a")
	register_clcmd("cheer", "ClCmdSelectclass")
	register_clcmd("say /hc", "ClCmdSelectclass")
	register_think("touchground_entity", "fw_Think")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Pre", 0)
	RegisterHam( Ham_Killed, "player", "fw_PlayerKilled_Post", 1)
	register_forward(FM_Touch,"FM_Touch_hook")
	
	register_forward(FM_PlayerPreThink, "FW_playerprethink")
	register_forward(FM_CmdStart, "fw_FMCmdStart", 1)
	register_forward(FM_PlaybackEvent, "fw_FMPlaybackEvent")
	unregister_forward(FM_PrecacheEvent, g_FMPrecacheEvent, 1)
	entity_set_string(g_TouchGroundEnt , EV_SZ_classname , "touchground_entity")
	RegisterHam(Ham_TakeDamage, "player", "Ham_PlayerTakeDamage", 0)
	RegisterHam(Ham_Spawn, "player", "fwHamPlayerSpawnPost", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_Knife_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_Knife_SecondaryAttack_Post", 1) 

	g_iMaxPlayers = get_maxplayers()
	g_TouchGroundEnt = create_entity("info_target")
	g_status_sync = CreateHudSyncObj()
	gmsgFade = get_user_msgid("ScreenFade")
	gmsgShake = get_user_msgid ("ScreenShake") 
	g_SayText = get_user_msgid("SayText")
	g_msgHostageAdd = get_user_msgid("HostagePos")
	g_msgHostageDel = get_user_msgid("HostageK")
	set_task (2.0,"radar_scan",_,_,_,"b")
	new weapon_name[24]
	for (new i = 1; i <= 30; i++)
	{
		if (!(WEAPONS_BITSUM & 1 << i) && get_weaponname(i, weapon_name, 23))
		{
			RegisterHam(Ham_Weapon_PrimaryAttack, weapon_name, "fw_Weapon_PrimaryAttack_Pre")
			RegisterHam(Ham_Weapon_PrimaryAttack, weapon_name, "fw_Weapon_PrimaryAttack_Post", 1)
		}
	}
}

public plugin_precache() 
{	
	sprite = precache_model("sprites/white.spr")
	boomsprite = precache_model("sprites/zerogxplode.spr")
	precache_model("models/rpgrocket.mdl")
	g_FMPrecacheEvent = register_forward(FM_PrecacheEvent, "fw_FMPrecacheEvent", 1)
}

public ClCmdSelectclass(id)
{
	if(zp_get_user_zombie(id) || zp_get_user_nemesis(id) || zp_get_user_survivor(id) || (got_class[id] == true))
	{
		return PLUGIN_HANDLED;
	}
	else if(!is_user_alive(id))
	{
		return PLUGIN_HANDLED;
	}
	else
	{
		human_menu(id)
	}
	return PLUGIN_CONTINUE;
}

public human_menu(id)
{
	new menu = menu_create("\yChoose Your Human Class:", "human_menu_handler")
	
	menu_additem(menu, "\wArmorer \y(+20 Armor)", "1", 0)
	menu_additem(menu, "\wPounder \y(+300 HP)", "2", 0)
	menu_additem(menu, "\wJumper \y(High Jump)", "3", 0)
	menu_additem(menu, "\wLeaper \y(Can Leap)", "4", 0)
	menu_additem(menu, "\wRunner \y(Fast Movement)", "5", 0)
	menu_additem(menu, "\wStealth Warrior \y(+Stealth)", "6", 0)
	menu_additem(menu, "\wFrost Soldier \y(FrostNade X5)", "7", 0)


	menu_additem(menu, "\wThief \y(Steals AP On Inf)", "8", 0)
	menu_additem(menu, "\wBlinder \y(+FB On Inf)", "9", 0)
	menu_additem(menu, "\wDoc \y(+500 HP On Inf)", "10", 0)
	menu_additem(menu, "\wWicked One \y(+Madness On Inf)", "11", 0)
	menu_additem(menu, "\wFeatherFoot \y(No Fall Damage)", "12", 0)
	menu_additem(menu, "\wArmored Later \y(+Armor On Inf)", "13", 0)
	menu_additem(menu, "\wLight Handler \y(Flare X5 & Light Aura)", "14", 0)	


	menu_additem(menu, "\wShotgunner \y(+Shotguns)", "15", 0)
	menu_additem(menu, "\wSubMachine Kid \y(+SMG's)", "16", 0)
	menu_additem(menu, "\wPhalanxer \y(Shield&Deagle)", "17", 0)
	menu_additem(menu, "\wSharpshooter \y(No Recoil)", "18", 0)
	menu_additem(menu, "\wLaser Aimer \y(Laser Sight)", "19", 0)
	menu_additem(menu, "\wZombie Seeker \y(Zombie Radar)", "20", 0)
	menu_additem(menu, "\wFirebat \y(NapalmNade X5)", "21", 0)
	
	
	menu_additem(menu, "\wMan Of Despair \y(+10% Damage)", "22", 0)
	menu_additem(menu, "\wBlaster \y(C4 Mine)", "23", 0)
	menu_additem(menu, "\wMedic \y(1 Extra Antidote)", "24", 0)
	menu_additem(menu, "\wPistolero \y(+All Guns)", "25", 0)
	menu_additem(menu, "\wSamurai \y(Fast Knife + Dmg)", "26", 0)
	menu_additem(menu, "\wTremor Maker \y(Shaking Screen)", "27", 0)
	menu_additem(menu, "\wDeceiver \y(Bliniding Zombies)", "28", 0)
	
	
	menu_additem(menu, "\wMutant \y(Nemesis On Inf)", "29", 0)
	menu_additem(menu, "\wSpy \y(Intel Gathering)", "30", 0)
	menu_additem(menu, "\wTough Guy \y(+M249 Para)", "31", 0)
	menu_additem(menu, "\wSeer \y(+NightVision)", "32", 0)
	menu_additem(menu, "\wLast Man \y(Survivor If Last)", "33", 0)
	menu_additem(menu, "\wSlapper \y(Slaps Zombies)", "34", 0)
	menu_additem(menu, "\wPogo Jumper \y(Pogo Weapons)", "35", 0)
	
	
	menu_additem(menu, "\wCameraman \y(3rd Person Cam)", "36", 0)
	menu_additem(menu, "\wGhost Stalker \y(+No Clip On Inf)", "37", 0)
	menu_additem(menu, "\wSniper \y(+Snipers & Damage)", "38", 0)
	menu_additem(menu, "\wDisemboweler \y(Explo Zombies)", "39", 0)
	menu_additem(menu, "\wLeecher \y(Steals HP)", "40", 0)
	menu_additem(menu, "\wHacker \y(Ejects CD)", "41", 0)
	menu_additem(menu, "\wWiseman \y(HS Inf Only)", "42", 0)
	
	menu_additem(menu, "\wKnockBacker \y(+Knockback)", "43", 0)
	menu_additem(menu, "\wCollector \y(Multi Weapons)", "44", 0)
	menu_additem(menu, "\wAurelius \y(Slow Aura)", "45", 0)
	menu_additem(menu, "\wStealth Giver \y(Stealth Aura)", "46", 0)
	menu_additem(menu, "\wNeutralizer \y(Disabling Inf Nades)", "47", 0)
	menu_additem(menu, "\wSmoker \y(+SG On Inf)", "48", 0)
	
	
	
	
	
	menu_additem(menu, "\wGambler \y(Random Class)", "51", 0)
	

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public human_menu_handler(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	new data[6], iName[64]
	new access, callback
	menu_item_getinfo(menu, item, access, data, 5, iName, 63, callback)
	new key = str_to_num(data)
	switch(key)
	{
		case 1:
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 1
			got_class[id] = true
			class_1(id)
		}
		case 2:
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 2
			got_class[id] = true
			class_2(id)
			
		}
		case 3: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 3
			got_class[id] = true
			class_3(id)
		}
		case 4: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 4
			got_class[id] = true
			class_4(id)
	
		}
		case 5: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 5
			got_class[id] = true
			class_5(id)
		}
		case 6: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 6
			got_class[id] = true
			class_6(id)
		}
		case 7: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 7
			got_class[id] = true
			class_7(id)
		}
		case 8: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 8
			got_class[id] = true
			class_8(id)
		}
		case 9: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 9
			got_class[id] = true
			class_9(id)
		}
		case 10: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 10
			got_class[id] = true
			class_10(id)
		}
		case 11: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 11
			got_class[id] = true
			class_11(id)
		}	
		case 12: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 12
			got_class[id] = true
			class_12(id)
		}
		case 13: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 13
			got_class[id] = true
			class_13(id)
		}
		case 14: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 14
			got_class[id] = true
			class_14(id)
		}
		case 15: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 15
			got_class[id] = true
			class_15(id)
		}
		case 16: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 16
			got_class[id] = true
			class_16(id)
		}
		case 17: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 17
			got_class[id] = true
			class_17(id)
		}
		case 18: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 18
			got_class[id] = true
			class_18(id)
		}
		case 19: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 19
			got_class[id] = true
			class_19(id)
		}
		case 20: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 20
			got_class[id] = true
			class_20(id)
		}
		case 21: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 21
			got_class[id] = true
			class_21(id)
		}
		case 22:
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 22
			got_class[id] = true
			class_22(id)
		}
		case 23: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 23
			got_class[id] = true
			class_23(id)
		}
		case 24: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 24
			got_class[id] = true
			class_24(id)
		}
		case 25: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 25
			got_class[id] = true
			class_25(id)
		}
		case 26: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 26
			got_class[id] = true
			class_26(id)
		}
		case 27: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 27
			got_class[id] = true
			class_27(id)
		}
		case 28: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 28
			got_class[id] = true
			class_28(id)
		}
		case 29: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 29
			got_class[id] = true
			class_29(id)
		}
		case 30: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 30
			got_class[id] = true
			class_30(id)
		}
		case 31: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 31
			got_class[id] = true
			class_31(id)
		}
				
		case 32: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 32
			got_class[id] = true
			class_32(id)
		}
		case 33: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 33
			got_class[id] = true
			class_33(id)
		}
		case 34: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 34
			got_class[id] = true
			class_34(id)
		}
		case 35: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 35
			got_class[id] = true
			class_35(id)
		}
		case 36: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 36
			got_class[id] = true
			class_36(id)
		}
		case 37: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 37
			got_class[id] = true
			class_37(id)
		}
		case 38: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 38
			got_class[id] = true
			class_38(id)
		}
		case 39: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 39
			got_class[id] = true
			class_39(id)
		}
		case 40: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 40
			got_class[id] = true
			class_40(id)
		}
		case 41: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 41
			got_class[id] = true
			class_41(id)
		}
		case 42: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 42
			got_class[id] = true
			class_42(id)
		}
		case 43: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 43
			got_class[id] = true
			class_43(id)
		}
		case 44: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 43
			got_class[id] = true
			class_44(id)
		}
		case 45: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 43
			got_class[id] = true
			class_45(id)
		}
		case 46: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 43
			got_class[id] = true
			class_46(id)
		}
		case 47: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 43
			got_class[id] = true
			class_47(id)
		}
		case 48: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 43
			got_class[id] = true
			class_48(id)
		}
		case 51: 
		{
			if(zp_get_user_zombie(id) || zp_get_user_survivor(id) || zp_get_user_nemesis(id)) return PLUGIN_HANDLED;
			//g_player_class[id] = 51
			got_class[id] = true
			new rand = random_num(1,48)
			switch(rand) 
			{
				case 1: class_1(id)
				case 2: class_2(id)
				case 3: class_3(id)
				case 4: class_4(id)
				case 5: class_5(id)
				case 6: class_6(id)
				case 7: class_7(id)
				case 8: class_8(id)
				case 9: class_9(id)
				case 10: class_10(id)
				case 11: class_11(id)
				case 12: class_12(id)
				case 13: class_13(id)
				case 14: class_14(id)
				case 15: class_15(id)
				case 16: class_16(id)
				case 17: class_17(id)
				case 18: class_18(id)
				case 19: class_19(id)
				case 20: class_20(id)
				case 21: class_21(id)
				case 22: class_22(id)
				case 23: class_23(id)
				case 24: class_24(id)
				case 25: class_25(id)
				case 26: class_26(id)
				case 27: class_27(id)
				case 28: class_28(id)
				case 29: class_29(id)
				case 30: class_30(id)
				case 31: class_31(id)
				case 32: class_32(id)
				case 33: class_33(id)
				case 34: class_34(id)
				case 35: class_35(id)
				case 36: class_36(id)
				case 37: class_37(id)
				case 38: class_38(id)
				case 39: class_39(id)
				case 40: class_40(id)
				case 41: class_41(id)
				case 42: class_42(id)
				case 43: class_43(id)
				case 44: class_44(id)
				case 45: class_45(id)
				case 46: class_46(id)
				case 47: class_47(id)
				case 48: class_48(id)
			}
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public fw_Weapon_PrimaryAttack_Post(entity)
{
	new id = pev(entity, pev_owner)
	if (g_norecoil[id] == true)
	{
		new Float: push[3]
		pev(id, pev_punchangle, push)
		xs_vec_sub(push, cl_pushangle[id], push)
		xs_vec_mul_scalar(push, 0.0, push)
		xs_vec_add(push, cl_pushangle[id], push)
		set_pev(id, pev_punchangle, push)
		return HAM_IGNORED;
	}
	return HAM_IGNORED;
}

public fw_Weapon_PrimaryAttack_Pre(entity)
{
	new id = pev(entity, pev_owner)
	if (g_norecoil[id] == true)
	{
		pev(id, pev_punchangle, cl_pushangle[id])
		return HAM_IGNORED;
	}
	return HAM_IGNORED;
}

public FW_playerprethink(id)
{
	if(g_speed[id] == true)  
	{
		set_user_maxspeed(id, get_cvar_float("zp_human_speed") + 50)  
	}
	
	if(g_laser[id] == true)
	{
		new e[3]
		get_user_origin(id, e, 3)
		message_begin( MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte (TE_BEAMENTPOINT)
		write_short(id | 0x1000)
		write_coord (e[0])			
		write_coord (e[1])			
		write_coord (e[2])			

		write_short(sprite)			
		
		write_byte (1)      						
		write_byte (10)     								
		write_byte (1)				
		write_byte (5)   						
		write_byte (0)    			
		write_byte (255) 			
		write_byte (0)				
		write_byte (0)				
		write_byte (150)     							
		write_byte (25)      				
		message_end()
	}

	if(can_leap(id))
	{
		if(g_leap[id] == true)
		{
			static Float:velocity[3]
			velocity_by_aim(id, 570, velocity)
			velocity[2] = 275.00
			set_pev(id, pev_velocity, velocity)
			g_lastLeaptime[id] = get_gametime()
		}
	}
	if(g_aurel[id] == true)
	{
		for( new i = 1; i <= g_iMaxPlayers; i++ )
		{
			if(is_user_alive(i) && zp_get_user_zombie(i))
			{
				new Distance; Distance = get_entity_distance(i, id)
				if(Distance <= 300) 
				{
					set_user_maxspeed(i, 150.0)
				}
			}
		}
	}
	
	if(g_sthg[id] == true)
	{
		for( new i = 1; i <= g_iMaxPlayers; i++ )
		{
			if(is_user_alive(i) && !zp_get_user_zombie(i))
			{
				new Distance; Distance = get_entity_distance(i, id)
				if(Distance <= 300) 
				{
					stealthize(i)
					set_user_maxspeed(id, get_cvar_float("zp_human_speed") - 60) 
				}
			}
		}
	}
	
	if(g_neut[id] == true)
	{
		new infnade = find_ent_by_class(-1, "grenade")
		{
			new Distance = fm_get_entity_distance(infnade, id)
			new owner = pev(infnade, pev_owner)
			if(Distance <= 200 && zp_get_user_zombie(owner)) 
			{
				remove_entity(infnade)
			}
		}
	}
}

public Ham_PlayerTakeDamage(iVictim, iInflictor, iAttacker, Float:flDamage, iDmgBits)
{        
	if (iDmgBits & DMG_FALL) 
	{
	if (g_nofalldamage[iVictim] == true)
		{
			return HAM_SUPERCEDE
		}
	}
	if(g_dmgx[iAttacker])
		{
		SetHamParamFloat(4,(flDamage*1.1)) 
		return HAM_HANDLED  
		}
	if(g_samurai[iAttacker] && g_iCurrentWeapon[iAttacker] == CSW_KNIFE)
		{
		SetHamParamFloat(4,(flDamage*2.0)) 
		return HAM_HANDLED  
		}
	if(g_snip[iAttacker] && g_iCurrentWeapon[iAttacker] == CSW_AWP || g_iCurrentWeapon[iAttacker] == CSW_SCOUT)
		{
		SetHamParamFloat(4,(flDamage*2.0)) 
		return HAM_HANDLED  
		}
	return HAM_IGNORED
}

public blind(id)
{
	message_begin(MSG_ONE_UNRELIABLE, gmsgFade,{0,0,0},id)
	write_short(1<<2) 
	write_short(1<<11)  
	write_short(1<<12)  
	write_byte(255) 
	write_byte(255) 
	write_byte(255) 
	write_byte(250) 
	message_end()
}

public shake(id)
{
	message_begin (MSG_ONE_UNRELIABLE, gmsgShake, {0,0,0}, id)
	write_short (1<<6) 
	write_short (1<<13) 
	write_short (1<<12)
	message_end ()
}

stock fm_get_speed(entity)
{
	static Float:velocity[3]
	pev(entity, pev_velocity, velocity)
	return floatround(vector_length(velocity))
}

can_leap(id)
{
	static buttons
	buttons = pev(id, pev_button)
	if (!(pev(id, pev_flags) & FL_ONGROUND) || fm_get_speed(id) < 20 || !(buttons & IN_JUMP) || !(buttons & IN_DUCK))
		return false
	if (get_gametime() - g_lastLeaptime[id] < 4.0)
		return false
	return true
}

public radar_scan()
{	
	new zombie_count = 0;
	new zombie_list[32];
	new ZombieCoords[3];
	new id, i;
	
	for (new id=1; id<=32; id++)
		if (zp_get_user_zombie(id))
		{
			zombie_count++;
			zombie_list[zombie_count]=id;
		}
	
	for (id=1; id<=32; id++)
	{
		if ((!is_user_alive(id))||(!g_radar[id])) continue;
		
		for (i=1;i<=zombie_count;i++)
		{
			
			get_user_origin(zombie_list[i], ZombieCoords)
		
			message_begin(MSG_ONE_UNRELIABLE, g_msgHostageAdd, {0,0,0}, id)
			write_byte(id)
			write_byte(i)		
			write_coord(ZombieCoords[0])
			write_coord(ZombieCoords[1])
			write_coord(ZombieCoords[2])
			message_end()
		
			message_begin(MSG_ONE_UNRELIABLE, g_msgHostageDel, {0,0,0}, id)
			write_byte(i)
			message_end()
		}
	}
}

public remove_mad(id)
{
	set_user_godmode(id, 0)
	remove_task(id + TASK_AURA)
}

public zp_extra_item_selected(id, itemid)
{
	if (itemid == g_class)
	{
		got_class[id] = false
		ClCmdSelectclass(id)
	}
}

public NewRound(i)
{
	for (i = 1; i <= 32; i++)
	{
	if (g_speed[i])
		{
		g_speed[i] = false
		}
	if (g_norecoil[i])
		{
		g_norecoil[i] = false
		}	
	if (g_laser[i])
		{
		g_laser[i] = false
		}
	if (g_leap[i])
		{
		g_leap[i] = false
		}
	if (g_nofalldamage[i])
		{
		g_nofalldamage[i] = false
		}
	if (g_radar[i])
		{
		g_radar[i] = false
		}
	if (g_doc[i])
		{
		g_doc[i] = false
		}
	if (g_blinder[i])
		{
		g_blinder[i] = false
		}
	if (g_mad[i])
		{
		g_mad[i] = false
		}
	if (g_shg[i])
		{
		drop_primary_weapons(i)
		g_shg[i] = false
		}
	if (g_smg[i])
		{
		drop_primary_weapons(i)
		g_smg[i] = false
		}
	if (g_dmgx[i])
		{
		g_dmgx[i] = false
		}
	if (g_blaster[i])
		{
		g_blaster[i] = false
		}
	if (g_medic[i])
		{
		g_medic[i] = false
		}
	if (g_gunner[i])
		{
		drop_secondary_weapons(i)
		g_gunner[i] = false
		}
	if (g_az[i])
		{
		g_az[i] = false
		cs_set_user_armor(i,  0,  CsArmorType:1)
		}
	if (g_samurai[i])
		{
		g_samurai[i] = false
		}
	if (g_tremor[i])
		{
		g_tremor[i] = false
		}
	if (g_flasher[i])
		{
		g_flasher[i] = false
		}
	if (g_mutant[i])
		{
		g_mutant[i] = false
		}
	if (g_spy[i])
		{
		g_spy[i] = false
		}
	if (g_heavy[i])
		{
		g_heavy[i] = false
		}
	if (g_srv[i])
		{
		g_srv[i] = false
		}
	if (g_nvg[i])
		{
		g_nvg[i] = false
		}
	if (g_dis[i])
		{
		g_dis[i] = false
		}
	if (g_ghost[i])
		{
		g_ghost[i] = false
		}
	if (g_cam[i] == true)
		{
		set_view(i, CAMERA_NONE)
		g_cam[i] = false
		}
	if (g_pogo[i])
		{
		g_pogo[i] = false
		}
	if (g_knock[i])
		{
		g_knock[i] = false
		}
	if (g_leech[i])
		{
		g_leech[i] = false
		}
	if (g_cd[i])
		{
		g_cd[i] = false
		}
	if (g_snip[i])
		{
		g_snip[i] = false
		}
	if (g_aurel[i])
		{
		g_aurel[i] = false
		}
	if (g_sthg[i])
		{
		g_sthg[i] = false
		}
	if (g_neut[i])
		{
		g_neut[i] = false
		}
	if (g_smoker[i])
		{
		g_smoker[i] = false
		}
	if (g_collector[i])
		{
		drop_primary_weapons(i)
		drop_secondary_weapons(i)
		g_collector[i] = false
		}
	if (g_head[i])
		{
		set_user_hitzones(0, i, 1)
		g_head[i] = false
		}
	if (got_class[i])
		{
		got_class[i] = false
		}
	}
}

public fwHamPlayerSpawnPost(id)
{
	chat_color(id, "!g[ZP] !yPress !gJ !ykey or type !g/hc !yin chat to choose your !gHuman Class")
}

public zp_user_infected_post(id, infector)
{
	g_leap[id] = false
	g_speed[id] = false
	g_norecoil[id] = false
	g_laser[id] = false
	g_nofalldamage[id] = false
	g_radar[id] = false
	g_smg[id] = false
	g_shg[id] = false
	g_dmgx[id] = false
	g_gunner[id] = false
	g_blaster[id] = false
	g_flasher[id] = false
	g_samurai[id] = false
	g_tremor[id] = false
	g_spy[id] = false
	g_heavy[id] = false
	g_nvg[id] = false
	g_srv[id] = false
	g_dis[id] = false
	g_knock[id] = false
	g_cd[id] = false
	g_leech[id] = false
	g_snip[id] = false
	g_aurel[id] = false
	g_collector[id] = false
	g_sthg[id] = false
	g_neut[id] = false
	if(g_doc[id] == true)
	{
		set_user_health(id, (get_user_health(id)) + 500)
	}
	if(g_blinder[id] == true)
	{
		give_item(id, "weapon_flashbang")
	}
	if(g_aps[id] == true)
	{
		new amount
		amount = random_num(2,8)
		zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + amount)
		zp_set_user_ammo_packs(infector, (zp_get_user_ammo_packs(infector) - amount) - (get_cvar_num("zp_zombie_infect_reward")))
	}
	if(g_mad[id] == true)
	{
		set_user_godmode(id, 1)
		set_task(0.1, "aura", id + TASK_AURA, _, _, "b")
		set_task(5.0, "remove_mad", id)
	}
	if(g_az[id] == true)
	{
		cs_set_user_armor(id,  100,  CsArmorType:2)
	}
	if(got_class[id] == true)
	{
		got_class[id] = false
	}
	if(g_medic[id] == true)
	{
		set_task(10.0, "disinfect", id)
	}
	if(g_mutant[id] == true)
	{
		nemesize(id)
	}
	if(g_ghost[id] == true)
	{
		noclip(id)
	}
	if(g_cam[id] == true)
	{
		set_view(id, CAMERA_NONE)
	}
	if(g_head[id] == true)
	{
		g_head[id] = false
		set_user_hitzones(0, id, 1)
	}
	if(g_smoker[id] == true)
	{
		give_item(id, "weapon_smokegrenade")
	}
}

public DeathMsg()
{
	new id = read_data(2)
	got_class[id] = false
	
	g_leap[id] = false
	g_speed[id] = false
	g_norecoil[id] = false
	g_laser[id] = false
	g_nofalldamage[id] = false
	g_radar[id] = false
	g_doc[id] = false
	g_blinder[id] = false
	g_mad[id] = false
	g_aps[id] = false
	g_smg[id] = false
	g_shg[id] = false
	g_az[id] = false
	g_dmgx[id] = false
	g_blaster[id] = false
	g_medic[id] = false
	g_samurai[id] = false
	g_tremor[id] = false
	g_flasher[id] = false
	g_mutant[id] = false
	g_spy[id] = false
	g_heavy[id] = false
	g_nvg[id] = false
	g_srv[id] = false
	g_dis[id] = false
	g_cam[id] = false
	g_pogo[id] = false
	g_knock[id] = false
	g_snip[id] = false
	g_cd[id] = false
	g_leech[id] = false
	g_collector[id] = false
	g_aurel[id] = false
	g_sthg[id] = false
	g_neut[id] = false
	g_smoker[id] = false
	if(g_head[id] == true)
	{
		g_head[id] = false
		set_user_hitzones(0, id, 1)
	}
}

public zp_user_humanized_post(id)
{
	got_class[id] = false
	
	g_leap[id] = false
	g_speed[id] = false
	g_norecoil[id] = false
	g_laser[id] = false
	g_nofalldamage[id] = false
	g_radar[id] = false
	g_smg[id] = false
	g_shg[id] = false
	g_aps[id] = false
	g_doc[id] = false
	g_blinder[id] = false
	g_mad[id] = false
	g_az[id] = false
	g_dmgx[id] = false
	g_blaster[id] = false
	g_medic[id] = false
	g_samurai[id] = false
	g_tremor[id] = false
	g_flasher[id] = false
	g_mutant[id] = false
	g_spy[id] = false
	g_heavy[id] = false
	g_nvg[id] = false
	g_srv[id] = false
	g_dis[id] = false
	g_cam[id] = false
	g_pogo[id] = false
	g_knock[id] = false
	g_cd[id] = false
	g_snip[id] = false
	g_leech[id] = false
	g_collector[id] = false
	g_aurel[id] = false
	g_sthg[id] = false
	g_neut[id] = false
	g_smoker[id] = false
	if(g_head[id] == true)
	{
		g_head[id] = false
		set_user_hitzones(0, id, 1)
	}
}

public aura(id)
{
	id -= TASK_AURA
	new Origin[3]
	get_user_origin(id, Origin)
	
	message_begin(MSG_ALL, SVC_TEMPENTITY)
	write_byte(TE_DLIGHT)
	write_coord(Origin[0])
	write_coord(Origin[1])
	write_coord(Origin[2])
	write_byte(20)
	write_byte(255) 
	write_byte(0) 
	write_byte(0) 
	write_byte(2)
	write_byte(0)
	message_end()
}

stock drop_primary_weapons(id)	
{
	static weapons [ 32 ], num, i, weaponid
	num = 0 
	get_user_weapons (id, weapons, num )
	for ( i = 0; i < num; i++ )
	{
		weaponid = weapons [ i ]
		if  ( ( (1<<weaponid) & PRIMARY_WEAPONS_BITSUM ) )		
		{
		static wname[32]
		get_weaponname(weaponid, wname, charsmax(wname))
		engclient_cmd(id, "drop", wname)
		}
	}
}

stock drop_secondary_weapons(id)	
{
	static weapons [ 32 ], num, i, weaponid
	num = 0 
	get_user_weapons (id, weapons, num )
	for ( i = 0; i < num; i++ )
	{
		weaponid = weapons [ i ]
		if  ( ( (1<<weaponid) & SECONDARY_WEAPONS_BITSUM ) )		
		{
		static wname[32]
		get_weaponname(weaponid, wname, charsmax(wname))
		engclient_cmd(id, "drop", wname)
		}
	}
}

public class_1(id)
{
	g_armor[id] = true
	cs_set_user_armor(id,  20,  CsArmorType:1)
	chat_color(id,"!g[ZP] !yYour Human class for this round is:!g Armorer !t(20 AP)")
}

public class_2(id)
{
	g_pound[id] = true
	set_user_health(id, 300)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Pounder !t(300 HP)")
}

public class_3(id)
{
	g_jumper[id] = true
	set_user_gravity(id, 0.50)
	chat_color(id, "!g[ZP] Your Human class for this round is:!g Jumper !t(High Jump)");
}

public class_4(id)
{
	g_leap[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Leaper !t(Leap Ability)");
}

public class_5(id)
{
	got_class[id] = true
	g_speed[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Runner !t(+Speed)");
}

public class_6(id)
{
	g_stealth[id] = true
	set_user_rendering(id,kRenderFxNone,0,0,0,kRenderTransAlpha,127)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Stealth Warrior !t(Stealth)");
}
public class_7(id)
{
	g_frost[id] = true
	give_item(id, "weapon_flashbang")
	cs_set_user_bpammo(id, CSW_FLASHBANG, 5)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Frost Soldier !t(5 FrostNade)");
}

public class_8(id)
{
	g_aps[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Thief !t(Steals Random Number Of Ammo Packs From Infector)");
}

public class_9(id)
{
	g_blinder[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Blinder !t(Flashbang On Infection)");
}

public class_10(id)
{
	g_doc[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Doc !t(+500 HP Upon Infection)");
}

public class_11(id)
{
	g_mad[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Wicked One !t(Madness On Infection For 5 Seconds)");
}

public class_12(id)
{
	g_nofalldamage [id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g FeatherFoot !t(No Fall Damage)");
}

public class_13(id)
{
	g_az[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Armored Later !t(+100 Armor Upon Infection)");
}

public class_14(id)
{
	g_flare[id] = true
	give_item(id, "weapon_smokegrenade")
	cs_set_user_bpammo(id, CSW_SMOKEGRENADE, 5)
	set_pev(id, pev_effects, pev(id, pev_effects) | EF_BRIGHTLIGHT)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Light Handler !t(5 FlareNade & Light Aura)");
}

public class_15(id)
{
	g_shg[id] = true
	give_item(id,"weapon_xm1014")
	cs_set_user_bpammo(id, CSW_XM1014, 32)
	give_item(id,"weapon_m3")
	cs_set_user_bpammo(id, CSW_M3, 32)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Shotgunner !t(+Shotguns)");
}

public class_16(id)
{
	g_smg[id] = true
	give_item(id,"weapon_mp5navy")
	cs_set_user_bpammo(id, CSW_MP5NAVY, 120)
	give_item(id,"weapon_p90")
	cs_set_user_bpammo(id, CSW_P90, 100)
	give_item(id,"weapon_ump45")
	cs_set_user_bpammo(id, CSW_UMP45, 120)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g SubMachine Kid !t(+SubMachine Guns)");
}

public class_17(id)
{
	g_phalanx[id] = true
	drop_primary_weapons(id)
	give_item(id,"weapon_shield")
	give_item(id,"weapon_deagle")
	cs_set_user_bpammo(id, CSW_DEAGLE, 35)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Phalanxer !t(Shield & Deagle)");
}

public class_18(id)
{
	g_norecoil[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Sharpshooter !t(No Recoil For Weapons)");
}

public class_19(id)
{
	g_laser[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Laser Aimer !t(Laser Sight For Weapons)");
}

public class_20(id)
{
	g_radar[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Zombie Seeker !t(Zombie Radar)");
}

public class_21(id)
{
	g_fire[id] = true
	give_item(id, "weapon_hegrenade")
	cs_set_user_bpammo(id, CSW_HEGRENADE, 5)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Firebat !t(5 NapalmNade)");
}

public class_22(id)
{
	g_dmgx[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Man Of Despair !t(+10%% Damage)");
}

public class_23(id)
{
	g_blaster[id] = true
	give_item(id, "weapon_c4")
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Blaster !t(Can Drop C4 Mine, Deals 500 Dmg)");
}

public class_24(id)
{
	g_medic[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Medic !t(1 Extra Antidote, 10 Seconds After Inf)");
}

public class_25(id)
{
	g_gunner[id] = true
	give_item(id, "weapon_glock18")
	cs_set_user_bpammo(id, CSW_GLOCK18, 100)
	give_item(id, "weapon_deagle")
	cs_set_user_bpammo(id, CSW_DEAGLE, 100)
	give_item(id, "weapon_usp")
	cs_set_user_bpammo(id, CSW_USP, 100)
	give_item(id, "weapon_fiveseven")
	cs_set_user_bpammo(id, CSW_FIVESEVEN, 100)
	give_item(id, "weapon_p228")
	cs_set_user_bpammo(id, CSW_P228, 100)
	give_item(id, "weapon_elite")
	cs_set_user_bpammo(id, CSW_ELITE, 100)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Pistolero !t(+All Guns)");
}

public class_26(id)
{
	g_samurai[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Samurai !t(Fast Knife Slash + 2X Knife Damage)");
}

public class_27(id)
{
	g_tremor[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Tremor Maker !t(Shaking Zombie's Screen)");
}

public class_28(id)
{
	g_flasher[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Deceiver !t(Blinding Zombies)");
}

public class_29(id)
{
	g_mutant[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Mutant !t(Becomes Nemesis For 8 Seconds Upon Inf)");
}

public class_30(id)
{
	g_spy[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Spy !t(Can See Zombie's Health & AP & # Of Zombies Left)");
}

public class_31(id)
{
	g_heavy[id] = true
	give_item(id, "weapon_m249")
	cs_set_user_bpammo(id, CSW_M249, 250)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Tought Guy !t(+M294 Para)");
}

public class_32(id)
{
	g_nvg[id] = true
	zp_set_user_nightvision(id, 1)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Seer !t(+NightVision Goggles)");
}

public class_33(id)
{
	g_srv[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Last Man !t(Will Become Survivor If He Is Last Man Standing)");
}

public class_34(id)
{
	g_dis[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Slapper !t(Slaps Zombies Who Looks At Him)");
}

public class_35(id)
{
	g_pogo[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Pogo Jumper !t(Can Use Weapons As Pogo)");
}

public class_36(id)
{
	g_cam[id] = true
	set_view(id, CAMERA_3RDPERSON)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Cameraman !t(3rd Person View)");
}

public class_37(id)
{
	g_ghost[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Ghost Stalker !t(No Clip For 15 Seconds Upon Infection)");
}

public class_38(id)
{
	g_snip[id] = true
	drop_primary_weapons(id)
	give_item(id, "weapon_awp")
	cs_set_user_bpammo(id, CSW_AWP, 30)
	give_item(id, "weapon_scout")
	cs_set_user_bpammo(id, CSW_SCOUT, 30)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Sniper !t(Snipers + 2X Damage)");
}

public class_39(id)
{
	g_gore[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Disemboweler !t(Disembowels Zombies)");
}

public class_40(id)
{
	g_leech[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Leecher !t(Self-Healing While Making Damage)");
}

public class_41(id)
{
	g_cd[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Hacker !t(Ejects CD Tray Of Zombies That Looks At Him)");
}

public class_42(id)
{
	g_head[id] = true
	set_user_hitzones(0, id, 2)
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Wiseman !t(Can Be Infected With Headshot Only)");
}

public class_43(id)
{
	g_knock[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g KnockBacker !t(Bigger Knockback For Weapons)");
}

public class_44(id)
{
	g_collector[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Collector !t(Can Pickup Multiple Weapons)");
}

public class_45(id)
{
	g_aurel[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Aurelius !t(Slowing Nearby Zombies)");
}

public class_46(id)
{
	g_sthg[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Stealth Giver !t(Stealth Aura)");
}

public class_47(id)
{
	g_neut[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Neutralizer !t(Neutralizing Infection Grenades)");
}

public class_48(id)
{
	g_smoker[id] = true
	chat_color(id, "!g[ZP] !yYour Human class for this round is:!g Smoker !t(+Smoke Grenade When Infected)");
}


stock chat_color(const id, const input[], any:...)
{
	static msg[191]
	vformat(msg, 190, input, 3)
	
	replace_all(msg, 190, "!g", "^4")
	replace_all(msg, 190, "!y", "^1")
	replace_all(msg, 190, "!t", "^3")
	replace_all(msg, 190, "!c", "^0")
	
	message_begin(MSG_ONE_UNRELIABLE, g_SayText, _, id)
	write_byte(id)
	write_string(msg)
	message_end()
}

public pfn_touch(ptr, ptd)
{ 
	new bomb = find_ent_by_model(-1,"weaponbox","models/w_backpack.mdl")
	entity_set_string(bomb,EV_SZ_classname,"bomb")

	if(ptr > 0 && ptd > 0 && is_valid_ent(ptr) && is_user_alive(ptd) && zp_get_user_zombie(ptd) && !zp_get_user_nemesis(ptd))
	{
		new bomb[32]
		entity_get_string(ptr, EV_SZ_classname, bomb, 31)
		if (equal(bomb,"bomb")) 
		{
			set_user_health(ptd, (get_user_health(ptd)) - 500)
			new bOrigin[3]
			get_user_origin(ptd, bOrigin, 0)
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION)
			write_coord(bOrigin[0]) 
			write_coord(bOrigin[1]) 
			write_coord(bOrigin[2]) 
			write_short(boomsprite) 
			write_byte(30)
			write_byte(15) 
			write_byte(0) 
			message_end()
			remove_entity(ptr)
		}
	}		
}

public disinfect(id)
{
	zp_disinfect_user(id)
	got_class[id] = true
}

public nemesize(id)
{
	zp_make_user_nemesis(id)
	set_task(8.0, "zombify", id)
}

public zombify(id)
{
	set_task(0.1, "disinfect", id) 
	set_task(0.2, "make_zomb", id)
	g_mutant[id] = false
}

public survivorize(id)
{	
	zp_make_user_survivor(id)
	set_user_health(id, 1000)
}

public make_zomb(id)
{
	zp_infect_user(id)
}

public stealthize(id)
{
	set_user_rendering(id,kRenderFxNone,0,0,0,kRenderTransAlpha,127)
	set_task(1.0, "unstealthize", id)
}

public unstealthize(id)
{
	set_user_rendering(id,kRenderFxNone,0,0,0,kRenderTransAlpha,255)
}

public fw_Knife_PrimaryAttack_Post(knife)
{
	static id
	id = get_pdata_cbase(knife, m_pPlayer, 4)
	if(g_samurai[id])
	{
		static Float:flRate
		flRate = 0.1
		
		set_pdata_float(knife, m_flNextPrimaryAttack, flRate, 4)
		set_pdata_float(knife, m_flNextSecondaryAttack, flRate, 4)
		set_pdata_float(knife, m_flTimeWeaponIdle, flRate, 4)		
	}
	return HAM_IGNORED
}

public fw_Knife_SecondaryAttack_Post(knife)
{
	static id
	id = get_pdata_cbase(knife, m_pPlayer, 4)

	if(g_samurai[id])
	{
		static Float:flRate
		flRate = 0.3
		
		set_pdata_float(knife, m_flNextPrimaryAttack, flRate, 4)
		set_pdata_float(knife, m_flNextSecondaryAttack, flRate, 4)
		set_pdata_float(knife, m_flTimeWeaponIdle, flRate, 4)
	}
	return HAM_IGNORED
}

public showStatus(id)
{
	if(is_user_connected(id) && zp_get_user_zombie(id)) 
	{
		new pid = read_data(2)
		if(g_tremor[pid] == true)
		{
			shake(id)
		} 
		if(g_flasher[pid] == true)
		{
			blind(id)
		}
		if(g_dis[pid] == true)
		{
			user_slap(id, 0, 1)
		}
		if(g_cd[pid] == true)
		{
			client_cmd(id, "cd eject")
		} 
	}

	if(!is_user_bot(id) && is_user_connected(id) && g_spy[id] == true) 
	{
		new zmb = read_data(2)
		if(g_spy[id] == true && zp_get_user_zombie(zmb))
		{
			new hp = get_user_health(zmb)
			new ap = zp_get_user_ammo_packs(zmb)
			new zm = zp_get_zombie_count()
			new name[32]
			get_user_name(zmb,name,31)
			set_hudmessage(0, 255, 0, -1.0, 0.1, 0, 2.0, 1.5, 0.1, 0.2, 13)
			ShowSyncHudMsg(id, g_status_sync, "Name: %s^nHealth: %i^nAmmo Packs: %i^nZombies Left: %i", name, hp, ap, zm)
		}
	}
}

public zp_user_last_human(id)
{
	if(g_srv[id] == true)
	set_task(1.0, "survivorize", id) 
}

public noclip(id)
{
	set_user_rendering(id,kRenderFxNone,0,0,0,kRenderTransAlpha,127)
	set_user_noclip(id,1)
	set_task(15.0, "clipno", id)
}

public clipno(id)
{
	set_user_rendering(id,kRenderFxNone,0,0,0,kRenderTransAlpha,255)
	set_user_noclip(id,0)
}

public fw_FMPrecacheEvent( Type , const szName[] ) 
{ 
	for ( new i = 0 ; i < sizeof( g_GunEvents ) ; ++i ) 
	{
		if (equal(g_GunEvents[i] , szName)) 
		{
			g_GunEventBits |= (1 << get_orig_retval());
			return FMRES_HANDLED;
		}
	}

        return FMRES_IGNORED;
}

public fw_FMPlaybackEvent(Flags , Invoker , EventID ) 
{
        if (!( g_GunEventBits & ( 1 << EventID ) ) || !IsPlayer(Invoker))
                return FMRES_IGNORED;

	static Float:fVelocity[ 3 ];
	static iOrigin[ 3 ] , Float:fOrigin[ 3 ];
	static iAimOrigin[ 3 ] , Float:fAimOrigin[ 3 ];
	
	get_user_origin( Invoker , iOrigin );
	get_user_origin( Invoker , iAimOrigin , 3 );

	IVecFVec( iOrigin , fOrigin );
	IVecFVec( iAimOrigin , fAimOrigin );
	
	if (( -80.0 >= GetAngleOrigins( fOrigin , fAimOrigin ) >= -90.0 ) && g_pogo[Invoker] == true)
	{
		pev( Invoker , pev_velocity , fVelocity );
		fVelocity[ 2 ] = 220.0
		set_pev( Invoker , pev_velocity , fVelocity );
		
		SetPogo(Invoker);
		
		entity_set_float( g_TouchGroundEnt , EV_FL_nextthink , get_gametime() + 0.25 );

		return FMRES_IGNORED;
	}
	
	return FMRES_HANDLED;
}

public fw_Think(Entity)
{
	if( Entity != g_TouchGroundEnt ) 
		return FMRES_IGNORED;
	
	static id;
	
	for (id = 1 ; id <= g_iMaxPlayers ; id++)
		if (IsPogo(id) && ((pev(id , pev_flags) & FL_ONGROUND) || !is_user_alive(id))) 
			RemovePogo(id);
			
	if (g_bIsPogo)
		entity_set_float(g_TouchGroundEnt , EV_FL_nextthink , get_gametime() + 0.25 );
		
	return FMRES_IGNORED;
}

Float: GetAngleOrigins(const Float:fOrigin1[3] , const Float:fOrigin2[3])
{
	new Float:fVector[3] , Float:fAngle[3];
	
	xs_vec_sub(fOrigin2 , fOrigin1 , fVector);
	vector_to_angle(fVector , fAngle);
	
	return ( ( fAngle[ 0 ] > 90.0 ) ? -( 360.0 - fAngle[ 0 ] ) : fAngle[ 0 ] );
}

public fw_PlayerKilled_Pre(iVictim, iAttacker, iShouldGib)
{
	if(zp_get_user_zombie(iVictim) && g_gore[iAttacker])
	{
		SetHamParamInteger(3, 2)
	}
}

public fw_PlayerKilled_Post(iVictim, iAttacker, iShouldGib)
{
	if(zp_get_user_zombie(iVictim) && g_gore[iAttacker])
	{
		SetHamParamInteger(3, 2)
	}
}

public Event_Damage()
{
	new victim = read_data(0)
	new attacker = get_user_attacker(victim)

	if (zp_get_user_zombie(victim) && victim != attacker && g_leech[attacker] && is_user_alive(attacker) && is_user_alive(victim))
	{
		new damage = read_data(2)
		set_user_health(attacker, (get_user_health(attacker) + damage/20))
	}
	
	if(zp_get_user_zombie(victim) && victim != attacker && g_knock[attacker])
	{
		new Float:vec[3];
		new Float:oldvelo[3];
		get_user_velocity(victim, oldvelo);
		create_velocity_vector(victim , attacker , vec);
		vec[0] += oldvelo[0];
		vec[1] += oldvelo[1];
		set_user_velocity(victim , vec);
	}
}

stock fm_get_entity_distance(ent1, ent2)
{
	return floatround(fm_entity_range(ent1, ent2))
}

stock Float:fm_entity_range(ent1, ent2) {
	new Float:origin1[3], Float:origin2[3];
	pev(ent1, pev_origin, origin1);
	pev(ent2, pev_origin, origin2);

	return get_distance_f(origin1, origin2);
}

stock create_velocity_vector(victim,attacker,Float:velocity[3])
{
	if(!zp_get_user_zombie(victim) || !is_user_alive(attacker))
		return 0;

	new Float:vicorigin[3];
	new Float:attorigin[3];
	entity_get_vector(victim   , EV_VEC_origin , vicorigin);
	entity_get_vector(attacker , EV_VEC_origin , attorigin);

	new Float:origin2[3]
	origin2[0] = vicorigin[0] - attorigin[0];
	origin2[1] = vicorigin[1] - attorigin[1];

	new Float:largestnum = 0.0;

	if(floatabs(origin2[0])>largestnum) largestnum = floatabs(origin2[0]);
	if(floatabs(origin2[1])>largestnum) largestnum = floatabs(origin2[1]);

	origin2[0] /= largestnum;
	origin2[1] /= largestnum;

	velocity[0] = ( origin2[0] * 30000 ) / get_entity_distance(victim , attacker);
	velocity[1] = ( origin2[1] * 30000 ) / get_entity_distance(victim , attacker);
	if(velocity[0] <= 20.0 || velocity[1] <= 20.0)
		velocity[2] = random_float(200.0 , 275.0);

	return 1;
}

public FM_Touch_hook(weaponbox,id)
{
	if(is_user_alive(id) && !is_user_bot(id) && g_collector[id] == true && pev_valid(weaponbox))
	{
		static classname[64], trash[4]
		pev(weaponbox,pev_classname,classname,63)
		if(equali(classname,"weaponbox"))
		{
			pev(weaponbox,pev_model,classname,63)
			replace(classname,63,"w_"," ")
			replace(classname,63,".mdl","")
			strbreak(classname,trash,3,classname,63)
			format(classname,63,"weapon_%s",classname)

			new ent = engfunc(EngFunc_FindEntityByString,g_iMaxPlayers,"classname",classname)
			while(ent && pev_valid(ent))
			{
				if(pev(ent,pev_owner)==weaponbox)
				{
					give_item(id,classname)
					static classname2[32]
					pev(ent,pev_classname,classname2,31)

					if(pev_valid(weaponbox)) engfunc(EngFunc_RemoveEntity,weaponbox)
					if(pev_valid(ent)) engfunc(EngFunc_RemoveEntity,ent)
				}
				ent = engfunc(EngFunc_FindEntityByString,ent,"classname",classname)
			}
		}
	}
}
