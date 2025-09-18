#if defined _zp50_class_dragon_included
  #endinput
#endif
#define _zp50_class_dragon_included

#include <zp50_class_zombie>

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib zp50_class_dragon
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib zp50_class_dragon
	#endif
#else
	#pragma library zp50_class_dragon
#endif


/**
 * Returns whether a player is a Dragon.
 *
 * @param id		Player index.
 * @return			True if it is, false otherwise.
 */
native zp_class_dragon_get(id)

/**
 * Forces a player to become a Dragon.
 *
 * @param id		Player index.
 * @return			True on success, false otherwise.
 */
native zp_class_dragon_set(id)

/**
 * Returns number of alive dragon.
 *
 * @return		Dragon count.
 */
native zp_class_dragon_get_count()
