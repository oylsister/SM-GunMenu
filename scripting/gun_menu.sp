#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <gun_menu>

#undef REQUIRE_PLUGIN
#include <zriot>
#include <zombiereloaded>
#include <smrpg_armorplus>

bool zombiereloaded;
bool zombieriot;
bool smrpg_armor;

#pragma newdecls required

#define SLOT_PRIMARY 0
#define SLOT_SECONDARY 1
#define SLOT_KNIFE 2
#define SLOT_GRENADE 3
#define SLOT_KEVLAR 4

#define WEAPON_SLOT_MAX 4

enum struct Weapon_Data
{
    char data_name[64];
    char data_entity[64];
    char data_type[64];
    bool data_multienable;
    float data_multiprice;
    int data_price;
    int data_slot;
    char data_command[64];
    bool data_restrict;
    int data_maxpurchase;
    float data_cooldown;
}

int g_iTotal;

Weapon_Data g_Weapon[64];

bool g_bBuyZoneOnly = false;
bool g_bHookBuyZone = true;
bool g_bAllowLoadout = true;
bool g_bCommandInitialized = false;
bool g_bMenuCommandInitialized = false;
bool g_bSaveOnMenuCommand;

char sTag[64];

ConVar g_Cvar_BuyZoneOnly;
ConVar g_Cvar_Command;
ConVar g_Cvar_PluginTag;
ConVar g_Cvar_HookOnBuyZone;
ConVar g_Cvar_ConfigPath;
ConVar g_Cvar_SaveOnMenuCommand;
ConVar g_Cvar_CooldownMode;
ConVar g_Cvar_GlobalCooldown;
ConVar g_Cvar_FreeOnSpawn;
ConVar g_Cvar_MenuOnSpawn;

// Default Weapon
ConVar g_Cvar_Def_Primary;
ConVar g_Cvar_Def_Secondary;
ConVar g_Cvar_Free_Kevlar;
ConVar g_Cvar_Free_HE;

char sDefPrimary[64];
char sDefSecondary[64];

bool g_bFreeKevlar;
bool g_bFreeHe;

bool g_bZombieSpawned;

char g_sConfigPath[PLATFORM_MAX_PATH];

int g_iCooldownMode;
float g_fGlobalCooldown;
bool g_bFreeOnSpawn;

enum struct ByPassWeapon
{
    bool ByPass_Price;
    bool ByPass_Count;
    bool ByPass_Restrict;
    bool ByPass_Cooldown;
}

ByPassWeapon g_ByPass[64][MAXPLAYERS+1];

bool g_bByPass_GlobalCooldown[MAXPLAYERS+1];

int g_iPurchaseCount[64][MAXPLAYERS+1];
float g_fPurchaseCooldown[64][MAXPLAYERS+1];
float g_fPurchaseGlobalCooldown[MAXPLAYERS+1];

// Client Preferences
Handle g_hWeaponCookies[WEAPON_SLOT_MAX] = INVALID_HANDLE;
Handle g_hRebuyCookies = INVALID_HANDLE;

bool g_bAutoRebuy[MAXPLAYERS+1];

// Forward
GlobalForward g_hOnClientPurchase;

public Plugin myinfo = 
{
    name = "[CSGO/CSS] Gun Menu",
    author = "Oylsister",
    description = "Purchase weapon from the menu and create specific command to purchase specific weapon",
    version = "3.1",
    url = "https://github.com/oylsister/SM-GunMenu"
};

public void OnPluginStart()
{
    g_Cvar_BuyZoneOnly = CreateConVar("sm_gunmenu_buyzoneonly", "0.0", "Only allow to purchase on buyzone only", _, true, 0.0, true, 1.0);
    g_Cvar_Command = CreateConVar("sm_gunmenu_command", "sm_gun,sm_guns,sm_zmarket,sm_zbuy", "Specific command for open menu command");
    g_Cvar_PluginTag = CreateConVar("sm_gunmenu_prefix", "[ZBuy]", "Prefix for plugin");
    g_Cvar_HookOnBuyZone = CreateConVar("sm_gunmenu_hookbuyzone", "1.0", "Also apply purchase method to player purchase with default buy menu from buyzone", _, true, 0.0, true, 1.0);
    g_Cvar_ConfigPath = CreateConVar("sm_gunmenu_configpath", "configs/gun_menu.txt", "Specify the path of config file for gun menu");
    g_Cvar_SaveOnMenuCommand = CreateConVar("sm_gunmenu_saveloadout_onmenu", "1.0", "Save weapon loadout when player do !zbuy <weaponname>", _, true, 0.0, true, 1.0);
    g_Cvar_CooldownMode = CreateConVar("sm_gunmenu_cooldown_mode", "1.0", "0 = Disabled | 1 = Global Cooldown | 2 = Inviduals Cooldown", _, true, 0.0, true, 2.0);
    g_Cvar_GlobalCooldown = CreateConVar("sm_gunmenu_global_cooldown", "5.0", "Length of Global Cooldown in seconds", _, true, 0.0, false);
    g_Cvar_FreeOnSpawn = CreateConVar("sm_gunmenu_free_onspawn", "1.0", "Free purchase on spawn", _, true, 0.0, true, 1.0);
    g_Cvar_MenuOnSpawn = CreateConVar("sm_gunmenu_menu_onspawn", "1.0", "Display gun menu to players on spawn", _, true, 0.0, true, 1.0);

    g_Cvar_Def_Primary = CreateConVar("sm_gunmenu_default_primary", "P90", "Default Primary weapon");
    g_Cvar_Def_Secondary = CreateConVar("sm_gunmenu_default_secondary", "Elite", "Default Secondary weapon");
    g_Cvar_Free_Kevlar = CreateConVar("sm_gunmenu_free_kevlar", "1", "Give Free Kevlar to player", _, true, 0.0, true, 1.0);
    g_Cvar_Free_HE = CreateConVar("sm_gunmenu_free_he", "1", "Give Free HE to player", _, true, 0.0, true, 1.0);

    RegAdminCmd("sm_restrict", Command_Restrict, ADMFLAG_GENERIC);
    RegAdminCmd("sm_unrestrict", Command_Unrestrict, ADMFLAG_GENERIC);
    RegAdminCmd("sm_slot", GetSlotCommand, ADMFLAG_GENERIC);
    RegAdminCmd("sm_reloadweapon", Command_ReloadConfig, ADMFLAG_CONFIG);

    g_bMenuCommandInitialized = false;
    g_bCommandInitialized = false;

    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("round_start", OnRoundStart);

    HookConVarChange(g_Cvar_BuyZoneOnly, OnBuyZoneChanged);
    HookConVarChange(g_Cvar_Command, OnCommandChanged);
    HookConVarChange(g_Cvar_PluginTag, OnTagChanged);
    HookConVarChange(g_Cvar_HookOnBuyZone, OnHookBuyZoneChanged);
    HookConVarChange(g_Cvar_ConfigPath, OnConfigPathChanged);
    HookConVarChange(g_Cvar_SaveOnMenuCommand, OnSaveOnMenuCommandChanged);
    HookConVarChange(g_Cvar_CooldownMode, OnCooldownModeChanged);
    HookConVarChange(g_Cvar_GlobalCooldown, OnGlobalCooldownChanged);
    HookConVarChange(g_Cvar_FreeOnSpawn, OnFreeOnSpawnChanged);

    HookConVarChange(g_Cvar_Def_Primary, OnDefaultChanged);
    HookConVarChange(g_Cvar_Def_Secondary, OnDefaultChanged);
    HookConVarChange(g_Cvar_Free_Kevlar, OnDefaultChanged);
    HookConVarChange(g_Cvar_Free_HE, OnDefaultChanged);

    if(g_hRebuyCookies == INVALID_HANDLE)
    {
        g_hRebuyCookies = RegClientCookie("gunmenu_autorebuy", "Toggle Auto Rebuy", CookieAccess_Protected);
    }

    for(int i = 0; i < WEAPON_SLOT_MAX; i++)
    {
        if(g_hWeaponCookies[i] == INVALID_HANDLE)
        {
            char cookiename[64];
            char cookiedesc[64];

            Format(cookiename, sizeof(cookiename), "gunmenu_loadoutslot_%d", i);
            Format(cookiedesc, sizeof(cookiedesc), "Client Loadout Slot %d", i);

            g_hWeaponCookies[i] = RegClientCookie(cookiename, cookiedesc, CookieAccess_Protected);
        }
    }

    for(int i = 1; i <= MaxClients; i++)
    {
        if(AreClientCookiesCached(i))
        {
            OnClientCookiesCached(i);
        }
    }

    AutoExecConfig();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_hOnClientPurchase = CreateGlobalForward("GunMenu_OnClientPurchase", ET_Hook, Param_Cell, Param_String, Param_Cell, Param_Cell);

    CreateNative("GunMenu_SetClientByPass", Native_SetClientByPass);
    CreateNative("GunMenu_CheckClientByPass", Native_CheckClientByPass);
    CreateNative("GunMenu_GetWeaponIndexByEntityName", Native_GetWeaponIndexByEntityName);

    MarkNativeAsOptional("ZR_IsClientZombie");
    MarkNativeAsOptional("ZRiot_IsClientZombie");
    MarkNativeAsOptional("SMRPG_Armor_GetClientMaxArmor");

    return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
    zombiereloaded = LibraryExists("zombiereloaded");
    zombieriot = LibraryExists("zombieriot");
    smrpg_armor = LibraryExists("smrpg_armorplus");
}
 
public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "zombiereloaded"))
    {
        zombiereloaded = false;
    }

    if (StrEqual(name, "zombieriot"))
    {
        zombieriot = false;
    }

    if (StrEqual(name, "zombiereloaded"))
    {
        zombiereloaded = false;
    }
}
 
public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "zombiereloaded"))
    {
        zombiereloaded = true;
    }

    if (StrEqual(name, "zombieriot"))
    {
        zombieriot = true;
    }

    if (StrEqual(name, "smrpg_armorplus"))
    {
        smrpg_armor = true;
    }
}

void ResetClientData(int client)
{
    for(int i = 0; i < 64; i++)
    {
        g_iPurchaseCount[i][client] = 0;
        g_fPurchaseCooldown[i][client] = 0.0;
    }

    g_fPurchaseGlobalCooldown[client] = 0.0;
}

void ResetByPass(int client)
{
    for(int i = 0; i < 64; i++)
    {
        g_ByPass[i][client].ByPass_Price = false;
        g_ByPass[i][client].ByPass_Count = false;
        g_ByPass[i][client].ByPass_Restrict = false;
        g_ByPass[i][client].ByPass_Cooldown = false;
    }

    g_bByPass_GlobalCooldown[client] = false;
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);

    ResetClientData(client);
    ResetByPass(client);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);

    ResetClientData(client);
    ResetByPass(client);
}

public void OnBuyZoneChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_bBuyZoneOnly = GetConVarBool(g_Cvar_BuyZoneOnly);
}

public void OnCommandChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_bMenuCommandInitialized = false;
    CreateMenuCommand();
}

public void OnTagChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    GetConVarString(g_Cvar_PluginTag, sTag, sizeof(sTag));
}

public void OnHookBuyZoneChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_bHookBuyZone = GetConVarBool(g_Cvar_HookOnBuyZone);
}

public void OnConfigPathChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    GetConVarString(g_Cvar_ConfigPath, g_sConfigPath, sizeof(g_sConfigPath));
    ReloadConfig();
}

public void OnSaveOnMenuCommandChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_bSaveOnMenuCommand = GetConVarBool(g_Cvar_SaveOnMenuCommand);
}

public void OnCooldownModeChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_iCooldownMode = GetConVarInt(g_Cvar_CooldownMode);
}

public void OnGlobalCooldownChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_fGlobalCooldown = GetConVarFloat(g_Cvar_GlobalCooldown);
}

public void OnFreeOnSpawnChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_bFreeOnSpawn = GetConVarBool(g_Cvar_FreeOnSpawn);
}

public void OnDefaultChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    if(cvar == g_Cvar_Def_Primary)
        GetConVarString(g_Cvar_Def_Primary, sDefPrimary, sizeof(sDefPrimary));

    else if(cvar == g_Cvar_Def_Secondary)
        GetConVarString(g_Cvar_Def_Secondary, sDefSecondary, sizeof(sDefSecondary));

    else if(cvar == g_Cvar_Free_Kevlar)
        g_bFreeKevlar = GetConVarBool(g_Cvar_Free_Kevlar);

    else if(cvar == g_Cvar_Free_HE)
        g_bFreeHe = GetConVarBool(g_Cvar_Free_HE);
}

public Action OnWeaponCanUse(int client, int weapon)
{
    char weaponentity[64];
    GetEdictClassname(weapon, weaponentity, sizeof(weaponentity));

    int index = FindWeaponIndexByEntityName(weaponentity);

    if(index == -1)
        return Plugin_Continue;

    if(StrEqual(weaponentity, g_Weapon[index].data_entity, false))
    {
        if(g_Weapon[index].data_restrict)
        {
            if(!IsClientByPassRestrict(client, index))
                return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

public void OnClientCookiesCached(int client)
{
    char sBuffer[32];
    GetClientCookie(client, g_hRebuyCookies, sBuffer, sizeof(sBuffer));

    if(sBuffer[0] != '\0')
    {
        g_bAutoRebuy[client] = view_as<bool>(StringToInt(sBuffer));
    }
    else
    {
        g_bAutoRebuy[client] = false;
        SaveRebuyCookie(client);
    }

    for(int i = 0; i < WEAPON_SLOT_MAX; i++)
    {
        char sBuffer2[32];
        GetClientCookie(client, g_hWeaponCookies[i], sBuffer2, sizeof(sBuffer2));

        if(sBuffer2[0] == '\0')
        {
            if(i == SLOT_PRIMARY)
            {
                Format(sBuffer2, sizeof(sBuffer2), "%s", sDefPrimary);
            }
            else if(i == SLOT_SECONDARY)
            {
                Format(sBuffer2, sizeof(sBuffer2), "%s", sDefSecondary);
            }
            else
            {
                Format(sBuffer2, sizeof(sBuffer2), "");
            }
            SaveLoadoutCookie(client, i, sBuffer2);
        }
    }
}

void SaveRebuyCookie(int client)
{
    char sCookie[32];
    FormatEx(sCookie, sizeof(sCookie), "%b", g_bAutoRebuy[client]);
    SetClientCookie(client, g_hRebuyCookies, sCookie);
}

void SaveLoadoutCookie(int client, int weaponslot, const char[] weaponname)
{
    for(int i = 0; i < WEAPON_SLOT_MAX; i++)
    {
        if(weaponslot == i)
        {
            SetClientCookie(client, g_hWeaponCookies[i], weaponname);
            return;
        }
    }
}

public void OnConfigsExecuted()
{
    GetConVarString(g_Cvar_PluginTag, sTag, sizeof(sTag));
    g_bBuyZoneOnly = GetConVarBool(g_Cvar_BuyZoneOnly);
    GetConVarString(g_Cvar_ConfigPath, g_sConfigPath, sizeof(g_sConfigPath));
    g_bSaveOnMenuCommand = GetConVarBool(g_Cvar_SaveOnMenuCommand);
    g_iCooldownMode = GetConVarInt(g_Cvar_CooldownMode);
    g_fGlobalCooldown = GetConVarFloat(g_Cvar_GlobalCooldown);
    g_bFreeOnSpawn = GetConVarBool(g_Cvar_FreeOnSpawn);

    GetConVarString(g_Cvar_Def_Primary, sDefPrimary, sizeof(sDefPrimary));
    GetConVarString(g_Cvar_Def_Secondary, sDefSecondary, sizeof(sDefSecondary));
    g_bFreeKevlar = GetConVarBool(g_Cvar_Free_Kevlar);
    g_bFreeHe = GetConVarBool(g_Cvar_Free_HE);

    LoadConfig();
    CreateMenuCommand();
    CreateGunCommand();
}

public Action Command_ReloadConfig(int client, int args)
{
    ReloadConfig();
    return Plugin_Handled;
}

public void ReloadConfig()
{
    g_bCommandInitialized = false;
    LoadConfig();
    CreateGunCommand();
}

void LoadConfig()
{
    KeyValues kv;
    char sTemp[64];
    char sConfigPath[PLATFORM_MAX_PATH];

    BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), "%s", g_sConfigPath);

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

            KvGetString(kv, "type", sTemp, sizeof(sTemp));
            Format(g_Weapon[g_iTotal].data_type, 64, "%s", sTemp);

            KvGetString(kv, "price", sTemp, sizeof(sTemp));
            g_Weapon[g_iTotal].data_price = StringToInt(sTemp);

            g_Weapon[g_iTotal].data_multiprice = KvGetFloat(kv, "multiprice", 1.0);
            
            if(g_Weapon[g_iTotal].data_multiprice > 1.0)
            {
                g_Weapon[g_iTotal].data_multienable = true;
            }
            else if(g_Weapon[g_iTotal].data_multiprice == 1.0)
            {
                g_Weapon[g_iTotal].data_multienable = false;
            }
            else
            {
                LogError("[%s] You cannot set value to lower than 1.0 for multiprice!", g_Weapon[g_iTotal].data_name);
                g_Weapon[g_iTotal].data_multiprice = 1.0;
                g_Weapon[g_iTotal].data_multienable = false;
            }

            g_Weapon[g_iTotal].data_slot = KvGetNum(kv, "slot", -1);

            KvGetString(kv, "command", sTemp, sizeof(sTemp));
            Format(g_Weapon[g_iTotal].data_command, 64, "%s", sTemp);

            KvGetString(kv, "restrict", sTemp, sizeof(sTemp));
            g_Weapon[g_iTotal].data_restrict = view_as<bool>(StringToInt(sTemp));

            g_Weapon[g_iTotal].data_maxpurchase = KvGetNum(kv, "maxpurchase", 0);

            g_Weapon[g_iTotal].data_cooldown = KvGetFloat(kv, "cooldown", 0.0);

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
                    PurchaseWeapon(client, weaponentity, false);
                    return Plugin_Stop;
                }
                lastidx += ++idx;

                if(FindCharInString(weaponcommand[lastidx], ',') == -1 && weaponcommand[lastidx+1] != '\0')
                {
                    if(!strncmp(command, weaponcommand[lastidx], idx))
                    {
                        Format(weaponentity, sizeof(weaponentity), "%s", g_Weapon[i].data_entity);
                        PurchaseWeapon(client, weaponentity, false);  
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
                PurchaseWeapon(client, weaponentity, false);
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
                PurchaseWeapon(client, g_Weapon[i].data_entity, false);
                return Plugin_Handled;
            }
        }
    }
    return Plugin_Continue;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bZombieSpawned = false;

    if (g_Cvar_MenuOnSpawn.BoolValue)
    {
        for (int client = 1; client <= MaxClients; client++)
        {
            GunMenu(client);
        }
    }
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if(g_bAutoRebuy[client])  
        CreateTimer(0.5, DelayApplyTimer, client);

    ResetClientData(client);
}

public Action DelayApplyTimer(Handle timer, any client)
{
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Handled;

    if(zombiereloaded && ZR_IsClientZombie(client))
        return Plugin_Handled;

    BuySavedLoadout(client, true);
    int grenade = GetPlayerWeaponSlot(client, SLOT_GRENADE);
    int kevlar = GetEntProp(client, Prop_Send, "m_ArmorValue");

    if(kevlar < 100 && g_bFreeKevlar)
    {
        SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
    }

    if(grenade == -1 && g_bFreeHe)
    {
        GivePlayerItem(client, "weapon_hegrenade");
    }
    return Plugin_Handled;
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

    if(StrEqual(sArg, "all"))
    {
        for(int i = 0; i < g_iTotal; i++)
        {
            g_Weapon[i].data_restrict = true;
        }

        PrintToChatAll(" \x04%s\x01 Weapon-Type \x06\"All\" \x01has been restricted.", sTag);
        return Plugin_Handled;
    }

    bool found = false;

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArg, g_Weapon[i].data_name, false))
        {
            RestrictWeapon(sArg);
            found = true;
            return Plugin_Handled;
        }
        else if(StrEqual(sArg, g_Weapon[i].data_type, false))
        {
            RestrictTypeWeapon(sArg);
            found = true;
            return Plugin_Handled;
        }
    }

    if(!found)
    {
        ReplyToCommand(client, " \x04%s\x01 the weapon or weapon type is invaild.");
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

    if(StrEqual(sArg, "all"))
    {
        for(int i = 0; i < g_iTotal; i++)
        {
            g_Weapon[i].data_restrict = false;
        }

        PrintToChatAll(" \x04%s\x01 Weapon-Type \x06\"All\" \x01has been unrestricted.", sTag);
        return Plugin_Handled;
    }

    bool found = false;

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(sArg, g_Weapon[i].data_name, false))
        {
            UnrestrictWeapon(sArg);
            found = true;
            return Plugin_Handled;
        }
        else if(StrEqual(sArg, g_Weapon[i].data_type, false))
        {
            UnrestrictTypeWeapon(sArg);
            found = true;
            return Plugin_Handled;
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
            PrintToChatAll(" \x04%s\x01 Weapon \x06\"%s\" \x01has been restricted", sTag, g_Weapon[i].data_name);
            return;
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
            PrintToChatAll(" \x04%s\x01 Weapon \x06\"%s\" \x01has been unrestricted.", sTag, g_Weapon[i].data_name);
            return;
        }
    }
}

public void RestrictTypeWeapon(const char[] weapontype)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapontype, g_Weapon[i].data_type, false))
        {
            g_Weapon[i].data_restrict = true;
        }
    }
    PrintToChatAll(" \x04%s\x01 Weapon-Type \x06\"%s\" \x01has been restricted.", sTag, weapontype);
}

public void UnrestrictTypeWeapon(const char[] weapontype)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weapontype, g_Weapon[i].data_type, false))
        {
            g_Weapon[i].data_restrict = false;
        }
    }
    PrintToChatAll(" \x04%s\x01 Weapon-Type \x06\"%s\" \x01has been unrestricted.", sTag, weapontype);
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
                PrintToChatAll(" \x04%s\x01 Weapon \x06\"%s\" \x01has been restricted.", sTag, g_Weapon[i].data_name);
            }
            else
            {
                PrintToChatAll(" \x04%s\x01 Weapon \x06\"%s\" \x01has been unrestricted.", sTag, g_Weapon[i].data_name);
            }
            return;
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
            return Plugin_Handled;
        }
    }
    return Plugin_Handled;
}

public Action Command_GunMenu(int client, int args)
{
    if(args == 0)
    {
        GunMenu(client);
        return Plugin_Handled;
    }
    
    char command[64];
    char weaponcommand[64];
    char weaponentity[64];

    GetCmdArg(1, command, sizeof(command));

    int slot;

    for (int i = 0; i < g_iTotal; i++)
    {
        // Looking from weapon command
        Format(weaponcommand, sizeof(weaponcommand), g_Weapon[i].data_command);
        ReplaceString(weaponcommand, sizeof(weaponcommand), "sm_", "", false);

        if(FindCharInString(weaponcommand, ',') != -1)
        {
            int idx;
            int lastidx;
            while((idx = FindCharInString(weaponcommand[lastidx], ',')) != -1)
            {
                if(!strncmp(command, weaponcommand[lastidx], idx))
                {
                    Format(weaponentity, sizeof(weaponentity), "%s", g_Weapon[i].data_entity);
                    PurchaseWeapon(client, weaponentity, false);
                    if(g_bSaveOnMenuCommand)
                    {
                        slot = g_Weapon[i].data_slot;
                        SaveLoadoutCookie(client, slot, g_Weapon[i].data_name);
                    }
                    return Plugin_Stop;
                }
                lastidx += ++idx;

                if(FindCharInString(weaponcommand[lastidx], ',') == -1 && weaponcommand[lastidx+1] != '\0')
                {
                    if(!strncmp(command, weaponcommand[lastidx], idx))
                    {
                        Format(weaponentity, sizeof(weaponentity), "%s", g_Weapon[i].data_entity);
                        PurchaseWeapon(client, weaponentity, false);  
                        if(g_bSaveOnMenuCommand)
                        {
                            slot = g_Weapon[i].data_slot;
                            SaveLoadoutCookie(client, slot, g_Weapon[i].data_name);
                        }
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
                PurchaseWeapon(client, weaponentity, false);
                if(g_bSaveOnMenuCommand)
                {
                    slot = g_Weapon[i].data_slot;
                    SaveLoadoutCookie(client, slot, g_Weapon[i].data_name);
                }
                return Plugin_Stop;
            }
        }

        // Looking from entity name
        Format(weaponentity, sizeof(weaponentity), g_Weapon[i].data_entity);
        ReplaceString(weaponentity, sizeof(weaponentity), "weapon_", "", false);

        if(StrEqual(command, weaponentity, false))
        {
            PurchaseWeapon(client, g_Weapon[i].data_entity, false);
            if(g_bSaveOnMenuCommand)
            {
                slot = g_Weapon[i].data_slot;
                SaveLoadoutCookie(client, slot, g_Weapon[i].data_name);
            }
            return Plugin_Stop;
        }

        // Looking from weapon name
        if(StrEqual(command, g_Weapon[i].data_name, false))
        {
            PurchaseWeapon(client, g_Weapon[i].data_entity, false);
            if(g_bSaveOnMenuCommand)
            {
                slot = g_Weapon[i].data_slot;
                SaveLoadoutCookie(client, slot, g_Weapon[i].data_name);
            }
            return Plugin_Stop;
        }
    }

    ReplyToCommand(client, " \x04%s\x01 Could not find any weapon name \"%s\".", sTag, command);
    GunMenu(client);
    return Plugin_Stop;
}

public void GunMenu(int client)
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
                else
                {
                    GrenadeMenu(param1);
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
                    PurchaseWeapon(param1, g_Weapon[i].data_entity, false);
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

void PurchaseWeapon(int client, const char[] entity, bool loadout, bool free = false)
{
    Action result = ForwardOnClientPurchase(client, entity, loadout, free);

    if(result == Plugin_Handled)
    {
        return;
    }

    if(!IsPlayerAlive(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be alive to purchase the weapon.", sTag);
        return;
    }

    if(zombieriot && ZRiot_IsClientZombie(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be Human to purchase the weapon.", sTag);
        return;
    }

    if(zombiereloaded && ZR_IsClientZombie(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be Human to purchase the weapon.", sTag);
        return;
    }

    if(g_bBuyZoneOnly && !IsClientInBuyZone(client))
    {
        PrintToChat(client, " \x04%s\x01 You must be in the buyzone to purchase the weapon.", sTag);
        return;
    }

    int index = FindWeaponIndexByEntityName(entity);

    if(StrEqual(entity, g_Weapon[index].data_entity, false))
    {
        if(g_Weapon[index].data_restrict)
        {
            if(!IsClientByPassRestrict(client, index))
            {
                PrintToChat(client, " \x04%s\x01 Weapon \x06\"%s\" \x01has been restricted.", sTag, g_Weapon[index].data_name);
                return;
            }
        }

        float cooldown;

        if(g_iCooldownMode == 2)
            cooldown = g_Weapon[index].data_cooldown;

        else 
            cooldown = g_fGlobalCooldown;

        float thetime = GetEngineTime();

        float expirecooldown;
        
        if(g_iCooldownMode == 2)
            expirecooldown = GetPurchaseCooldown(client, g_Weapon[index].data_name);

        else 
            expirecooldown = g_fPurchaseGlobalCooldown[client];
        
        if(!IsClientByPassGlobalCooldown(client) &&!StrEqual(entity, "weapon_kevlar"))
        {
            if(cooldown > 0 && thetime < expirecooldown && !loadout)
            {
                if(!IsClientByPassCooldown(client, index))
                {
                    if(zombiereloaded && g_bZombieSpawned)
                    {
                        PrintToChat(client, " \x04%s\x01 Weapon \x06\"%s\" \x01purchasing is on the cooldown. Available again in \x06%d\x01 seconds.", sTag, g_Weapon[index].data_name, RoundToNearest(expirecooldown - thetime));
                        return;
                    }
                    else
                    {
                        PrintToChat(client, " \x04%s\x01 Weapon \x06\"%s\" \x01purchasing is on the cooldown. Available again in \x06%d\x01 seconds.", sTag, g_Weapon[index].data_name, RoundToNearest(expirecooldown - thetime));
                        return;
                    }
                }
            }
        }

        int purchasemax = GetWeaponPurchaseMax(g_Weapon[index].data_name);
        int purchasecount = GetPurchaseCount(client, g_Weapon[index].data_name);
        int purchaseleft = purchasemax - purchasecount;

        if(purchasemax > 0 && purchaseleft <= 0)
        {
            if(!IsClientByPassCount(client, index))
            {
                PrintToChat(client, " \x04%s\x01 You have reached maximum purchase for \x04\"%s\"\x01. You can purchase it again on next round.", sTag, g_Weapon[index].data_name);
                return;
            }
        }

        int cash = GetEntProp(client, Prop_Send, "m_iAccount");

        int originalprice = g_Weapon[index].data_price;
        bool ismulti = g_Weapon[index].data_multienable;
        float multiprice = g_Weapon[index].data_multiprice;
        int totalprice;

        if(ismulti)
        {
            if(purchasecount > 0)
            {
                float orifloat = float(originalprice);
                totalprice = RoundToNearest(orifloat * multiprice);
            }
            else
            {
                totalprice = originalprice;
            }
        }
        else
        {
            totalprice = originalprice;
        }

        if(totalprice > cash)
        {
            if(zombiereloaded && g_bZombieSpawned)
            {
                if(!IsClientByPassPrice(client, index))
                {   
                    PrintToChat(client, " \x04%s\x01 You don't have enough cash to purchase this item.", sTag);
                    return;
                }
            }
            else
            {
                if(!IsClientByPassPrice(client, index))
                {   
                    PrintToChat(client, " \x04%s\x01 You don't have enough cash to purchase this item.", sTag);
                    return;
                }
            }
        }

        if(StrEqual(entity, "weapon_kevlar"))
        {
            if(GetEntProp(client, Prop_Send, "m_ArmorValue") >= 100)
            {
                PrintToChat(client, " \x04%s\x01 You already have Kevlar!", sTag);
                return;
            }

            if(!loadout)
            {
                if(!ismulti)
                {
                    if(purchasemax == 0 || IsClientByPassCount(client, index))
                    {
                        PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Select weapon from menu or use command to purchase again.", sTag, g_Weapon[index].data_name);
                    }
                    else
                    {
                        PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. You can only purchase this item again \x06%i\x01 times.", sTag, g_Weapon[index].data_name, purchaseleft - 1);
                    }
                }
                else
                {
                    if(purchasemax == 0)
                    {
                        if(IsClientByPassCount(client, index))
                        {
                            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Select weapon from menu or use command to purchase again.", sTag, g_Weapon[index].data_name);
                        }
                        else
                        {                      
                            if(purchasecount > 0)
                            {
                                PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01 for \x06%i$\x01 because you re-purchase this weapon again.", sTag, g_Weapon[index].data_name, totalprice);
                            }
                            else
                            {
                                PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Next time it will cost \x06\"x%0.2f\" \x01from original price to purchase.", sTag, g_Weapon[index].data_name, multiprice);
                            }
                        }
                    }
                    else
                    {
                        if(IsClientByPassCount(client, index))
                        {
                            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Select weapon from menu or use command to purchase again.", sTag, g_Weapon[index].data_name);
                        }
                        else
                        {
                            if(purchasecount > 0)
                            {
                                PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01 for \x06%i$\x01 because you re-purchase this weapon again. And you only can purchase this item again \x06%i\x01 times.", sTag, g_Weapon[index].data_name, totalprice, purchaseleft - 1);
                            }
                            else
                            {
                                PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Next time it will cost \x06\"x%0.2f\"\x01 from original price to purchase. And you only can purchase this item again \x06%i\x01 times.", sTag, g_Weapon[index].data_name, multiprice, purchaseleft - 1);
                            }
                        }
                    }
                }
            }

            if(!smrpg_armor)
            {
                SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
            }
            else
            {
                int armorvalue = SMRPG_Armor_GetClientMaxArmor(client);
                SetEntProp(client, Prop_Send, "m_ArmorValue", armorvalue);
            }

            SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);

            if(!IsClientByPassPrice(client, index) && !free)
            {
                if(zombiereloaded && g_bZombieSpawned)
                    SetEntProp(client, Prop_Send, "m_iAccount", cash - totalprice);

                else
                    SetEntProp(client, Prop_Send, "m_iAccount", cash - totalprice);

            }
            if(!IsClientByPassCount(client, index))
                SetPurchaseCount(client, g_Weapon[index].data_name, 1, true);

            return;
        }

        int weapon = GetPlayerWeaponSlot(client, g_Weapon[index].data_slot);
        int slot = g_Weapon[index].data_slot;

        if(slot == SLOT_PRIMARY || slot == SLOT_SECONDARY)
        {
            if(weapon != -1)
            {
                CS_DropWeapon(client, weapon, true, false);
            }
        }

        if(!loadout)
        {
            if(!ismulti)
            {
                if(purchasemax == 0 || IsClientByPassCount(client, index))
                {
                    PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Select weapon from menu or use command to purchase again.", sTag, g_Weapon[index].data_name);
                }
                else
                {
                    PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. You can only purchase this item again \x06%i\x01 times.", sTag, g_Weapon[index].data_name, purchaseleft - 1);
                }
            }
            else
            {
                if(purchasemax == 0)
                {
                    if(IsClientByPassCount(client, index))
                    {
                        PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Select weapon from menu or use command to purchase again.", sTag, g_Weapon[index].data_name);
                    }
                    else
                    {                      
                        if(purchasecount > 0)
                        {
                            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01 for \x06%i$\x01 because you re-purchase this weapon again.", sTag, g_Weapon[index].data_name, totalprice);
                        }
                        else
                        {
                            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Next time it will cost \x06\"x%0.2f\" \x01from original price to purchase.", sTag, g_Weapon[index].data_name, multiprice);
                        }
                    }
                }
                else
                {
                    if(IsClientByPassCount(client, index))
                    {
                        PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Select weapon from menu or use command to purchase again.", sTag, g_Weapon[index].data_name);
                    }
                    else
                    {
                        if(purchasecount > 0)
                        {
                            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01 for \x06%i$\x01 because you re-purchase this weapon again. And you only can purchase this item again \x06%i\x01 times.", sTag, g_Weapon[index].data_name, totalprice, purchaseleft - 1);
                        }
                        else
                        {
                            PrintToChat(client, " \x04%s\x01 You have purchased \x04\"%s\"\x01. Next time it will cost \x06\"x%0.2f\"\x01 from original price to purchase. And you only can purchase this item again \x06%i\x01 times.", sTag, g_Weapon[index].data_name, multiprice, purchaseleft - 1);
                        }
                    }
                }
            }
        }

        if(!IsClientByPassPrice(client, index) && !free)
        {
            if(zombiereloaded && g_bZombieSpawned)
                SetEntProp(client, Prop_Send, "m_iAccount", cash - totalprice);

            else
                SetEntProp(client, Prop_Send, "m_iAccount", cash - totalprice);
        }

        if(StrEqual(g_Weapon[index].data_entity, "weapon_hkp2000", false))
        {
            GivePlayerItem2(client, g_Weapon[index].data_entity);
        }
        else
        {
            GivePlayerItem(client, g_Weapon[index].data_entity);
        }
        
        if(!IsClientByPassCount(client, index))
            if(!free)
                SetPurchaseCount(client, g_Weapon[index].data_name, 1, true);

        if(cooldown > 0)
        {
            if(zombiereloaded && g_bZombieSpawned)
            {
                if(g_iCooldownMode == 2)
                    SetPurchaseCooldown(client, g_Weapon[index].data_name, thetime + cooldown);

                else
                    SetPurchaseGlobalCooldown(client, thetime + cooldown);
            }
            else
            {
                if(g_iCooldownMode == 2)
                    SetPurchaseCooldown(client, g_Weapon[index].data_name, thetime + cooldown);

                else
                    SetPurchaseGlobalCooldown(client, thetime + cooldown);
            }
        }

        return;
    }
    return;
}

public void ClientLoadoutMenu(int client)
{
    Menu menu = new Menu(ClientLoadoutMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Loadout Menu", sTag);
    menu.AddItem("save", "Save Current Loadout");
    menu.AddItem("edit", "Edit Your Loadout");
    menu.AddItem("buy", "Buy Saved Loadout");
    menu.AddItem("Auto-Rebuy", "Auto-Rebuy");

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ClientLoadoutMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DisplayItem:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            if(StrEqual(info, "Auto-Rebuy", false))
            {
                char display[64];
                if(!g_bAutoRebuy[param1])
                {
                    Format(display, sizeof(display), "%s: No", info);
                    RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: Yes", info);
                    RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            if(StrEqual(info, "save", false))
            {
                for(int i = 0; i < WEAPON_SLOT_MAX; i++)
                {
                    SaveCurrentLoadout(param1, i);
                }
                ClientLoadoutMenu(param1);
            }
            else if(StrEqual(info, "buy", false))
            {
                BuySavedLoadout(param1, false);
            }
            else if(StrEqual(info, "edit", false))
            {
                EditLoadout(param1);
            }
            else if(StrEqual(info, "Auto-Rebuy", false))
            {
                g_bAutoRebuy[param1] = !g_bAutoRebuy[param1];
                SaveRebuyCookie(param1);

                if(g_bAutoRebuy[param1])
                {
                    PrintToChat(param1, " \x04%s\x01 You have \x06enabled\x01 Auto-Rebuy, Next spawn you will purchase loadout weapon automatically.", sTag);
                }
                else
                {
                    PrintToChat(param1, " \x04%s\x01 You have \x06disabled\x01 Auto-Rebuy, Next spawn you will purchase loadout weapon automatically.", sTag);
                }
                ClientLoadoutMenu(param1);
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

void SaveCurrentLoadout(int client, int slot)
{
    if(slot == SLOT_KNIFE || slot == SLOT_KEVLAR)
    {
        return;
    }

    char weaponentity[64];
    int weapon = GetPlayerWeaponSlot(client, slot);

    if(weapon == -1)
    {
        return;
    }

    GetEntityClassname(weapon, weaponentity, sizeof(weaponentity));

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weaponentity, g_Weapon[i].data_entity, false))
        {
            char weaponname[64];
            Format(weaponname, sizeof(weaponname), "%s", g_Weapon[i].data_name);
            SaveLoadoutCookie(client, slot, weaponname);
            return;
        }
    }
}

void BuySavedLoadout(int client, bool spawn)
{
    for(int i = 0; i < WEAPON_SLOT_MAX; i++)
    {
        char weaponentity[64];
        int weapon = GetPlayerWeaponSlot(client, i);

        if(weapon != -1)
        {
            GetEntityClassname(weapon, weaponentity, sizeof(weaponentity));
            //PrintToChat(client, " \x04[Debug]\x01 Found %s", weaponentity);
        }

        char weaponname[64];
        GetClientCookie(client, g_hWeaponCookies[i], weaponname, sizeof(weaponname));

        if(weaponname[0] == '\0')
        {
            continue;
        }

        for(int x = 0; x < g_iTotal; x++)
        {
            if(StrEqual(weaponname, g_Weapon[x].data_name, false))
            {
                if(spawn)
                {
                    if(!StrEqual(weaponentity, g_Weapon[x].data_entity))
                    {
                        PurchaseWeapon(client, g_Weapon[x].data_entity, true, g_bFreeOnSpawn);
                    }
                }
                else
                {
                    PurchaseWeapon(client, g_Weapon[x].data_entity, true);
                }
            }
        }
    }
}

void EditLoadout(int client)
{
    Menu menu = new Menu(EditLoadoutHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Edit Loadout Option \nChoose the option to changed it.", sTag);
    menu.AddItem("Primary", "Primary");
    menu.AddItem("Secondary", "Secondary");
    menu.AddItem("Grenade", "Grenade");

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int EditLoadoutHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DisplayItem:
        {
            char info[64];
            char weaponname[64];
            char display[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "Primary", false))
            {
                GetClientCookie(param1, g_hWeaponCookies[SLOT_PRIMARY], weaponname, sizeof(weaponname));
                if(weaponname[0] == '\0')
                {
                    Format(display, sizeof(display), "%s: None", info);
                    RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: %s", info, weaponname);
                    RedrawMenuItem(display);
                }
            }
            else if(StrEqual(info, "Secondary", false))
            {
                GetClientCookie(param1, g_hWeaponCookies[SLOT_SECONDARY], weaponname, sizeof(weaponname));
                if(weaponname[0] == '\0')
                {
                    Format(display, sizeof(display), "%s: None", info);
                    RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: %s", info, weaponname);
                    RedrawMenuItem(display);
                }
            }
            if(StrEqual(info, "Grenade", false))
            {
                GetClientCookie(param1, g_hWeaponCookies[SLOT_GRENADE], weaponname, sizeof(weaponname));
                if(weaponname[0] == '\0')
                {
                    Format(display, sizeof(display), "%s: None", info);
                    RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: %s", info, weaponname);
                    RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "Primary", false))
            {
                ChooseLoadout(param1, SLOT_PRIMARY);
            }
            else if(StrEqual(info, "Secondary", false))
            {
                ChooseLoadout(param1, SLOT_SECONDARY);
            }
            else if(StrEqual(info, "Grenade", false))
            {
                ChooseLoadout(param1, SLOT_GRENADE);
            }
        }
        case MenuAction_Cancel:
        {
            ClientLoadoutMenu(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

int currentslot;

public void ChooseLoadout(int client, int slot)
{
    char weapontype[64];

    if(slot == SLOT_PRIMARY)
    {
        Format(weapontype, sizeof(weapontype), "Primary");
    }
    else if(slot == SLOT_SECONDARY)
    {
        Format(weapontype, sizeof(weapontype), "Secondary");
    }
    else if(slot == SLOT_GRENADE)
    {
        Format(weapontype, sizeof(weapontype), "Grenade");
    }

    currentslot = slot;

    Menu menu = new Menu(ChooseLoadoutHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Edit %s Loadout", sTag, weapontype);
    menu.AddItem("none", "None");

    for(int i = 0; i < g_iTotal; i++)
    {
        if(g_Weapon[i].data_slot == slot)
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

public int ChooseLoadoutHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DrawItem:
        {
            char info[64];
            char cookie[64];
            menu.GetItem(param2, info, sizeof(info));
            GetClientCookie(param1, g_hWeaponCookies[currentslot], cookie, sizeof(cookie));
            if(StrEqual(info, "none", false))
            {
                if(cookie[0] == '\0')
                {
                    return ITEMDRAW_DISABLED;
                }
            }
            else
            {
                if(StrEqual(cookie, info, false))
                {
                    return ITEMDRAW_DISABLED;
                }
            }
        }
        case MenuAction_DisplayItem:
        {
            char info[64];
            char cookie[64];
            char display[64];
            menu.GetItem(param2, info, sizeof(info));
            GetClientCookie(param1, g_hWeaponCookies[currentslot], cookie, sizeof(cookie));
            if(StrEqual(info, "none", false))
            {
                if(cookie[0] == '\0')
                {
                    Format(display, sizeof(display), "%s (Selected)", info);
                    return RedrawMenuItem(display);
                }
            }
            else
            {
                if(StrEqual(cookie, info, false))
                {
                    Format(display, sizeof(display), "%s (Selected)", info);
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "none", false))
            {
                SaveLoadoutCookie(param1, currentslot, "");
                EditLoadout(param1);
            }
            else
            {
                SaveLoadoutCookie(param1, currentslot, info);
                EditLoadout(param1);
            }
        }
        case MenuAction_Cancel:
        {
            EditLoadout(param1);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public void ServerSettingMenu(int client)
{
    Menu menu = new Menu(ServerSettingMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("%s Setting Menu", sTag);
    menu.AddItem("BuyZone Only", "BuyZone Only");
    menu.AddItem("restrict", "Restrict Weapon");
    menu.AddItem("Allow Loadout", "Allow Loadout");

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ServerSettingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_DisplayItem:
        {
            char info[64];
            char display[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "Allow Loadout"))
            {
                if(g_bAllowLoadout)
                {
                    Format(display, sizeof(display), "%s: Yes", info);
                    return RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: No", info);
                    return RedrawMenuItem(display);
                }
            }
            else if(StrEqual(info, "BuyZone Only"))
            {
                if(!g_bBuyZoneOnly)
                {
                    Format(display, sizeof(display), "%s: No", info);
                    return RedrawMenuItem(display);
                }
                else
                {
                    Format(display, sizeof(display), "%s: Yes", info);
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "BuyZone Only"))
            {
                g_bBuyZoneOnly = !g_bBuyZoneOnly;
                if(g_bBuyZoneOnly == true)
                {
                    PrintToChatAll(" \x04%s\x01 Purchase weapon in Buyzone-only has been \x07enabled\x01.", sTag);
                }
                else
                {
                    PrintToChatAll(" \x04%s\x01 Purchase weapon in Buyzone-only has been \x06disabled\x01.", sTag);
                }
                ServerSettingMenu(param1);
            }
            else if(StrEqual(info, "Allow Loadout"))
            {
                g_bAllowLoadout = !g_bAllowLoadout;
                if(g_bAllowLoadout == true)
                {
                    PrintToChatAll(" \x04%s\x01 Weapon Loadout has been \x07enabled\x01.", sTag);
                }
                else
                {
                    PrintToChatAll(" \x04%s\x01 Weapon Loadout has been \x06disabled\x01.", sTag);
                }
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
                else
                {
                    RestrictGrenadeMenu(param1);
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

int FindWeaponIndexByName(const char[] weaponname)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weaponname, g_Weapon[i].data_name))
        {
            return i;
        }
    }
    return -1;
}

// More accurate
int FindWeaponIndexByEntityName(const char[] weaponentity)
{
    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weaponentity, g_Weapon[i].data_entity))
        {
            return i;
        }
    }
    return -1;
}

void SetPurchaseGlobalCooldown(int client, float time)
{
    g_fPurchaseGlobalCooldown[client] = time;
}

void SetPurchaseCooldown(int client, const char[] weaponname, float time)
{
    int index = FindWeaponIndexByName(weaponname);

    g_fPurchaseCooldown[index][client] = time;
}

float GetPurchaseCooldown(int client, const char[] weaponname)
{
    int index = FindWeaponIndexByName(weaponname);

    return g_fPurchaseCooldown[index][client];
}

void SetPurchaseCount(int client, const char[] weaponname, int value, bool add = false)
{
    int purchasemax;
    int index = FindWeaponIndexByName(weaponname);
    
    if(add)
    {
        purchasemax = GetPurchaseCount(client, weaponname);
    }
    g_iPurchaseCount[index][client] = purchasemax + value;
}

int GetPurchaseCount(int client, const char[] weaponname)
{
    int index = FindWeaponIndexByName(weaponname);

    return g_iPurchaseCount[index][client];
}

int GetWeaponPurchaseMax(const char[] weaponname)
{
    int maxpurchase;

    for(int i = 0; i < g_iTotal; i++)
    {
        if(StrEqual(weaponname, g_Weapon[i].data_name, false))
        {
            maxpurchase = g_Weapon[i].data_maxpurchase;
        }
    }
    return maxpurchase;
}

Action ForwardOnClientPurchase(int client, const char[] weaponentity, bool loadout, bool free)
{
    Call_StartForward(g_hOnClientPurchase);

    Call_PushCell(client);
    Call_PushString(weaponentity);
    Call_PushCell(loadout);
    Call_PushCell(free);

    Action result;
    Call_Finish(result);
    return result;
}

public int Native_SetClientByPass(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char weaponentity[64];
    GetNativeString(2, weaponentity, 64);

    ByPassType type = view_as<ByPassType>(GetNativeCell(3));
    bool allow = view_as<bool>(GetNativeCell(4));

    PreSetClientByPass(client, weaponentity, type, allow);
}

void PreSetClientByPass(int client, char[] weaponentity, ByPassType type, bool allow)
{
    int weaponindex = FindWeaponIndexByEntityName(weaponentity);

    switch (type)
    {
        case BYPASS_PRICE:
        {
            SetClientByPassPrice(client, weaponindex, allow);
        }
        case BYPASS_COUNT:
        {
            SetClientByPassCount(client, weaponindex, allow);
        }
        case BYPASS_RESTRICT:
        {
            SetClientByPassRestrict(client, weaponindex, allow);
        }
        case BYPASS_COOLDOWN:
        {
            SetClientByPassCooldown(client, weaponindex, allow);
        }
        case BYPASS_GLOBALCOOLDOWN:
        {
            SetClientByPassGlobalCooldown(client, allow);
        }
    }
    return;
}

public int Native_CheckClientByPass(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char weaponentity[64];
    GetNativeString(2, weaponentity, 64);

    ByPassType type = view_as<ByPassType>(GetNativeCell(3));

    return PreCheckClientByPass(client, weaponentity, type);
}

bool PreCheckClientByPass(int client, char[] weaponentity, ByPassType type)
{
    int weaponindex = FindWeaponIndexByEntityName(weaponentity);

    switch (type)
    {
        case BYPASS_PRICE:
        {
            return IsClientByPassPrice(client, weaponindex);
        }
        case BYPASS_COUNT:
        {
            return IsClientByPassCount(client, weaponindex);
        }
        case BYPASS_RESTRICT:
        {
            return IsClientByPassRestrict(client, weaponindex);
        }
        case BYPASS_COOLDOWN:
        {
            return IsClientByPassCooldown(client, weaponindex);
        }
        case BYPASS_GLOBALCOOLDOWN:
        {
            return IsClientByPassGlobalCooldown(client);
        }
    }
    return false;
}

public int Native_GetWeaponIndexByEntityName(Handle plugin, int numParams)
{
    char weaponentity[64];
    GetNativeString(1, weaponentity, 64);

    return FindWeaponIndexByEntityName(weaponentity);
}

stock bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC);
}

stock bool IsClientInBuyZone(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send,"m_bInBuyZone"));
}

stock void GivePlayerItem2(int client, const char[] weaponentity)
{
    int team = GetClientTeam(client);
    switch (team)
    {
        case 2:
        {
            SetEntProp(client, Prop_Send, "m_iTeamNum", 3);
        }
        case 3:
        {
            SetEntProp(client, Prop_Send, "m_iTeamNum", 2);
        }
    }
    GivePlayerItem(client, weaponentity);
    SetEntProp(client, Prop_Send, "m_iTeamNum", team);
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnoverride, bool &respawn)
{
    if(!g_bZombieSpawned)
        g_bZombieSpawned = true;
}

stock void SetClientByPassPrice(int client, int weaponindex, bool value)
{
    g_ByPass[weaponindex][client].ByPass_Price = value;
}

stock void SetClientByPassCount(int client, int weaponindex, bool value) 
{
    g_ByPass[weaponindex][client].ByPass_Count = value;
}

stock void SetClientByPassCooldown(int client, int weaponindex, bool value) 
{
    g_ByPass[weaponindex][client].ByPass_Cooldown = value;
}

stock void SetClientByPassRestrict(int client, int weaponindex, bool value) 
{
    g_ByPass[weaponindex][client].ByPass_Restrict = value;
}

stock void SetClientByPassGlobalCooldown(int client, bool value)
{
    g_bByPass_GlobalCooldown[client] = value;
}

stock bool IsClientByPassPrice(int client, int weaponindex)
{
    return g_ByPass[weaponindex][client].ByPass_Price;
}

stock bool IsClientByPassCount(int client, int weaponindex)
{
    return g_ByPass[weaponindex][client].ByPass_Count;
}

stock bool IsClientByPassCooldown(int client, int weaponindex)
{
    return g_ByPass[weaponindex][client].ByPass_Cooldown;
}

stock bool IsClientByPassRestrict(int client, int weaponindex)
{
    return g_ByPass[weaponindex][client].ByPass_Restrict;
}

stock bool IsClientByPassGlobalCooldown(int client)
{
    return g_bByPass_GlobalCooldown[client];
}