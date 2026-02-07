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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EasyMath = require(ReplicatedStorage:WaitForChild("EasyMath"):WaitForChild("EasyMath"))
local part = workspace.Part

EasyMath.Tween:Hover(
    part,
    part.Position + Vector3.new(0, 1, 0),
    part.Position + Vector3.new(0, 3, 0),
    -1,
    1
)

EasyMath.Tween:Rotate(part, -1, 0.1)

task.delay(4, function()
   EasyMath.Tween:FadeOut(part, 2)
end)

```

