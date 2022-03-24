#include <sourcemod>
#include <gun_menu>

public void OnPluginStart()
{
    RegAdminCmd("sm_enablebypass", Command_ByPass, ADMFLAG_GENERIC);
    RegAdminCmd("sm_disablebypass", Command_DisableByPass, ADMFLAG_GENERIC);
}

public Action Command_ByPass(int client, int args)
{
    GunMenu_SetClientByPass(client, "weapon_awp", BYPASS_RESTRICT, true);
    GunMenu_SetClientByPass(client, "weapon_m249", BYPASS_PRICE, true);
    GunMenu_SetClientByPass(client, "weapon_hegrenade", BYPASS_COUNT, true);
    GunMenu_SetClientByPass(client, "weapon_hegrenade", BYPASS_PRICE, true);
    GunMenu_SetClientByPass(client, "weapon_nova", BYPASS_COOLDOWN, true);
    return Plugin_Handled;
}

public Action Command_DisableByPass(int client, int args)
{
    GunMenu_SetClientByPass(client, "weapon_awp", BYPASS_RESTRICT, false);
    GunMenu_SetClientByPass(client, "weapon_m249", BYPASS_PRICE, false);
    GunMenu_SetClientByPass(client, "weapon_hegrenade", BYPASS_COUNT, false);
    GunMenu_SetClientByPass(client, "weapon_hegrenade", BYPASS_PRICE, false);
    GunMenu_SetClientByPass(client, "weapon_nova", BYPASS_COOLDOWN, false);
    return Plugin_Handled;
}