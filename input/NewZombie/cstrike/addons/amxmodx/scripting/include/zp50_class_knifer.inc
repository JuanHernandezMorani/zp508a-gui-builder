#if defined _zp50_class_knifer_included
  #endinput
#endif
#define _zp50_class_knifer_included

#include <zp50_class_human>

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib zp50_class_knifer
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib zp50_class_knifer
	#endif
#else
	#pragma library zp50_class_knifer
#endif


/**
 * Returns whether a player is a knifer.
 *
 * @param id		Player index.
 * @return			True if it is, false otherwise.
 */
native zp_class_knifer_get(id)

/**
 * Forces a player to become a knifer.
 *
 * @param id		Player index.
 * @return			True on success, false otherwise.
 */
native zp_class_knifer_set(id)

/**
 * Returns number of alive knifer.
 *
 * @return		knifer count.
 */
native zp_class_knifer_get_count()
