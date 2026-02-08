# EasyMath

EasyMath is an open-source Roblox utility library built to provide reusable systems for developers.  
It is designed to be simple, modular, and easy to integrate into any game.

---

## Installation

1. Go to the **Releases** section of the repository.  
2. Download the latest **EasyMath Roblox model**.  
3. Insert the model into your Roblox place.  
4. Move the **EasyMath** folder into `ReplicatedStorage`.

Once in `ReplicatedStorage`, the library is ready to be required.

---

## Features

### Pathfinding
- Supports **Linear** (Roblox pathfinding) and **Advanced** (smoothed movement) modes  
- Can target **players, models, parts, or positions**  
- Includes optional **damage system** and **animation support**  
- Works with **Humanoids and parts**

---

### Tween
EasyMath.Tween is a **math‑driven procedural animation system** designed to work on any object type.

#### Procedural Effects
- **Rotate**  
  - `Rotate(obj, angle, speed)`  
  - `angle = -1` → loop forever  
  - `speed = 1` → 15° per second  
  - Can run simultaneously with Hover and other effects

- **Hover**  
  - `Hover(obj, startPos, endPos, amount, speed)`  
  - Smooth up/down motion  
  - `amount = -1` → infinite loop  
  - Preserves rotation and works alongside Rotate

#### TweenService Helpers
- **Move** — CFrame offset  
- **Scale** — Size multiplier  
- **FadeIn / FadeOut**  
  - Automatically detects object type:  
    - Parts  
    - Beams  
    - ParticleEmitters  
    - Lights  
    - UI objects (ImageLabel, TextLabel, etc.)

#### Effect Control
- `Stop(obj)` — stops all procedural + tween effects on that object

---

## Open Source

EasyMath is fully **open source**:  
- Free to use in personal or commercial projects  
- You can modify or extend the code  
- Contributions and improvements are welcome  

---

## Usage Example (pathfinding)
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
## Usage Example (tween)
Require the library from `ReplicatedStorage`:

```lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local EasyMath = require(ReplicatedStorage:WaitForChild("EasyMath"):WaitForChild("EasyMath"))
local Tween = EasyMath.Tween

local tweenPart = workspace:WaitForChild("TweenPart")

player.Chatted:Connect(function(message)
	message = message:lower()
	if message == "/start tween" then
		local part = tweenPart
		local startPos = part.Position + Vector3.new(0, 1, 0)
		local endPos = part.Position + Vector3.new(0, 3, 0)

		Tween:Hover(part, startPos, endPos, -1, 1)
		Tween:Rotate(part, -1, 4)
		task.delay(1, function()
			Tween:CameraShake(cam, {
				magnitude = 3,
				roughness = 2,
				rotation = 8,
				fadeIn = 0.2,
				fadeOut = 0.5,
				duration = 4
			})
		end)
		task.delay(2, function()
			Tween:Move(part, Vector3.new(5, 0, 0), 1)
			Tween:Scale(part, 1.5, 1)
		end)

		task.delay(3.5, function()
			Tween:FadeOutTree(part, 2)
		end)
		task.delay(6, function()
			Tween:FadeIn(part, 2)
		end)

		task.delay(7, function()
			Tween:Rotate(cam, -1, 0.2)
		end)
		task.delay(8, function()
			Tween:Move(cam, Vector3.new(0, 0, -5), 1)
		end)
	end
end)


```

