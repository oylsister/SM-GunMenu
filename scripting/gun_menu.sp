#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <zriot>
//#include <zombiereloaded>

#pragma newdecls required

#define SLOT_PRIMARY 0
#define SLOT_SECONDARY 1
#define SLOT_KNIFE 2
#define SLOT_GRENADE 3
#define SLOT_THROWABLE 4
#define SLOT_FIRE 5

enum struct Weapon_Data
{
    char data_name[64];
    char data_entity[64];
    int data_price;
    int data_slot;
    char data_command[64];
    bool data_restrict;
}

int g_iTotal;

Weapon_Data g_Weapon[64];

bool g_bBuyZoneOnly = false;
bool g_bHookBuyZone = true;
bool g_bAllowLoadout = false;
bool g_bCommandInitialized = false;
bool g_bMenuCommandInitialized = false;

char sTag[64];

ConVar g_Cvar_BuyZoneOnly;
ConVar g_Cvar_Command;
ConVar g_Cvar_PluginTag;
ConVar g_Cvar_HookOnBuyZone;

bool g_zombiereloaded = false;
bool g_zombieriot = false;

public Plugin myinfo = 
{
    name = "[CSGO/CSS] Gun Menu",
	author = "Oylsister",
	description = "Purchase weapon from the menu and create specific command to purchase specific weapon",
	version = "1.0",
	url = "https://github.com/oylsister"
};

public void OnPluginStart()
{
    g_Cvar_BuyZoneOnly = CreateConVar("sm_gunmenu_buyzoneonly", "0.0", "Only allow to purchase on buyzone only", _, true, 0.0, true, 1.0);
    g_Cvar_Command = CreateConVar("sm_gunmenu_command", "sm_gun,sm_guns,sm_zmarket,sm_zbuy", "Specific command for open menu command");
    g_Cvar_PluginTag = CreateConVar("sm_gunmenu_prefix", "[ZBuy]", "Prefix for plugin");
    g_Cvar_HookOnBuyZone = CreateConVar("sm_gunmenu_hookbuyzone", "1.0", "Also apply purchase method to player purchase with default buy menu from buyzone", _, true, 0.0, true, 1.0);

    RegAdminCmd("sm_restrict", Command_Restrict, ADMFLAG_GENERIC);
    RegAdminCmd("sm_unrestrict", Command_Unrestrict, ADMFLAG_GENERIC);
    RegAdminCmd("sm_slot", GetSlotCommand, ADMFLAG_GENERIC);
    RegAdminCmd("sm_reloadweapon", Command_ReloadConfig, ADMFLAG_CONFIG);

    g_bMenuCommandInitialized = false;
    g_bCommandInitialized = false;

    HookConVarChange(g_Cvar_BuyZoneOnly, OnBuyZoneChanged);
    HookConVarChange(g_Cvar_Command, OnCommandChanged);
    HookConVarChange(g_Cvar_PluginTag, OnTagChanged);
    HookConVarChange(g_Cvar_HookOnBuyZone, OnHookBuyZoneChanged);

    AutoExecConfig();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("ZR_IsClientZombie");
    MarkNativeAsOptional("ZRiot_IsClientZombie");

    return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
    if(LibraryExists("zombiereloaded"))
    {
        g_zombiereloaded = true;
    }
    
    if(LibraryExists("zombieriot"))
    {
        g_zombieriot = true;
    }
}

public void OnLibraryAdded(const char[] name)
{
    if(StrEqual(name, "zombiereloaded", false))
    {
        g_zombiereloaded = true;
    }
    if(StrEqual(name, "zombieriot", false))
    {
        g_zombieriot = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if(StrEqual(name, "zombiereloaded", false))
    {
        g_zombiereloaded = true;
    }
    if(StrEqual(name, "zombieriot", false))
    {
        g_zombieriot = true;
    }
}

public void OnBuyZoneChanged(ConVar cvar, const char[] newValue, const char[] oldValue)
{
    g_bBuyZoneOnly = GetConVarBool(g_Cvar_BuyZoneOnly);
}

public void OnCommandChanged(ConVar cvar, const char[] newValue, const char[] oldValue)
{
    g_bMenuCommandInitialized = false;
    CreateMenuCommand();
}

public void OnTagChanged(ConVar cvar, const char[] newValue, const char[] oldValue)
{
    GetConVarString(g_Cvar_PluginTag, sTag, sizeof(sTag));
}

public void OnHookBuyZoneChanged(ConVar cvar, const char[] newValue, const char[] oldValue)
{
    g_bHookBuyZone = GetConVarBool(g_Cvar_HookOnBuyZone);
}

public void OnConfigsExecuted()
{
    GetConVarString(g_Cvar_PluginTag, sTag, sizeof(sTag));
    g_bBuyZoneOnly = GetConVarBool(g_Cvar_BuyZoneOnly);

    LoadConfig();
    CreateMenuCommand();
    CreateGunCommand();
}

public Action Command_ReloadConfig(int client, int args)
{
    g_bCommandInitialized = false;
    LoadConfig();
    CreateGunCommand();
    return Plugin_Handled;
}

void LoadConfig()
{
    KeyValues kv;
    char sConfigPath[PLATFORM_MAX_PATH];
    char sTemp[64];

    BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), "configs/gun_menu.txt");

    kv = CreateKeyValues("weapons");
    FileToKeyValues(kv, sConfigPath);

    if(KvGotoFirstSubKey(kv))
    {
        g_iTotal = 0;

        do
        {
            KvGetSectionName(kv, sTemp, 64);
            Format(g_Weapon[g_iTotal].data_name, 64, "%s", sTemp);

            KvGetString(kv, "entity", sTemp, sizeof(sTemp));
            Format(g_Weapon[g_iTotal].data_entity, 64, "%s", sTemp);

            KvGetString(kv, "price", sTemp, sizeof(sTemp));
            g_Weapon[g_iTotal].data_price = StringToInt(sTemp);

            g_Weapon[g_iTotal].data_slot = KvGetNum(kv, "slot", -1);

            KvGetString(kv, "command", sTemp, sizeof(sTemp));
            Format(g_Weapon[g_iTotal].data_command, 64, "%s", sTemp);

            KvGetString(kv, "restrict", sTemp, sizeof(sTemp));
            g_Weapon[g_iTotal].data_restrict = view_as<bool>(StringToInt(sTemp));

            g_iTotal++;
        }
        while(KvGotoNextKey(kv));
    }
}

void CreateMenuCommand()
{
    if(g_bMenuCommandInitialized)
    {
        return;
    }

    char menucommand[128];
    GetConVarString(g_Cvar_Command, menucommand, sizeof(menucommand));

    if(menucommand[0])
    {
        if(FindCharInString(menucommand, ',') != -1)
        {
            int idx;
            int lastidx;
            while((idx = FindCharInString(menucommand[lastidx], ',')) != -1)
            {
                char out[64];
                char fmt[64];
                Format(fmt, sizeof(fmt), "%%.%ds", idx);
                Format(out, sizeof(out), fmt, menucommand[lastidx]);
                RegConsoleCmd(out, Command_GunMenu);
                lastidx += ++idx;

                if(FindCharInString(menucommand[lastidx], ',') == -1 && menucommand[lastidx+1] != '\0')
                {
                    RegConsoleCmd(menucommand[lastidx], Command_GunMenu);
                }
            }
        }
        else
        {
            RegConsoleCmd(menucommand, Command_GunMenu);
        }
    }
    g_bMenuCommandInitialized = true;
}

void CreateGunCommand()
{
    if(g_bCommandInitialized)
    {
        return;
    }

    char weaponcommand[64];
    char weaponentity[64];
    
    for(int i = 0; i < g_iTotal; i++)
    {
        Format(weaponcommand, sizeof(weaponcommand), "%s", g_Weapon[i].data_command);
        if(weaponcommand[0])
        {
            Format(weaponentity, sizeof(weaponentity), "%s", g_Weapon[i].data_entity);

            if(FindCharInString(weaponcommand, ',') != -1)
            {
                int idx;
                int lastidx;
                while((idx = FindCharInString(weaponcommand[lastidx], ',')) != -1)
                {
                    char out[64];
                    char fmt[64];
                    Format(fmt, sizeof(fmt), "%%.%ds", idx);
                    Format(out, sizeof(out), fmt, weaponcommand[lastidx]);
                    RegConsoleCmd(out, WeaponBuyCommand, weaponentity);
                    lastidx += ++idx;

                    if(FindCharInString(weaponcommand[lastidx], ',') == -1 && weaponcommand[lastidx+1] != '\0')
                    {
                        RegConsoleCmd(weaponcommand[lastidx], WeaponBuyCommand, weaponentity);
                    }
                }
            }
            else
            {
                RegConsoleCmd(weaponcommand, WeaponBuyCommand, weaponentity);
            }
        }
    }
    g_bCommandInitialized = true;
}

public Action WeaponBuyCommand(int client, int args)
{
    char command[64];
    char weaponcommand[64];
    char weaponentity[64];

    GetCmdArg(0, command, sizeof(command));

    for(int i = 0; i < g_iTotal; i++)
    {
        Format(weaponcommand, sizeof(weaponcommand), g_Weapon[i].data_command);

        if(FindCharInString(weaponcommand, ',') != -1)
        {
            int idx;
            int lastidx;
            while((idx = FindCharInString(weaponcommand[lastidx], ',')) != -1)
            {
                if(!strncmp(command, weaponcommand[lastidx], idx))
                {
                    Format(weaponentity, sizeof(weaponentity), "%s", g_Weapon[i].data_entity);
                    PurchaseWeapon(client, weaponentity);
                    return Plugin_Stop;
                }
                lastidx += ++idx;

                if(FindCharInString(weaponcommand[lastidx], ',') == -1 && weaponcommand[lastidx+1] != '\0')
                {
                    if(!strncmp(command, weaponcommand[lastidx], idx))
                    {
                        Format(weaponentity, sizeof(weaponentity), "%s", g_Weapon[i].data_entity);
                        PurchaseWeapon(client, weaponentity);  
                        return Plugin_Stop;
                    }
                }
            }
        }
        else
        {
            if(StrEqual(command, weaponcommand))
            {
                Format(weaponentity, sizeof(weaponentity), "%s", g_Weapon[i].data_entity);
                PurchaseWeapon(client, weaponentity);
                return Plugin_Stop;
            }
        }
    }
    return Plugin_Handled;
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
    if(g_bHookBuyZone)
    {
        for(int i = 0; i < g_iTotal; i++)
        {
            char reformat[64];
            Format(reformat, sizeof(reformat), "%s", g_Weapon[i].data_entity);
            ReplaceString(reformat, sizeof(reformat), "weapon_", "");

            if(StrEqual(weapon, reformat, false))
            {
                PurchaseWeapon(client, g_Weapon[i].data_entity);
                break;
            }
        }
    }
    return Plugin_Continue;
}

public Action Command_Restrict(int client, int args)
{
    if(args < 1)
    {
        RestrictMenu(client);
        return Plugin_Handled;
    }

    char sArg[64];
    GetCmdArg(1, sArg, sizeof(sArg));

    bool found = false;

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArg, g_Weapon[i].data_name, false))
        {
            RestrictWeapon(sArg);
            found = true;
            break;
        }
    }

    if(!found)
    {
        ReplyToCommand(client, " \x04%s\x01 the weapon is invaild.");
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public Action Command_Unrestrict(int client, int args)
{
    if(args < 1)
    {
        RestrictMenu(client);
        return Plugin_Handled;
    }

    char sArg[64];
    GetCmdArg(1, sArg, sizeof(sArg));

    bool found = false;

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArg, g_Weapon[i].data_name, false))
        {
            UnrestrictWeapon(sArg);
            found = true;
            break;
        }
    }

    if(!found)
    {
        ReplyToCommand(client, " \x04%s\x01 the weapon is invaild.");
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public void RestrictWeapon(const char[] weapon)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapon, g_Weapon[i].data_name, false))
        {
            g_Weapon[i].data_restrict = true;
            PrintToChatAll(" \x04%s\x01 \x05\"%s\" \x01has been restricted", sTag, g_Weapon[i].data_name);
            break;
        }
    }
}

public void UnrestrictWeapon(const char[] weapon)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapon, g_Weapon[i].data_name, false))
        {
            g_Weapon[i].data_restrict = false;
            PrintToChatAll(" \x04%s\x01 \x05\"%s\" \x01has been unrestricted.", sTag, g_Weapon[i].data_name);
            break;
        }
    }
}

public void Toggle_RestrictWeapon(const char[] weapon)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapon, g_Weapon[i].data_name, false))
        {
            g_Weapon[i].data_restrict = !g_Weapon[i].data_restrict;

            if(g_Weapon[i].data_restrict == true)
            {
                PrintToChatAll(" \x04%s\x01 \x05\"%s\" \x01has been restricted.", sTag, g_Weapon[i].data_name);
            }
            else
            {
                PrintToChatAll(" \x04%s\x01 \x05\"%s\" \x01has been unrestricted.", sTag, g_Weapon[i].data_name);
            }
            break;
        }
    }
}

public Action GetSlotCommand(int client, int args)
{
    if(args == 0)
    {
        ReplyToCommand(client, " \x04%s\x01 Usage: sm_slot <weaponname>", sTag);
        return Plugin_Handled;
    }

    char sArgs[64];
    GetCmdArg(1, sArgs, sizeof(sArgs));

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArgs, g_Weapon[i].data_name))
        {
            PrintToChat(client, " \x04%s\x01 %s slot is %i.", sTag, g_Weapon[i].data_name, g_Weapon[i].data_slot);
            break;
        }
    }
    return Plugin_Handled;
}

public Action Command_GunMenu(int client, int args)
{
    Menu menu = new Menu(MainMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Main Menu", sTag);
    menu.AddItem("buy", "Buy Weapon");
    menu.AddItem("loadout", "Your Loadout");
    menu.AddItem("SPACE", "---------------");
    menu.AddItem("settings", "Server Setting");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DrawItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "settings"))
            {
                if(!IsClientAdmin(param1))
                {
                    return ITEMDRAW_DISABLED;
                }
            }
            else if(StrEqual(info, "SPACE"))
            {
                return ITEMDRAW_DISABLED;
            }
            else if(StrEqual(info, "loadout"))
            {
                if(!g_bAllowLoadout)
                {
                    return ITEMDRAW_DISABLED;
                }
            }
        }
        case MenuAction_DisplayItem:
        {
            char info[64];
            char display[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "settings"))
            {
                if(!IsClientAdmin(param1))
                {
                    Format(display, sizeof(display), "%s (Admin Only)", info);
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "buy"))
            {
                WeaponTypeMenu(param1);
            }
            else if(StrEqual(info, "loadout"))
            {
                ClientLoadoutMenu(param1);
            }
            else if(StrEqual(info, "settings"))
            {
                ServerSettingMenu(param1);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void WeaponTypeMenu(int client)
{
    Menu menu = new Menu(WeaponTypeMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Weapon Type Menu", sTag);
    menu.AddItem("primary", "Primary Weapon");
    menu.AddItem("secondary", "Secondary Weapon");
    menu.AddItem("grenade", "Grenade");
    menu.AddItem("throwable", "Throwable");
    menu.AddItem("fire", "Fire Grenade");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int WeaponTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            {
                if(StrEqual(info, "primary"))
                {
                    PrimaryMenu(param1);
                }
                else if(StrEqual(info, "secondary"))
                {
                    SecondaryMenu(param1);
                }
                else if(StrEqual(info, "grenade"))
                {
                    GrenadeMenu(param1);
                }
                else if(StrEqual(info, "throwable"))
                {
                    ThrowableMenu(param1);
                }
                else
                {
                    FireGrenadeMenu(param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
            Command_GunMenu(param1, 0);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void PrimaryMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Primary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_PRIMARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void SecondaryMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Secondary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_SECONDARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void GrenadeMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_GRENADE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void ThrowableMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Throwable Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_THROWABLE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void FireGrenadeMenu(int client)
{
    Menu menu = new Menu(SelectMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Fire Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_FIRE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s - (%d$)", g_Weapon[i].data_name, g_Weapon[i].data_price);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int SelectMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DrawItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    if(g_Weapon[i].data_restrict == true)
                    {
                        return ITEMDRAW_DISABLED;
                    }
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    PurchaseWeapon(param1, g_Weapon[i].data_entity);
                }
            }
        }
        case MenuAction_Cancel:
        {
            WeaponTypeMenu(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void PurchaseWeapon(int client, const char[] entity)
{
    if(!IsPlayerAlive(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be alive to purchase the weapon.", sTag);
        return;
    }

    if(g_zombieriot || g_zombiereloaded)
    {
        if(ZRiot_IsClientZombie(client))
        {
            PrintToChat(client, " \x04%s\x01 You must be Human to purchase the weapon.", sTag);
            return;
        }
    }

    if(g_bBuyZoneOnly && !IsClientInBuyZone(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be in the buyzone to purchase the weapon.", sTag);
        return;
    }

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(entity, g_Weapon[i].data_entity, false))
        {
            if(g_Weapon[i].data_restrict == true)
            {
                PrintToChat(client, " \x04%s\x01 \x04\"%s\" has been restricted.", sTag, g_Weapon[i].data_name);
                break;
            }
            int cash = GetEntProp(client, Prop_Send, "m_iAccount");

            if(g_Weapon[i].data_price > cash)
            {
                PrintToChat(client, " \x04%s\x01 You don't have enough cash to purchase this item.", sTag);
                break;
            }

            int weapon = GetPlayerWeaponSlot(client, g_Weapon[i].data_slot);
            int slot = g_Weapon[i].data_slot;

            if(slot != SLOT_KNIFE || slot != SLOT_GRENADE || slot != SLOT_THROWABLE || slot != SLOT_FIRE)
            {
                if(weapon != -1)
                {
                    CS_DropWeapon(client, weapon, true, false);
                }
            }

            else if(slot == SLOT_THROWABLE || slot == SLOT_FIRE)
            {
                slot = SLOT_GRENADE;
            }

            SetEntProp(client, Prop_Send, "m_iAccount", cash - g_Weapon[i].data_price);
            GivePlayerItem(client, g_Weapon[i].data_entity);
            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\" \x01. Select weapon from menu or use command to purchase again.", sTag, g_Weapon[i].data_name);
            break;
        }
    }
}

public void ClientLoadoutMenu(int client)
{

}

public void ServerSettingMenu(int client)
{
    Menu menu = new Menu(ServerSettingMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Setting Menu", sTag);
    menu.AddItem("buyzone", "BuyZone Only");
    menu.AddItem("restrict", "Restrict Weapon");
    menu.AddItem("loadout", "Allow Loadout");

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ServerSettingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DrawItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "loadout"))
            {
                return ITEMDRAW_DISABLED;
            }
        }
        case MenuAction_DisplayItem:
        {
            char info[64];
            char display[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "loadout"))
            {
                Format(display, sizeof(display), "%s (unavailable)", info);
                return RedrawMenuItem(display);
            }
            else if(StrEqual(info, "buyzone"))
            {
                if(!g_bBuyZoneOnly)
                {
                    Format(display, sizeof(display), "%s: False", info);
                    return RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: True", info);
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "buyzone"))
            {
                g_bBuyZoneOnly = !g_bBuyZoneOnly;
                ServerSettingMenu(param1);
            }
            else if(StrEqual(info, "restrict"))
            {
                RestrictMenu(param1);
            }
        }
        case MenuAction_Cancel:
        {
            Command_GunMenu(param1, 0);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void RestrictMenu(int client)
{
    Menu menu = new Menu(RestrictTypeMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Restrict Weapon Menu", sTag);
    menu.AddItem("primary", "Primary Weapon");
    menu.AddItem("secondary", "Secondary Weapon");
    menu.AddItem("grenade", "Grenade");
    menu.AddItem("throwable", "Throwable");
    menu.AddItem("fire", "Fire Grenade");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int RestrictTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            {
                if(StrEqual(info, "primary"))
                {
                    RestrictPrimaryMenu(param1);
                }
                else if(StrEqual(info, "secondary"))
                {
                    RestrictSecondaryMenu(param1);
                }
                else if(StrEqual(info, "grenade"))
                {
                    RestrictGrenadeMenu(param1);
                }
                else if(StrEqual(info, "throwable"))
                {
                    RestrictThrowableMenu(param1);
                }
                else
                {
                    RestrictFireGrenadeMenu(param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
            ServerSettingMenu(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void RestrictPrimaryMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Primary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_PRIMARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void RestrictSecondaryMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Secondary Weapons", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_SECONDARY)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void RestrictGrenadeMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_GRENADE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void RestrictThrowableMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Throwable Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_THROWABLE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void RestrictFireGrenadeMenu(int client)
{
    Menu menu = new Menu(SelectRestrictMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Fire Grenade", sTag);
    for (int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == SLOT_FIRE)
        {
            char choice[64];
            Format(choice, sizeof(choice), "%s", g_Weapon[i].data_name);
            menu.AddItem(g_Weapon[i].data_name, choice);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int SelectRestrictMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DisplayItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    if(g_Weapon[i].data_restrict == true)
                    {
                        char display[64];
                        Format(display, sizeof(display), "%s - Restricted", info);
                        RedrawMenuItem(display);
                    }
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            for (int i = 0; i < g_iTotal; i++)
            {
                if(StrEqual(info, g_Weapon[i].data_name, false))
                {
                    Toggle_RestrictWeapon(g_Weapon[i].data_name);
                }
            }
        }
        case MenuAction_Cancel:
        {
            RestrictMenu(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

stock bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC);
}

stock bool IsClientInBuyZone(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send,"m_bInBuyZone"));
}