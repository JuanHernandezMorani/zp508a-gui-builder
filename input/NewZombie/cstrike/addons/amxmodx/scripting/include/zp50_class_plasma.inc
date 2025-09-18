#if defined _zp50_class_plasma_included
  #endinput
#endif
#define _zp50_class_plasma_included

#include <zp50_class_human>

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib zp50_class_plasma
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib zp50_class_plasma
	#endif
#else
	#pragma library zp50_class_plasma
#endif


/**
 * Returns whether a player is a Plasma.
 *
 * @param id		Player index.
 * @return			True if it is, false otherwise.
 */
native zp_class_plasma_get(id)

/**
 * Forces a player to become a plasma.
 *
 * @param id		Player index.
 * @return			True on success, false otherwise.
 */
native zp_class_plasma_set(id)

/**
 * Returns number of alive plasmas.
 *
 * @return		plasma count.
 */
native zp_class_plasma_get_count()
