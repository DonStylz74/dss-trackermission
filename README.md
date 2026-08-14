![Awesome ReadME](https://imgur.com/bYDobJQ.png)



# DSS Tracker Missions

A heavily expanded and reworked ESX vehicle-theft mission resource for FiveM, based on the original By Kamkus

**dss-trackermission** keeps that concept but adds a much larger configurable mission system, improved interactions, multiple mission outcomes, enhanced GPS gameplay, seller NPC handoffs and difficulty-based payments.

# **Main Features**

- ESX Legacy support.
- `ox_lib` menus, notifications and progress handling.
- `ox_inventory` item support.
- `ox_target` vehicle/GPS interactions.
- Mission contact NPC with configurable spawn locations.
- Built-in NPC shop for mission equipment.
- Large configurable stolen-vehicle model pool.
- Configurable search areas with individual vehicle spawn locations.
- Live police GPS tracking while the stolen vehicle tracker is active.
- Player tracker-status blip while the vehicle engine is running and the tracker is still fitted.
- Interactive GPS tracker removal from the front/bonnet of the vehicle.
- Optional MGC Frequency Jam minigame or standard timed tracker removal.
- Choice to **Sell** or **Chop** the stolen vehicle after removing the tracker.
- Multiple random seller and chop-shop locations.
- Seller NPC cash handoff animation and cash prop.
- Seller can enter the purchased vehicle and drive away, or remain at the location until the player leaves.
- Difficulty bonus payment system based on search-area size and individual vehicle location.
- Minimum police requirement, mission cooldown and AFK protection.
- Server-side mission/payout validation and controlled mission-entity cleanup.

| Feature | Original | dss-trackermission |
| --- | --- | --- |
| Basic steal-and-deliver mission | Yes | Yes, expanded |
| Random mission NPC position | Yes | Expanded configurable NPC locations |
| Search area | Automatically sized around selected vehicle | Configurable `searchRadius` per area |
| Vehicle spawn locations | Basic `vec4` list | Individual spawn entries with bonus options |
| Vehicle selection | Small configurable list | Expanded configurable vehicle pool |
| Police GPS tracking | Yes | Retained and integrated with updated tracker system |
| Player tracker warning | No | Yes shows while engine is running and tracker remains fitted |
| Tracker removal | Basic timed interaction | Bonnet/front positioning, hood animation and configurable minigame |
| Tracker removal item | Basic required item | Dedicated `Item` using `ox_inventory` |
| Equipment shop | No | Mission NPC shop with configurable items/prices/payment type |
| Mission start fee/item reward | Original mission handling | Mission acceptance separated from shop purchases |
| Mission outcome | Vehicle return | Player chooses **Sell** or **Chop** |
| Seller NPC | No dedicated buyer handoff | Configurable buyer NPC with animated cash exchange |
| Buyer vehicle behaviour | No | Buyer can drive vehicle away or remain until player leaves |
| Chop locations | No separate route system | Multiple configurable chop locations and route blips |
| Difficulty payments | No | Search-radius + individual-location bonuses |
| Payment validation | Basic payout | Server-side payout calculation and delivery validation |
| Target system | `qtarget` | Uses `ox_target` for new GPS interactions while retaining required existing target support |

[📱 Visit this Project](https://github.com/DonStylz74)



## Mission Flow

 1. Talk to the vehicle-theft contact.
 2. Purchase a GPS Tracker Removal Tool or other configured equipment if required.
 3. Start a mission and travel to the marked search area.
 4. Locate the randomly selected vehicle inside the configured radius.
 5. Steal/start the vehicle.
 6. While the tracker is active:
    - Police receive the vehicle GPS position.
    - The thief sees the tracker-signal blip while the vehicle engine is running.
 7. Move to the front of the vehicle and remove the GPS tracker.
 8. Complete the configured tracker-removal minigame/action.
 9. Choose to **Sell** or **Chop** the vehicle.
10. Follow the assigned route and complete the selected mission outcome.

## Difficulty Bonus System

Sale payments can include two additional bonuses on top of the normal configured vehicle payment.

### Search Radius Bonus

```lua
{maxRadius = 100.0, bonus = 0 },
{ maxRadius = 150.0, bonus = 50 },
{ maxRadius = 200.0, bonus = 100 },
{ maxRadius = 300.0, bonus = 200 },
{ maxRadius = 400.0, bonus = 300 },
{ maxRadiusBonus = 500 }
```

### Individual Location Bonus

```lua
     { coords = vec4(1358.3177, -541.9930, 73.4445, 154.3497), bonus = true },
     { coords = vec4(1291.3696, -581.4116, 71.4121, 343.3168), bonus = false },
     { coords = vec4(1237.0114, -586.1911, 68.9535, 270.4646), bonus = true },
```

## GPS Tracker Removal

Two modes are available:

- `mgc` - uses the MGC Frequency Jam minigame. (optional)
- `none` - uses the configured timed progress action instead.

```lua
Config.GPSRemoval = {
    minigame = 'mgc', -- 'mgc' or 'none'
}
```

The GPS tracker blip only appears while stolen vehicle engine is running and the GPS tracker has not been removed. Once removed the tracker blip is permanently disabled for that mission.

## Seller System

- drop-off locations containing both a vehicle delivery point and buyer NPC location
- animated cash handoff.
- Driveaway or Leave area endings.

## NPC Shop

- The mission contact includes a configurable equipment shop.
- Add multiple purchaseable equipment items.
- Payment types (money/bank/black_money)
- Additional items such as lockpicks or hotwire equipment from other resources can be added.

## 🎨 Screenshots

- Tracker Removal ![Gauge Warning Diagram](https://imgur.com/8FTI9Ve.png)
- Mission Choices ![mission choice](https://imgur.com/rWddwEN.png)
- Final Sales ![mission choice](https://imgur.com/7Xpwfe0.png)

### Dependencies

DSS Trackermission requires:

- `es_extended`

- `ox_lib`

- `ox_inventory`

- `ox_target`

- `qtarget`

- `mgc` - (optional) -- only required when `Config.GPSRemoval.minigame = 'mgc'`



### Installation

1. Place `dss-trackermission` in your resources folder.
2. Add the supplied `traker_remtool` item to your `ox_inventory` items.
3. Add `traker_remtool.png` to your inventory images if required by your setup.
4. Ensure all required dependencies start before this resource.
5. Configure NPC locations, vehicles, search areas, payouts, seller locations and chop locations in `shared.lua`.
6. Add to `server.cfg`: `ensure dss-trackermission`

### OX Item

```lua
['traker_remtool'] = {
    label = 'GPS Disabler',
    weight = 100,
	  stack = false,
    description = 'GPS Tracker disabling module',
    client = {
        image = "traker_remtool.png",
    }
},
```



## Authors

- **Original author:** Kamkus
- **Modified by Don Stylz** - [Don_Stylz74](https://github.com/DonStylz74)



## License

Review the LICENSE file included with the resource for the licensing terms that apply to this version.

Because DSS Trackermission is derived from an existing project, retain the appropriate original copyright, licence notices and attribution where required.



## Acknowledgments

This resource is a heavily modified version of the original trackerMission and retains credit to the original author for the base mission concept and code

- [**Kamkus** - Original Code](https://github.com/Kamkus/trackerMission)
