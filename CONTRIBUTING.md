# Contributing to EpochHelper

## Submitting Quest Data

The easiest way to contribute is from inside the game:

1. Accept the quest you want to submit
2. Walk to the objective location
3. Type `/eh import` and click the world map at the objective
4. Type `/eh capture done`
5. Type `/eh export` and copy the output
6. [Open a Quest Submission issue](../../issues/new?template=quest_submission.md) and paste it

## Updating QuestData.lua Directly

If you're comfortable with Lua:

1. Fork this repository
2. Edit `data/QuestData.lua` and add your entry using the format in the README
3. Open a Pull Request with the title `[DATA] Quest Name`

## Getting Quest IDs

While the quest is in your log, select it and type:
```
/script print(GetQuestID())
```

## Getting Coordinates

Open your world map to the correct zone, stand at the objective, and type:
```
/script local x,y = GetPlayerMapPosition("player") print(x,y)
```
