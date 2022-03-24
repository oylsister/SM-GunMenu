# [CS:GO/CS:S] SM-GunMenu
Purchase weapon through command and menu with customizable config for gun command. And completely replacement for ZMarket on Zombie:Reloaded

**\*I'm no longer working on 'Dev' branch. So check out Stable branch\***

## Feature
- Restrict Option Including Weapon Type.
- Allowing Player to save their own loadout.
- Allowing Customize more than 1 command for each gun.
- Toggleable Auto-Rebuy on Spawn.
- Hook the normal buy option in buyzone.
- Allowing Customize more than 1 command for menu.
- Maximum Purchase for each weapon.
- Multi Price on Second Purchase for each weapon.
- Cooldown purchase for each weapon or Global cooldown for all weapon (NEW)
- Toggleable for free purchase on spawn (NEW)
- By Pass mode for completely ignore Restriction, Purchase Count, Price and Purchase Cooldown (NEW)

## Convar
```
// Only allow to purchase on buyzone only
// -
// Default: "0.0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_gunmenu_buyzoneonly "0.0"

// Specific command for open menu command
// -
// Default: "sm_gun"
sm_gunmenu_command "sm_gun,sm_guns,sm_zmarket,sm_zbuy"

// Also apply purchase method to player purchase with default buy menu from buyzone
// -
// Default: "1.0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_gunmenu_hookbuyzone "1.0"

// Prefix for plugin
// -
// Default: "[ZBuy]"
sm_gunmenu_prefix "[ZBuy]"

// Specify the path of config file for gun menu
// - 
// Default: "configs/gun_menu.txt"
sm_gunmenu_configpath "configs/gun_menu.txt"

// 0 = Disabled | 1 = Global Cooldown | 2 = Inviduals Cooldown
// -
// Default: "1.0"
// Minimum: "0.000000"
// Maximum: "2.000000"
sm_gunmenu_cooldown_mode "1.0"

// Free purchase on spawn
// -
// Default: "1.0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_gunmenu_free_onspawn "1.0"

// Length of Global Cooldown in seconds
// -
// Default: "5.0"
// Minimum: "0.000000"
sm_gunmenu_global_cooldown "5.0"
```

## Example Config
```
"weapons"
{
  "Glock" // Weapon Name
  {
    "entity"    "weapon_glock" // Entity
    "type"      "Pistol" // Weapon Type
    "price"     "200" // Price
    "multiprice"	"1.0" // Put this greater than 1.0 will make second purchase cost more. (cost: Original_Price * MultiPrice) Set this below than 1.0, it will not work at all. 
    "slot"		"1"  // Weapon Slot [0 = Primary, 1 = Secondary, 2 = Melee, 3 = Grenade, 4 = Kevlar]
    "command"	"sm_glock"  // Command for Purchase this specific weapon
    "restrict"	"0"     // Restrict This gun or not
    "maxpurchase" "0"  // Maximum purchase in that round (0: No Maximum)
    "cooldown"	"0.0" // Cooldown after you purchase this weapon (0.0 = No cooldown)
  }
}
```


