--!nonstrict
--@author: v_eiyn
-- EasyMath.Tween

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Tween = {}
Tween.__index = Tween

-- =========================
-- Internal Controller Class
-- =========================
local Controller = {}
Controller.__index = Controller

-- =========================
-- Internal Storage
-- =========================
local activeTweens = {}
local effects = {}

-- =========================
-- Type Helpers
-- =========================
local function is3D(obj)
	return obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Attachment")
end

local function isUI(obj)
	return obj:IsA("GuiObject")
end

local function isCamera(obj)
	return obj == workspace.CurrentCamera or obj:IsA("Camera")
end

-- =========================
-- TweenService Wrapper
-- =========================
local function playTween(obj, props, easing, time)
	if activeTweens[obj] then
		for _, t in ipairs(activeTweens[obj]) do
			t:Cancel()
		end
	end

	local info = TweenInfo.new(time, easing or Enum.EasingStyle.Linear)
	local t = TweenService:Create(obj, info, props)

	activeTweens[obj] = activeTweens[obj] or {}
	table.insert(activeTweens[obj], t)

	t:Play()
	t.Completed:Connect(function()
		if not activeTweens[obj] then return end
		for i = #activeTweens[obj], 1, -1 do
			if activeTweens[obj][i] == t then
				table.remove(activeTweens[obj], i)
				break
			end
		end
		if #activeTweens[obj] == 0 then
			activeTweens[obj] = nil
		end
	end)

	return t
end
-- =========================
-- Effect Engine Helpers
-- =========================
local function ensureEffects(obj)
	effects[obj] = effects[obj] or {
		_running = false,
		_list = {}
	}
	return effects[obj]
end

local function startEffectLoop(obj)
	local data = effects[obj]
	if not data or data._running then return end
	data._running = true

	task.spawn(function()
		local last = os.clock()
		while effects[obj] and next(effects[obj]._list) ~= nil do
			local now = os.clock()
			local dt = now - last
			last = now

			for _, eff in pairs(effects[obj]._list) do
				if eff.update then
					eff:update(dt)
				end
			end

			RunService.Heartbeat:Wait()
		end

		if effects[obj] then
			effects[obj]._running = false
			if next(effects[obj]._list) == nil then
				effects[obj] = nil
			end
		end
	end)
end

local function setEffect(obj, name, eff)
	local data = ensureEffects(obj)
	if not eff then
		data._list[name] = nil
	else
		data._list[name] = eff
		startEffectLoop(obj)
	end
end
-- =========================
-- Unified Rotation Handler
-- =========================
function Controller:_applyRotation(obj, deltaDeg)
	if obj:IsA("BasePart") then
		obj.CFrame = obj.CFrame * CFrame.Angles(0, math.rad(deltaDeg), 0)

	elseif obj:IsA("Model") and obj.PrimaryPart then
		obj:SetPrimaryPartCFrame(obj.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(deltaDeg), 0))

	elseif obj:IsA("Attachment") then
		obj.CFrame = obj.CFrame * CFrame.Angles(0, math.rad(deltaDeg), 0)

	elseif isUI(obj) then
		obj.Rotation = obj.Rotation + deltaDeg

	elseif isCamera(obj) then
		obj.CFrame = obj.CFrame * CFrame.Angles(0, math.rad(deltaDeg), 0)
	end
end

-- =========================
-- Unified Fade Handler
-- =========================
function Controller:_fadeSingle(obj, alpha, time, easing)
	local ease = easing or Enum.EasingStyle.Linear
	local duration = time or 1

	if obj:IsA("BasePart") then
		return playTween(obj, {Transparency = alpha}, ease, duration)
	end
	if obj:IsA("Beam") then
		return playTween(obj, {Transparency = NumberSequence.new(alpha)}, ease, duration)
	end
	if obj:IsA("ParticleEmitter") then
		return playTween(obj, {Transparency = NumberSequence.new(alpha)}, ease, duration)
	end
	if obj:IsA("Light") then
		return playTween(obj, {Brightness = alpha}, ease, duration)
	end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		return playTween(obj, {
			ImageTransparency = alpha,
			BackgroundTransparency = alpha
		}, ease, duration)
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		return playTween(obj, {
			TextTransparency = alpha,
			BackgroundTransparency = alpha
		}, ease, duration)
	end
	if obj:IsA("Frame") then
		return playTween(obj, {
			BackgroundTransparency = alpha
		}, ease, duration)
	end
	if isCamera(obj) then
		return playTween(obj, {FieldOfView = alpha}, ease, duration)
	end

	return nil
end

local function collectFadeTargets(root)
	local list = {}
	local dummy = Controller:_fadeSingle(root, 0, 0, Enum.EasingStyle.Linear)
	if dummy ~= nil then
		table.insert(list, root)
	end
	for _, child in ipairs(root:GetDescendants()) do
		local t = Controller:_fadeSingle(child, 0, 0, Enum.EasingStyle.Linear)
		if t ~= nil then
			table.insert(list, child)
		end
	end
	return list
end
-- =========================
-- Procedural: Rotate
-- =========================
function Tween:Rotate(obj, angle, speed)
	if not obj then return end
	speed = speed or 1

	if angle < 0 then
		local eff = {
			speed = speed,
			update = function(self, dt)
				local degPerSec = self.speed * 15
				local delta = degPerSec * dt
				Controller:_applyRotation(obj, delta)
			end
		}
		setEffect(obj, "Rotate", eff)
		return eff
	end

	return playTween(obj, {}, Enum.EasingStyle.Linear, speed)
end

-- =========================
-- Procedural: Hover (3D only)
-- =========================
function Tween:Hover(obj, startVec, endVec, amount, speed)
	if not obj or not obj.CFrame then return end

	local loop = amount < 0
	local cycles = loop and math.huge or amount
	local s = speed or 1

	local eff = {
		t = 0,
		dir = 1,
		cycles = cycles,
		done = 0,
		update = function(self, dt)
			if self.done >= self.cycles then
				setEffect(obj, "Hover", nil)
				return
			end

			self.t += dt * s * self.dir

			if self.t >= 1 then
				self.t = 1
				self.dir = -1
			elseif self.t <= 0 then
				self.t = 0
				self.dir = 1
				self.done += 1
				if self.done >= self.cycles then
					setEffect(obj, "Hover", nil)
					return
				end
			end

			local pos = startVec:Lerp(endVec, self.t)
			obj.CFrame = CFrame.new(pos) * obj.CFrame.Rotation
		end
	}

	setEffect(obj, "Hover", eff)
	return eff
end

-- =========================
-- Procedural: Camera Shake
-- =========================
function Tween:CameraShake(camera, settings)
	camera = camera or workspace.CurrentCamera
	if not camera then return end

	local mag = settings and settings.magnitude or 1
	local rough = settings and settings.roughness or 20
	local rotPower = settings and settings.rotation or 2
	local fadeIn = settings and settings.fadeIn or 0.1
	local fadeOut = settings and settings.fadeOut or 0.2
	local duration = settings and settings.duration or 1

	local base = camera.CFrame
	local t = 0

	local eff = {
		update = function(self, dt)
			t += dt
			if t >= duration then
				camera.CFrame = base
				setEffect(camera, "CameraShake", nil)
				return
			end

			local p = t / duration
			local strength
			if p < fadeIn then
				strength = p / fadeIn
			elseif p > 1 - fadeOut then
				strength = (1 - p) / fadeOut
			else
				strength = 1
			end

			local n = t * rough

			local offset = Vector3.new(
				(math.noise(n,0,0)-0.5)*2*mag*strength,
				(math.noise(0,n,0)-0.5)*2*mag*strength,
				(math.noise(0,0,n)-0.5)*2*mag*strength
			)
			local rotX = (math.noise(n*1.2, 0, 0) - 0.5) * rotPower * strength
			local rotY = (math.noise(0, n*1.2, 0) - 0.5) * rotPower * strength

			camera.CFrame =
				base *
				CFrame.new(offset) *
				CFrame.Angles(
					math.rad(rotX),
					math.rad(rotY),
					0
				)
		end
	}

	setEffect(camera, "CameraShake", eff)
	return eff
end

-- =========================
-- Move (3D + UI)
-- =========================
function Tween:Move(obj, offset, time, easing)
	if not obj then return end

	if is3D(obj) and obj.CFrame then
		return playTween(obj, {
			CFrame = obj.CFrame * CFrame.new(offset)
		}, easing, time or 1)

	elseif isUI(obj) then
		local pos = obj.Position
		return playTween(obj, {
			Position = UDim2.new(
				pos.X.Scale,
				pos.X.Offset + offset.X,
				pos.Y.Scale,
				pos.Y.Offset + offset.Y
			)
		}, easing, time or 1)
	end
end

-- =========================
-- Scale (3D + UI)
-- =========================
function Tween:Scale(obj, factor, time, easing)
	if not obj then return end

	if obj:IsA("BasePart") then
		return playTween(obj, {
			Size = obj.Size * factor
		}, easing, time or 1)

	elseif isUI(obj) then
		local size = obj.Size
		return playTween(obj, {
			Size = UDim2.new(
				size.X.Scale * factor,
				size.X.Offset * factor,
				size.Y.Scale * factor,
				size.Y.Offset * factor
			)
		}, easing, time or 1)
	end
end

-- =========================
-- Fade (single or table)
-- =========================
function Tween:Fade(target, alpha, time, easing)
	if typeof(target) == "table" then
		for _, obj in ipairs(target) do
			Controller:_fadeSingle(obj, alpha, time, easing)
		end
	elseif typeof(target) == "Instance" then
		Controller:_fadeSingle(target, alpha, time, easing)
	end
end

function Tween:FadeOut(target, time, easing)
	self:Fade(target, 1, time, easing)
end

function Tween:FadeIn(target, time, easing)
	self:Fade(target, 0, time, easing)
end

-- =========================
-- Fade Entire Tree
-- =========================
function Tween:FadeTree(root, alpha, time, easing)
	local targets = collectFadeTargets(root)
	self:Fade(targets, alpha, time, easing)
end

function Tween:FadeOutTree(root, time, easing)
	self:FadeTree(root, 1, time, easing)
end

function Tween:FadeInTree(root, time, easing)
	self:FadeTree(root, 0, time, easing)
end

-- =========================
-- Stop Effects
-- =========================
function Tween:Stop(obj)
	if activeTweens[obj] then
		for _, t in ipairs(activeTweens[obj]) do
			t:Cancel()
		end
		activeTweens[obj] = nil
	end
	if effects[obj] then
		effects[obj] = nil
	end
end

function Tween:StopEffect(obj, name)
	if effects[obj] and effects[obj]._list[name] then
		effects[obj]._list[name] = nil
	end
end

return Tween
