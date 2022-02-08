#if defined _gunmenu_included
  #endinput
#endif
#define _gunmenu_included

/**
 * Called when a client is about to purchase through Gun-Menu plugin
 *
 * @param client        the client index.
 * @paran weaponentity  The weapoon entity name.
 *
 * public void PurchaseWeapon(int client, const char[] entity)
 */

forward Action GunMenu_OnClientPurchase(int client, const char[] weaponentity);