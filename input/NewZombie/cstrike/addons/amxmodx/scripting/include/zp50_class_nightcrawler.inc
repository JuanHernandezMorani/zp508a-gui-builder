#if defined _zp50_class_nightcrawler_included
  #endinput
#endif
#define _zp50_class_nightcrawler_included

#include <zp50_class_zombie>

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib zp50_class_nightcrawler
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib zp50_class_nightcrawler
	#endif
#else
	#pragma library zp50_class_nightcrawler
#endif


/**
 * Returns whether a player is a Nightcrawler.
 *
 * @param id		Player index.
 * @return			True if it is, false otherwise.
 */
native zp_class_nightcrawler_get(id)

/**
 * Forces a player to become a Nightcrawler.
 *
 * @param id		Player index.
 * @return			True on success, false otherwise.
 */
native zp_class_nightcrawler_set(id)

/**
 * Returns number of alive Nightcrawler.
 *
 * @return		Nightcrawler count.
 */
native zp_class_nightcrawler_get_count()
