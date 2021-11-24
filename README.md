# SM-GunMenu
Purchase weapon through command and menu.

## Feature
- Restrict Option.
- Allowing Custom more than 1 command for each gun.
- Toggleable Auto-Rebuy on Spawn.
- Hook the normal buy option in buyzone.
- Allowing Custom more than 1 Menu Command.

## Convar
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
sm_gunmenu_prefix "[ZBuy]"```

## Example Config
```
"weapons"
{
  "Glock" // Weapon Name
  {
    "entity"    "weapon_glock" // Entity
    "price"     "200" // Price
    "slot"		"1"  // Weapon Slot [0 = Primary, 1 = Secondary, 2 = Melee, 3 = Grenade, 4 = Kevlar]
    "command"	"sm_glock"  // Command for Purchase this specific weapon
    "restrict"	"0"     // Restrict This gun or not
  }
}
```


