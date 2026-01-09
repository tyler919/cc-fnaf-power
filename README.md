# FNAF Power System for CC:Tweaked

A Five Nights at Freddy's inspired power management system for Minecraft using CC:Tweaked computers.

## Features

- **Power Drain System**: Base power drains over time, doors and lights drain extra
- **Two Doors**: Left and right doors that can be closed when button is held
- **Three Lights**: Left hall, right hall, and room lights
- **Generator Room**: Refuel power by inserting coal into a chest (leaves you vulnerable!)
- **Central Monitor**: Shows power level, all device statuses
- **Remote Updates**: Press U on central to update all devices at once

## Installation

On any CC:Tweaked computer, run:

```
wget run https://raw.githubusercontent.com/tyler919/cc-fnaf-power/main/installer.lua
```

The installer will download all files and start the setup wizard.

## Setup

After installation, the computer will reboot and ask what type of device it is:

1. **Central Controller** - Main computer with monitor
2. **Left Door** - Door controller
3. **Right Door** - Door controller
4. **Left Hall Light** - Light controller
5. **Right Hall Light** - Light controller
6. **Room Light** - Light controller
7. **Generator** - Power refuel station

## Hardware Requirements

### Central Controller
- Computer
- Ender Modem (any side)
- Monitor (any side)

### Door/Light Controllers
- Computer
- Ender Modem (any side)
- Button input (redstone)
- Output to door/lamp (redstone)

### Generator
- Computer
- Ender Modem (any side)
- Chest (adjacent)
- Optional: Monitor

## Controls

### Central Controller
- **R** - Restart game (when power runs out)
- **U** - Update all devices
- **Q** - Quit

### Door/Light Controllers
- Hold button to close door / turn on light
- Only works if central has power

## Power Values

| Item | Power Drain/sec |
|------|-----------------|
| Base (idle) | 0.02 |
| Each closed door | +0.15 |
| Each light on | +0.10 |

| Fuel | Power Generated |
|------|-----------------|
| Coal/Charcoal | +10 |
| Coal Block | +90 |
| Lava Bucket | +50 |
| Blaze Rod | +15 |

## Updating

Run `update` on any device, or press U on the central controller to update all devices at once.

## Files

| File | Purpose |
|------|---------|
| central.lua | Main power controller |
| door.lua | Door controller |
| light.lua | Light controller |
| generator.lua | Generator room |
| startup.lua | Auto-start on boot |
| update.lua | Update system |
| installer.lua | First-time installer |
