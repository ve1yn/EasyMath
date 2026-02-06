--!nonstrict
--@author: v_eiyn/ve1yn/veiyn
-- EasyMath.Pathfinding

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Pathfinding = {}
Pathfinding.__index = Pathfinding

-- =========================
-- Defaults
-- =========================
local DEFAULTS = {
	WalkSpeed = 12,
	Jump = true,
	JumpPower = 50,
	Damage = 0, -- make this the max health for insta kill
	DamageCooldown = 1, -- seconds between hits
	Range = 60,
	RepathDistance = 8,
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentJumpHeight = 10,
	AgentMaxSlope = 45,
}

local MovementAnimations = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
	Climb = "rbxassetid://507765644",
	Swim = "rbxassetid://507784897",
	Sit = "rbxassetid://2506281703",
}

local function applyDefaults(params)
	params = params or {}
	for k, v in pairs(DEFAULTS) do
		if params[k] == nil then
			params[k] = v
		end
	end
	return params
end

-- =========================
-- Math Helpers (Advanced only)
-- =========================
local function lerp(a,b,t) return a + (b-a)*t end

local function catmull(p0,p1,p2,p3,t)
	local t2 = t*t
	local t3 = t2*t
	return 0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t2+(-p0+3*p1-3*p2+p3)*t3)
end

local function bezier(p0,p1,p2,p3,t)
	local a = lerp(p0,p1,t)
	local b = lerp(p1,p2,t)
	local c = lerp(p2,p3,t)
	local d = lerp(a,b,t)
	local e = lerp(b,c,t)
	return lerp(d,e,t)
end

local function getSmoothPosition(prev,cur,next,next2,t,smoothness)
	local p0,p1,p2,p3 = prev or cur, cur, next, next2 or next
	local cat = catmull(p0,p1,p2,p3,t)
	local bez = bezier(p0,p1,p2,p3,t)
	return lerp(cat, bez, smoothness or 0.5)
end

-- =========================
-- Closest Player Helper
-- =========================
local function getClosestPlayer(hrp, range)
	local best, target = math.huge, nil
	for _,p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local phrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChild("Humanoid")
		if phrp and hum and hum.Health > 0 then
			local d = (phrp.Position - hrp.Position).Magnitude
			if d < best and d <= range then
				best = d
				target = phrp
			end
		end
	end
	return target
end
-- =========================
-- Controller Class
-- =========================
local Controller = {}
Controller.__index = Controller

function Controller.new(npc, mode, params, target)
	local self = setmetatable({}, Controller)
	self.NPC = npc
	self.Mode = mode
	self.Params = applyDefaults(params)
	self.Target = target
	self._lastPos = nil
	self._stuckTime = 0
	self.Humanoid = npc:FindFirstChildOfClass("Humanoid")
	self.HRP = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
	if self.Humanoid then
		self.Humanoid.WalkSpeed = self.Params.WalkSpeed
		self.Humanoid.JumpPower = self.Params.JumpPower
	end

	self.Waypoints = {}
	self.WPIndex = 1
	self.TSegment = 0
	self.LastGoal = nil
	self.LastJumped = 0
	self._movingTo = false
	self._moveConn = nil
	self._path = nil

	self.PathTotalDistance = 0
	self.PathTraveledDistance = 0
	self.PathVersion = 0
	self.LastSmoothPos = nil

	self._emoteTrack = nil
	self._emoteBusy = false
	self._emoteConfig = nil
	self._emotePathVersion = 0
	self._lastEmoteTouch = 0

	-- =========================
	-- Animations
	-- =========================
	self.Animations = {}
	local animFolder = npc:FindFirstChild("Animations")
	if animFolder then
		for _, anim in ipairs(animFolder:GetChildren()) do
			if anim:IsA("Animation") and self.Humanoid then
				local track = self.Humanoid:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action
				self.Animations[anim.Name] = track
			end
		end
	end

	if self.Humanoid then
		for name, id in pairs(MovementAnimations) do
			if not self.Animations[name] then
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				local track = self.Humanoid:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action
				self.Animations[name] = track
			end
		end
	end

	-- =========================
	-- Damage Setup
	-- =========================
	if self.Params.Damage > 0 then
		self._lastDamage = {}
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Touched:Connect(function(hit)
					local m = hit:FindFirstAncestorOfClass("Model")
					local h = m and m:FindFirstChildOfClass("Humanoid")
					if h and h.Health > 0 then
						local lastTime = self._lastDamage[h] or 0
						local now = tick()
						if now - lastTime >= self.Params.DamageCooldown then
							h:TakeDamage(self.Params.Damage)
							self._lastDamage[h] = now
						end
					end
				end)
			end
		end
	end

	-- =========================
	-- Heartbeat Loop
	-- =========================
	self.Connection = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)

	return self
end

-- =========================
-- Animation Helper
-- =========================
function Controller:_playMovementAnimation(animName)
	if not self.Animations or not self.Humanoid then return end

	local current = self.Animations[animName]
	if current and current.IsPlaying then
		return
	end

	for name, track in pairs(self.Animations) do
		if track.IsPlaying then
			track:Stop()
		end
	end

	if current then
		current:Play()
	end
end


-- =========================
-- Linear Movement
-- =========================
function Controller:_linearMove(goal)
	if not self.Humanoid or not self.HRP then return end
	if self._movingTo then return end

	self._movingTo = true
	self._path = PathfindingService:CreatePath({
		AgentRadius = self.Params.AgentRadius,
		AgentHeight = self.Params.AgentHeight,
		AgentCanJump = self.Params.AgentCanJump,
		AgentJumpHeight = self.Params.AgentJumpHeight,
		AgentMaxSlope = self.Params.AgentMaxSlope,
	})

	local ok = pcall(function()
		self._path:ComputeAsync(self.HRP.Position, goal)
	end)
	if not ok or self._path.Status ~= Enum.PathStatus.Success then
		self._movingTo = false
		return
	end

	self.Waypoints = {}
	for _, wp in ipairs(self._path:GetWaypoints()) do
		table.insert(self.Waypoints, {Pos = wp.Position, Jump = (wp.Action == Enum.PathWaypointAction.Jump)})
	end

	self.PathTotalDistance = 0
	for i = 2, #self.Waypoints do
		self.PathTotalDistance += (self.Waypoints[i].Pos - self.Waypoints[i-1].Pos).Magnitude
	end
	self.PathTraveledDistance = 0
	self.PathVersion += 1
	self.LastSmoothPos = self.HRP.Position

	local index = 1
	if self._moveConn then
		self._moveConn:Disconnect()
		self._moveConn = nil
	end

	self._moveConn = self.Humanoid.MoveToFinished:Connect(function(reached)
		if reached then
			if index < #self.Waypoints then
				local prev = self.Waypoints[index].Pos
				local nxt = self.Waypoints[index+1].Pos
				self.PathTraveledDistance += (nxt - prev).Magnitude
			end

			index += 1
			if index <= #self.Waypoints then
				local wp = self.Waypoints[index]
				if wp.Jump and self.Params.Jump then
					self.Humanoid.Jump = true
				end
				self.Humanoid:MoveTo(wp.Pos)
			else
				self._movingTo = false
				self._moveConn:Disconnect()
				self._moveConn = nil
			end
		else
			local wp = self.Waypoints[index]
			if wp then
				self.Humanoid:MoveTo(wp.Pos)
			end
		end
	end)

	if #self.Waypoints > 0 then
		local wp = self.Waypoints[index]
		if wp.Jump and self.Params.Jump then
			self.Humanoid.Jump = true
		end
		self.Humanoid:MoveTo(wp.Pos)
	end
end
function Controller:_step(dt)
	if not self.NPC or not self.HRP then return end

	local goal
	if self.Target == "ClosestPlayer" then
		local target = getClosestPlayer(self.HRP, self.Params.Range)
		goal = target and target.Position

	elseif typeof(self.Target) == "Instance" then
		if self.Target:IsA("BasePart") then
			goal = self.Target.Position
		elseif self.Target:IsA("Model") then
			local hrp = self.Target:FindFirstChild("HumanoidRootPart")
			goal = hrp and hrp.Position
		end

	elseif typeof(self.Target) == "Vector3" then
		goal = self.Target

	elseif typeof(self.Target) == "table" then
		local bestDist = math.huge
		local bestPos = nil

		for _, obj in ipairs(self.Target) do
			if typeof(obj) == "Instance" then
				if obj:IsA("BasePart") then
					local d = (obj.Position - self.HRP.Position).Magnitude
					if d < bestDist then
						bestDist = d
						bestPos = obj.Position
					end
				elseif obj:IsA("Model") then
					local hrp = obj:FindFirstChild("HumanoidRootPart")
					if hrp then
						local d = (hrp.Position - self.HRP.Position).Magnitude
						if d < bestDist then
							bestDist = d
							bestPos = hrp.Position
						end
					end
				end

			elseif typeof(obj) == "Vector3" then
				local d = (obj - self.HRP.Position).Magnitude
				if d < bestDist then
					bestDist = d
					bestPos = obj
				end
			end
		end

		goal = bestPos
	end

	if not goal then return end

	-- =========================
	-- Linear Mode
	-- =========================
	if self.Mode == "Linear" then
		if not self._movingTo then
			self:_linearMove(goal)
		end

		-- =========================
		-- Advanced Mode
		-- =========================
	else
		if not self.LastGoal or (goal - self.LastGoal).Magnitude > self.Params.RepathDistance or self.WPIndex > #self.Waypoints then
			local path = PathfindingService:CreatePath({
				AgentRadius = self.Params.AgentRadius,
				AgentHeight = self.Params.AgentHeight,
				AgentCanJump = self.Params.AgentCanJump,
				AgentJumpHeight = self.Params.AgentJumpHeight,
				AgentMaxSlope = self.Params.AgentMaxSlope,
			})

			local ok = pcall(function()
				path:ComputeAsync(self.HRP.Position, goal)
			end)

			if ok and path.Status == Enum.PathStatus.Success then
				self.Waypoints = {}
				for _, wp in ipairs(path:GetWaypoints()) do
					table.insert(self.Waypoints, {Pos = wp.Position, Jump = (wp.Action == Enum.PathWaypointAction.Jump)})
				end

				self.WPIndex = 1
				self.TSegment = 0
				self.LastGoal = goal

				self.PathTotalDistance = 0
				for i = 2, #self.Waypoints do
					self.PathTotalDistance += (self.Waypoints[i].Pos - self.Waypoints[i-1].Pos).Magnitude
				end
				self.PathTraveledDistance = 0
				self.PathVersion += 1
				self.LastSmoothPos = self.HRP.Position
			end
		end

		if #self.Waypoints < 1 then return end

		local smoothness = self.Params.smoothness or 0.5
		local prev = self.Waypoints[math.max(self.WPIndex-1,1)].Pos
		local cur = self.Waypoints[self.WPIndex].Pos
		local nxt = self.Waypoints[self.WPIndex+1] and self.Waypoints[self.WPIndex+1].Pos or cur
		local nxt2 = self.Waypoints[self.WPIndex+2] and self.Waypoints[self.WPIndex+2].Pos or nxt

		local segmentDist = (cur - prev).Magnitude
		if segmentDist == 0 then segmentDist = 0.001 end

		self.TSegment = self.TSegment + dt * (self.Humanoid and self.Humanoid.WalkSpeed or 16) / segmentDist

		if self.TSegment >= 1 then
			self.TSegment -= 1
			if self.WPIndex < #self.Waypoints then
				self.PathTraveledDistance += (self.Waypoints[self.WPIndex+1].Pos - self.Waypoints[self.WPIndex].Pos).Magnitude
			end
			self.WPIndex += 1
			if self.WPIndex >= #self.Waypoints then
				self.WPIndex = #self.Waypoints
				self.TSegment = 1
			end
		end

		local smoothPos = getSmoothPosition(prev, cur, nxt, nxt2, math.clamp(self.TSegment,0,1), smoothness)

		if self.LastSmoothPos then
			self.PathTraveledDistance += (smoothPos - self.LastSmoothPos).Magnitude
		end
		self.LastSmoothPos = smoothPos

		if self.Humanoid then
			self.Humanoid:MoveTo(smoothPos)

			local currentPos = self.HRP.Position
			if self._lastPos then
				local moved = (currentPos - self._lastPos).Magnitude
				if moved < 0.1 then
					self._stuckTime += dt
				else
					self._stuckTime = 0
				end
			end
			self._lastPos = currentPos

			local wp = self.Waypoints[self.WPIndex]
			local nextWp = self.Waypoints[self.WPIndex + 1]

			local jumpNeeded = false

			if wp and wp.Jump then
				jumpNeeded = true
			end

			if nextWp and (nextWp.Pos.Y - self.HRP.Position.Y) > 2 then
				jumpNeeded = true
			end

			local forwardOrigin = self.HRP.Position + Vector3.new(0, 2, 0)
			local forwardDir = self.HRP.CFrame.LookVector * 4

			local downOrigin = self.HRP.Position + self.HRP.CFrame.LookVector * 2
			local downDir = Vector3.new(0, -4, 0)

			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {self.NPC}
			params.FilterType = Enum.RaycastFilterType.Exclude

			local forwardHit = workspace:Raycast(forwardOrigin, forwardDir, params)
			local downHit = workspace:Raycast(downOrigin, downDir, params)

			if forwardHit then
				local hitY = forwardHit.Position.Y
				local npcY = self.HRP.Position.Y
				local heightDiff = hitY - npcY
				if heightDiff > 0 and heightDiff <= self.Params.AgentJumpHeight then
					jumpNeeded = true
				end
			end

			if not downHit then
				jumpNeeded = true
			end

			if forwardHit and (forwardHit.Position - self.HRP.Position).Magnitude < 1 then
				jumpNeeded = false
			end

			if self._stuckTime > 0.5 then
				jumpNeeded = true
			end

			if jumpNeeded and self.LastJumped ~= self.WPIndex then
				self.Humanoid.Jump = true
				self.LastJumped = self.WPIndex
				self._stuckTime = 0
			end
		end
	end


	-- =========================
	-- Path Progress
	-- =========================
	local progress = 0
	if self.PathTotalDistance > 0 then
		progress = math.clamp(self.PathTraveledDistance / self.PathTotalDistance, 0, 1)
	end

	-- =========================
	-- Emote Trigger by Progress
	-- =========================
	if self._emoteConfig and not self._emoteBusy then
		if self._emoteConfig.Progress <= progress then
			if self._emotePathVersion ~= self.PathVersion then
				self:_playEmote(self._emoteConfig.Id, self._emoteConfig.RepeatCount)
				self._emotePathVersion = self.PathVersion
			end
		end
	end

	-- =========================
	-- Emote Trigger by Touch
	-- =========================
	if self.Target == "ClosestPlayer" then
		local target = getClosestPlayer(self.HRP, self.Params.Range)
		if target then
			local touching = (target.Position - self.HRP.Position).Magnitude <= 4
			if touching and not self._emoteBusy then
				local now = tick()
				if now - self._lastEmoteTouch >= 1 then
					self._lastEmoteTouch = now
					if self._emoteConfig then
						self:_playEmote(self._emoteConfig.Id, 1)
					end
				end
			end
		end
	end

	-- =========================
	-- Movement Animations
	-- =========================
	if self.Animations and self.Humanoid then
		local moving = (self.Mode == "Advanced" and self.WPIndex < #self.Waypoints)
			or (self.Mode == "Linear" and self._movingTo)
		if self.Animations and self.Humanoid then
			local state = self.Humanoid:GetState()
			local velocity = self.HRP.AssemblyLinearVelocity.Magnitude
			if state == Enum.HumanoidStateType.Jumping
				or state == Enum.HumanoidStateType.Freefall then

				self:_playMovementAnimation("Jump")
				return
			end
			if velocity < 0.1 then
				self:_playMovementAnimation("Idle")
			elseif velocity < 8 then
				self:_playMovementAnimation("Walk")
			else
				self:_playMovementAnimation("Run")
			end
		end
	end
end

-- =========================
-- Emote Playback
-- =========================
function Controller:_playEmote(id, repeatCount)
	if self._emoteBusy then return end
	self._emoteBusy = true

	if self._emoteTrack then
		self._emoteTrack:Stop()
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. id
	self._emoteTrack = self.Humanoid:LoadAnimation(anim)
	self._emoteTrack.Priority = Enum.AnimationPriority.Action

	if repeatCount == -1 then
		self._emoteTrack.Looped = true
		self._emoteTrack:Play()
		task.spawn(function()
			local currentVersion = self.PathVersion
			while self._emoteTrack and self._emoteTrack.IsPlaying and currentVersion == self.PathVersion do
				task.wait()
			end
			if self._emoteTrack then
				self._emoteTrack:Stop()
			end
			self._emoteBusy = false
		end)

	else
		self._emoteTrack.Looped = false
		self._emoteTrack:Play()

		task.spawn(function()
			for i = 1, repeatCount do
				if not self._emoteTrack then break end
				self._emoteTrack.Stopped:Wait()
				if i < repeatCount then
					self._emoteTrack:Play()
				end
			end
			self._emoteBusy = false
		end)
	end
end

function Controller:Emote(id, progress, repeatCount)
	self._emoteConfig = {
		Id = id,
		Progress = progress or 0,
		RepeatCount = repeatCount or 1
	}
	self._emotePathVersion = -1
end

function Controller:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	if self._moveConn then
		self._moveConn:Disconnect()
		self._moveConn = nil
	end
	self._path = nil
	if self._emoteTrack then
		self._emoteTrack:Stop()
	end
end
function Pathfinding:Start(mode, smoothness, parameters, obj, target)
	if not obj then warn("[EasyMath.Pathfinding] Object missing") return end
	mode = tostring(mode)
	if mode ~= "Linear" and mode ~= "Advanced" then
		warn("[EasyMath.Pathfinding] Unknown mode", mode)
		return
	end
	parameters = applyDefaults(parameters)
	parameters.smoothness = smoothness
	return Controller.new(obj, mode, parameters, target)
end

function Pathfinding:Emote(controller, id, progress, repeatCount)
	if controller and controller.Emote then
		controller:Emote(id, progress, repeatCount)
	end
end

return Pathfinding
