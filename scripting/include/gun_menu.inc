#if defined _gunmenu_included
  #endinput
#endif
#define _gunmenu_included

enum ByPassType
{
    INVALID_BYPASS = -1,
    BYPASS_PRICE,
    BYPASS_COUNT,
    BYPASS_RESTRICT,
    BYPASS_COOLDOWN,
    BYPASS_GLOBALCOOLDOWN,
}

/**
 * Called when a client is about to purchase through Gun-Menu plugin
 *
 * @param client        the client index.
 * @param weaponentity  The weapoon entity name.
 * @param loadout       Count as purchase from loadout or not.
 * @param free          Set this as free purchase or not
 *
 * void PurchaseWeapon(int client, const char[] entity, bool loadout, bool free = false)
 */

forward Action GunMenu_OnClientPurchase(int client, const char[] weaponentity, bool loadout, bool free);

/**
 * Set by pass mode for the weapon
 *
 * @param client        the client index.
 * @param weaponentity  The weapoon entity name.
 * @param type          Bypass type to use.
 * @param allow         Allow bypass or not.
 *
 * void PreSetClientByPass(int client, char[] weaponentity, ByPassType type, bool allow)
 */
native void GunMenu_SetClientByPass(int client, char[] weaponentity, ByPassType type, bool allow);

/**
 * Check if client have specific bypass privilege for this weapon. 
 *
 * @param client        the client index.
 * @param weaponentity  The weapoon entity name.
 * @param type          Bypass type to use.
 *
 * return true if they're bypassed or false otherwise.
 */
native bool GunMenu_CheckClientByPass(int client, char[] weaponentity, ByPassType type);

/**
 * Get weapon index which in gun_menu plugins config file
 *
 * @param weaponentity  The weapoon entity name.
 *
 * return weaponindex, if weapon is not found return -1.
 */
native int GunMenu_GetWeaponIndexByEntityName(const char[] weaponentity);