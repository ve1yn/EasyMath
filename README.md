# EasyMath

EasyMath is an open-source Roblox utility library built to provide reusable systems for developers.  
It is designed to be simple, modular, and easy to integrate into any game.

---

## Installation

1. Go to the **Releases** section of the repository.  
2. Download the latest **EasyMath Roblox model**.  
3. Insert the model into your Roblox place.  
4. Move the **EasyMath** folder into Replicated Storage


Once in `ReplicatedStorage`, the library is ready to be required.

---

## Features

### Pathfinding
- Supports **Linear** (Roblox pathfinding) and **Advanced** (smoothed movement) modes  
- Can target **players, models, parts, or positions**  
- Includes optional **damage system** and **animation support**  
- Works with **Humanoids and parts**

---

## Open Source

EasyMath is fully **open source**:  
- Free to use in personal or commercial projects  
- You can modify or extend the code  
- Contributions and improvements are welcome  

---

## Usage Example

Require the library from `ReplicatedStorage`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EasyMath = require(ReplicatedStorage:WaitForChild("EasyMath"):WaitForChild("EasyMath"))

local NPC = workspace:WaitForChild("NPC")

local controller = EasyMath.Pathfinding:Start(
	"Advanced",
	nil,
	{
		WalkSpeed = 12,
		Jump = true,
		Damage = 20,
		Range = 80,
		RepathDistance = 3,
	},
	NPC,
	"ClosestPlayer"
)
```
