local TweenService = game:GetService("TweenService")

local Tween = {}
Tween.__index = Tween

local active = {}
local procedural = {}

local function tween(obj, props, easing, time)
	if active[obj] then active[obj]:Cancel() end
	local t = TweenService:Create(obj, TweenInfo.new(time, easing), props)
	active[obj] = t
	t:Play()
	return t
end

function Tween:Rotate(obj, angle, speed)
	if not obj or not obj.CFrame then return end
	if procedural[obj] then procedural[obj].rotate = nil end

	speed = speed or 1

	if angle < 0 then
		procedural[obj] = procedural[obj] or {}
		procedural[obj].rotate = {speed = speed}
		task.spawn(function()
			while procedural[obj] and procedural[obj].rotate do
				local dt = task.wait()
				local degPerSec = procedural[obj].rotate.speed * 15
				obj.CFrame = obj.CFrame * CFrame.Angles(0, math.rad(degPerSec * dt), 0)
			end
		end)
		return
	end

	return tween(obj, {CFrame = obj.CFrame * CFrame.Angles(0, math.rad(angle), 0)}, Enum.EasingStyle.Linear, speed)
end


function Tween:Hover(obj, startVec, endVec, amount, speed)
	if not obj or not obj.CFrame then return end
	if procedural[obj] then procedural[obj].hover = nil end

	local loop = amount < 0
	local cycles = loop and math.huge or amount
	local s = speed or 1

	procedural[obj] = procedural[obj] or {}
	procedural[obj].hover = true

	task.spawn(function()
		for _ = 1, cycles do
			if not (procedural[obj] and procedural[obj].hover) then break end

			local t = 0
			while t < 1 do
				if not (procedural[obj] and procedural[obj].hover) then break end
				t += task.wait() * s
				local pos = startVec:Lerp(endVec, t)
				obj.CFrame = CFrame.new(pos) * obj.CFrame.Rotation
			end

			t = 0
			while t < 1 do
				if not (procedural[obj] and procedural[obj].hover) then break end
				t += task.wait() * s
				local pos = endVec:Lerp(startVec, t)
				obj.CFrame = CFrame.new(pos) * obj.CFrame.Rotation
			end
		end
	end)
end

function Tween:Move(obj, offset, time)
	if not obj or not obj.CFrame then return end
	return tween(obj, {CFrame = obj.CFrame * CFrame.new(offset)}, Enum.EasingStyle.Linear, time or 1)
end

function Tween:Scale(obj, factor, time)
	if not obj or not obj.Size then return end
	return tween(obj, {Size = obj.Size * factor}, Enum.EasingStyle.Linear, time or 1)
end

local function fade(obj, alpha, time)
	if obj:IsA("BasePart") then
		return tween(obj, {Transparency = alpha}, Enum.EasingStyle.Linear, time)
	end
	if obj:IsA("Beam") then
		return tween(obj, {Transparency = NumberSequence.new(alpha)}, Enum.EasingStyle.Linear, time)
	end
	if obj:IsA("ParticleEmitter") then
		return tween(obj, {Transparency = NumberSequence.new(alpha)}, Enum.EasingStyle.Linear, time)
	end
	if obj:IsA("Light") then
		return tween(obj, {Brightness = alpha}, Enum.EasingStyle.Linear, time)
	end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("TextLabel") or obj:IsA("TextButton") then
		return tween(obj, {ImageTransparency = alpha, TextTransparency = alpha}, Enum.EasingStyle.Linear, time)
	end
end

function Tween:FadeOut(obj, time)
	return fade(obj, 1, time or 1)
end

function Tween:FadeIn(obj, time)
	return fade(obj, 0, time or 1)
end

function Tween:Stop(obj)
	if active[obj] then active[obj]:Cancel() end
	if procedural[obj] then procedural[obj] = nil end
end

return Tween
