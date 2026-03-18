# EpochHelper

A quest helper addon for **Project Epoch** (WoW 3.3.5) with waypoint arrows, hints, and a community-maintained quest database.

## Features

- Rotating directional arrow pointing to quest objectives
- Live distance display (yards / km)
- Multi-step waypoints that auto-advance when you arrive
- Hints panel showing what to do at each step
- Draggable minimap button
- Auto-capture for unknown quests — builds your personal database as you play
- Community quest database maintained on GitHub

## Installation

1. Download the latest release from the [Releases](../../releases) page
2. Extract the `EpochHelper` folder into:
   ```
   World of Warcraft/Interface/AddOns/EpochHelper/
   ```
3. Log in and type `/eh` for help

## Updating the Quest Database

The community database lives in `data/QuestData.lua`. To get the latest data:

1. Download `data/QuestData.lua` from this repo
2. Replace `Interface/AddOns/EpochHelper/QuestData.lua` in your addon folder
3. `/reload` in-game

> **Tip:** Bookmark the raw file URL for quick access:
> `https://raw.githubusercontent.com/YOUR_USERNAME/EpochHelper/main/data/QuestData.lua`

## Contributing Quest Data

Found a quest that's missing? Two ways to contribute:

### Option A — In-game export (easiest)
1. Capture the quest in-game using `/eh import` or the auto-capture popup
2. Type `/eh export` — this prints a formatted Lua block to your chat
3. Copy it and [open a Quest Submission issue](../../issues/new?template=quest_submission.md)

### Option B — Manual
1. [Open a Quest Submission issue](../../issues/new?template=quest_submission.md)
2. Fill in the quest name, ID, zone, and coordinates

## Slash Commands

| Command | Description |
|---|---|
| `/eh` | Show all commands |
| `/eh show / hide` | Toggle arrow and hints panel |
| `/eh clear` | Clear current waypoint |
| `/eh import` | Click world map to set a waypoint |
| `/eh next / prev` | Move between quest steps |
| `/eh export` | Export current quest data for submission |
| `/eh capture done` | Save captured waypoint steps |
| `/eh capture on/off` | Toggle auto-capture prompt |
| `/eh list` | Show your captured quests |

## Quest Data Format

```lua
-- Single step
["Quest Title"] = {
    id   = 12345,           -- quest ID (/script print(GetQuestID()))
    zone = "Zone Name",
    x    = 0.0000,          -- map X (0.0 to 1.0)
    y    = 0.0000,          -- map Y (0.0 to 1.0)
    hint = "What to do.",
},

-- Multi-step
["Quest Title"] = {
    id   = 12345,
    zone = "Zone Name",
    steps = {
        { x=0.0000, y=0.0000, hint="Step 1." },
        { x=0.0000, y=0.0000, hint="Step 2." },
    },
},
```

## License

MIT — use freely, contributions welcome.
