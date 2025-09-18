#include <amxmodx>
#include <zombieplague>

#define PLUGIN "ZP BOT Random Zclass"
#define VERSION "1.0.0"
#define AUTHOR "yokomo"

#define MAX_ZCLASS 10 //Manually set your max number of zombie classes (see in zombie class menu)
#define TASK_SET_CLASS 16250
#define ID_SET_CLASS (taskid - TASK_SET_CLASS)

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
}

public client_putinserver(id)
{
	if (is_user_bot(id))
	{
		remove_task(id+TASK_SET_CLASS)
		set_task(5.0, "SetBotRandomClass", id+TASK_SET_CLASS)
	}
}

public client_disconnect(id)
{
	remove_task(id+TASK_SET_CLASS)
}

public SetBotRandomClass(taskid)
{
	new maxclass = MAX_ZCLASS - 1
	
	zp_set_user_zombie_class(ID_SET_CLASS, random_num(0, maxclass))
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0\\ deflang1033{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ f0\\ fs16 \n\\ par }
*/
