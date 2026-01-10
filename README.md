# FNAF Power System for CC:Tweaked

A Five Nights at Freddy's inspired power management system for Minecraft using CC:Tweaked computers and Powah mod integration.

## Features

- **Power Drain System**: Base power drains over time, doors and lights drain extra
- **Two Doors**: Left and right doors (hold button to close)
- **Three Lights**: Left hall, right hall, and room lights
- **Powah Battery Generator**: Recharge power using Hardened Batteries
- **Touch Screen Interface**: Tap monitor to select options
- **Breaker Warning System**: Flashing warning - tap to reset or generator breaks!
- **Admin Reset**: Press R on central to reset everything
- **Remote Updates**: Press U on central to update all devices

## Installation

On any CC:Tweaked computer, run:

```
wget run https://raw.githubusercontent.com/tyler919/cc-fnaf-power/main/installer.lua
```

The installer will download all files and start the setup wizard.

## Hardware Setup

### Central Controller
- Computer
- Ender Modem (any side)
- Monitor (any side)

### Door Controller
- Computer
- Ender Modem (any side)
- Button input (redstone)
- Output to door/piston (redstone)

### Light Controller
- Computer
- Ender Modem (any side)
- Button input (redstone)
- Output to lamp (redstone)

### Generator Room
- Computer
- Ender Modem (any side)
- Monitor (for touch interface)
- Oak Drawer (back side) - for battery input
- Hopper (front side redstone) - computer locks/unlocks it
- Powah Energy Cell (below hopper)

## Generator System

### How It Works
1. Charge a **Hardened Battery** (10M FE) elsewhere
2. Go to generator room (you're vulnerable!)
3. Insert battery into Oak Drawer
4. Monitor shows startup animation
5. **Tap** to select power level (10% - 100%)
6. Wait while charging (higher % = longer wait)
7. Power sent to central controller

### Power Levels
| Selection | Power Added | Wait Time (10K/tick) |
|-----------|-------------|---------------------|
| 10% | +10 | 5 sec |
| 20% | +20 | 10 sec |
| 50% | +50 | 25 sec |
| 100% | Full restore | 50 sec |

### Discharge Rate Config
Edit `generator.lua` to match your Energy Cell:
```lua
local DISCHARGE_RATE = "10K"  -- "1K", "4K", or "10K"
```

| Rate | Time for 100% |
|------|---------------|
| 1K/tick | ~8 minutes |
| 4K/tick | ~2 minutes |
| 10K/tick | 50 seconds |

## Breaker Warning System

- **Flashing red/yellow icon** appears in top-right corner
- Shows countdown timer (2.5 minutes default)
- **Tap the warning** to reset it
- If ignored: **50% chance** generator breaks permanently
- Broken generator = no more recharging!

### Config Options
```lua
BREAKER_WARNING_TIME = 150   -- Seconds to reset (2.5 min)
BREAKER_FIRST_WARNING = 60   -- First warning after 60 sec
BREAKER_BREAK_CHANCE = 0.5   -- 50% chance to break
```

## Controls

### Central Controller
| Key | Action |
|-----|--------|
| R | Reset game + fix broken generator |
| U | Update all devices |
| Q | Quit |

### Generator Monitor
- **Tap** power level option to select
- **Tap** flashing warning to reset breaker

## Power Drain Rates

| Source | Drain/sec |
|--------|-----------|
| Base (idle) | 0.02 |
| Each closed door | +0.15 |
| Each light on | +0.10 |

**Example**: Both doors + all 3 lights = 0.02 + 0.30 + 0.30 = **0.62/sec**

## Files

| File | Purpose |
|------|---------|
| central.lua | Main power controller + monitor |
| door.lua | Door controller |
| light.lua | Light controller |
| generator.lua | Powah battery generator |
| startup.lua | Auto-start + setup wizard |
| update.lua | Update system |
| installer.lua | First-time installer |

## Updating

- Run `update` on any device manually
- Or press **U** on central to update all devices at once

## Troubleshooting

### "bad argument (table expected got nil)"
The drawer inventory returned nil. Make sure:
- Drawer is properly connected on the correct side
- Drawer is a valid inventory peripheral

### Generator shows "OFFLINE"
The breaker warning was ignored and generator broke. Press **R** on central controller to reset.

### Devices not connecting
- Make sure all devices have Ender Modems
- Check they're all using the same protocol (FNAF_POWER)

## Version History

- **1.2.2** - Admin reset (R key) to fix broken generator
- **1.2.1** - Fixed nil error when drawer is empty
- **1.2.0** - Breaker warning system
- **1.1.2** - Configurable discharge rates
- **1.1.1** - Touch input for monitor
- **1.1.0** - Powah battery generator system
- **1.0.0** - Initial release
