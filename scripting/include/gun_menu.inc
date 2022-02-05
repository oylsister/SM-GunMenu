#if defined _gunmenu_included
  #endinput
#endif
#define _gunmenu_included


/**
 * Fucntion to find weapon index for gun_menu plugin via weapon entity name.
 *
 * @param weaponentity        weapon entity name (ex. weapon_ak47).
 *
 * @return   weapon index in config.
 */
native int GunMenu_GetWeaponIdByEntityName(const char[] weaponentity);

/**
 * Set the bypass purchase count for client, so they can purchase unlimited.
 *
 * @param client        the client index.
 * @param weaponindex   the weapon index that to be called from (GunMenu_GetWeaponIdByEntityName).
 * @param allowthem     set whetever to allow this bypass or not
 *
 * @error   invalid client or invalid weapon index
 */
native void GunMenu_SetClientByPassCount(int client, int weaponindex, bool allowthem);

/**
 * Set the bypass purchase price for client, so they can purchase it for free.
 *
 * @param client        the client index.
 * @param weaponindex   the weapon index that to be called from (GunMenu_GetWeaponIdByEntityName).
 * @param allowthem     set whetever to allow this bypass or not
 *
 * @error   invalid client or invalid weapon index
 */
native void GunMenu_SetClientByPassPrice(int client, int weaponindex, bool allowthem);

/**
 * Set the bypass purchase restrict weapon for client, so they can purchase it even weapon is still get restricted.
 *
 * @param client        the client index.
 * @param weaponindex   the weapon index that to be called from (GunMenu_GetWeaponIdByEntityName).
 * @param allowthem     set whetever to allow this bypass or not
 *
 * @error   invalid client or invalid weapon index
 */
native void GunMenu_SetClientByPassRestrict(int client, int weaponindex, bool allowthem);

/**
 * Called when a client is about to purchase through Gun-Menu plugin
 *
 * @param client        the client index.
 * @param weaponentity  The weapoon entity name.
 * @param loadout       Does client purchase via loadout or not
 * @param spawn         Does client purchase on spawn or not
 *
 * public void PurchaseWeapon(int client, const char[] entity, bool loadout, bool spawn)
 */

forward Action GunMenu_OnClientPurchase(int client, const char[] weaponentity, bool loadout, bool spawn);

/**
 * Called when a client purchased weapon through Gun-Menu plugin
 *
 * @param client        the client index.
 * @param weaponentity  The weapoon entity name.
 * @param loadout       Does client purchase via loadout or not
 * @param spawn         Does client purchase on spawn or not
 *
 * public void PurchaseWeapon(int client, const char[] entity,  bool loadout, bool spawn)
 */

forward void GunMenu_OnClientPurchased(int client, const char[] weaponentity, bool loadout, bool spawn);