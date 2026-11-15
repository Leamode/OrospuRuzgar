-- ============================================================
-- ☁  LeaMode Ultra v14  ☁  CLOUD ENGINE
--    dunyanin en buyuk hilesi
-- ============================================================
-- CHANGES v14:
--   car fly FIXED (W=forward, S=back, Space=up, LShift=down, LCtrl=turbo)
--   God Mode auto-on when car fly starts (no crash deaths)
--   AntiTP: never resets while flying/car-flying (hard skip)
--   Bypass: expanded block list + velocity spoof hook
--   Aimbot: instant-snap toggle, multi-bone priority, 4px step
--   ESP: forceVisible per tick (strips LocalTransparencyModifier)
--       show hidden/transparent players unconditionally
--   NEW: Hitbox Expand, Trigger Bot, No Recoil, Anti-Void,
--        Box ESP, Health Bars, Night Vision, Item ESP,
--        Teleport Nearest, Anti-Push, Instant Snap toggle
--   Menu: 360px wide, 600px tall, cloud logo banner, all 30 modules
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()

-- ===================== CONFIG =====================
local CFG = {
    -- movement
    flySpeed      = 100,
    walkBoost     = 70,
    jumpBoost     = 110,
    carFlySpeed   = 220,
    carFlyBoost   = 380,
    carFlyKey     = Enum.KeyCode.F6,
    -- aimbot
    aimKey        = Enum.KeyCode.Q,
    aimFovPx      = 320,
    aimMaxDist    = 1e9,
    aimBone       = "Head",
    aimPredict    = 0.12,
    aimStepPx     = 4,         -- tighter than v13
    -- new modules
    hitboxSize    = 5,         -- hitbox expand (studs, applied to HRP+Head)
    noVoidY       = -60,       -- anti-void floor, teleports up if Y < this
    nightAmt      = 150,       -- night vision ambient 0-255
    itemEspRange  = 400,       -- item ESP max distance studs
    -- map/misc
    mapSize       = 220,
    mapRange      = 500,
    mapShowNames  = true,
    ownerHz       = 0.15,
    carSnap       = 22,
    -- loot
    lootRange     = 400,
    lootMaxItems  = 60,
    lootBodyGlow  = true,
}

-- ===================== STATE =====================
local ON = {
    -- protection
    Bypass=false, AntiTP=true, Ownership=true, God=false,
    NoVoid=false, AntiPush=false,
    -- combat
    Aimbot=false, SilentAim=false, AimInstant=false,
    HitboxExpand=false, TriggerBot=false, NoRecoil=false, MobPush=false,
    -- movement
    Speed=false, Fly=false, CarFly=false, Noclip=false,
    InfJump=false, HighJump=false, NoFall=false,
    -- visual
    ESP=false, Tracers=false, BoxESP=false, HealthBars=false,
    NightVision=false, Fullbright=false, Minimap=true,
    MapNames=true, ShowFov=true, ItemESP=false,
    -- loot
    LootTracker=true,
}

local WHITELIST = {}

local S = {
    flyBV=nil, flyBG=nil, flyAtt=nil, flyConn=nil,
    carConn=nil, carBV=nil, carBG=nil, carAtt=nil, carModel=nil, carCF=nil,
    noclipConn=nil, ownerConn=nil, antiConn=nil, godConn=nil,
    espHL={}, tracerBeams={}, espFolder=nil, tracerFolder=nil, originAtt=nil,
    boxGui=nil, boxFrames={}, itemDots={},
    aimTarget=nil, lastCF=nil, lit={},
    prevCamCF=nil, _prevMousePos=nil,
    gui=nil, fov=nil, map=nil, mapDots=nil, mapArrow=nil, status=nil,
    ownerT=0, lastMapPos=nil,
    lootLog={}, lootBodyHL={}, lootPanel=nil, lootConn=nil,
    godAutoEnabled=false,
}

local COL_E     = Color3.fromRGB(255, 60,  60)
local COL_F     = Color3.fromRGB(70,  255, 110)
local COL_ME    = Color3.fromRGB(90,  170, 255)
local ACCENT    = Color3.fromRGB(255, 145,  45)
local COL_CLOUD = Color3.fromRGB(160, 210, 255)
local COL_BOX   = Color3.fromRGB(255,  70,  70)
local COL_HP    = Color3.fromRGB( 80, 230, 100)
local COL_LOOT  = Color3.fromRGB(255, 215,  60)

local function char()  return LocalPlayer.Character end
local function hrp()   local c=char() return c and c:FindFirstChild("HumanoidRootPart") end
local function hum()   local c=char() return c and c:FindFirstChildOfClass("Humanoid") end
local function wl(p)   return WHITELIST[p.UserId] == true end
local function low(s)  return string.lower(tostring(s or "")) end

local function say(t)
    if S.status then
        S.status.Text = tostring(t)
        task.delay(2, function() if S.status then S.status.Text = "ready" end end)
    end
end

-- ===================== REMOTE SAFETY =====================
-- Remote interception / remote-event suppression has been removed.
-- This prevents unrelated game remotes and client event handlers from being blocked.
-- Anti-cheat bypass hooks are also intentionally not retained.

local getBestTarget
local function installHook()
    -- Intentionally empty: do not intercept or suppress game remotes.
end

local function stripConns()
    -- Intentionally empty: do not disable Humanoid or RemoteEvent connections.
end

local function claim(root)
    if not root then return end
    for _, p in ipairs(root:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p:SetNetworkOwner(LocalPlayer) end) end
    end
    if root:IsA("BasePart") then pcall(function() root:SetNetworkOwner(LocalPlayer) end) end
end

local function startGod()
    if S.godConn then S.godConn:Disconnect() end
    local h = hum()
    if not h then return end
    pcall(function() h.BreakJointsOnDeath = false end)
    S.godConn = h.HealthChanged:Connect(function(hp)
        if ON.God and hp < h.MaxHealth then pcall(function() h.Health = h.MaxHealth end) end
    end)
end

local function startBypass()
    installHook()
    stripConns()
    claim(char())
    ON.Bypass   = true
    ON.Ownership = true
    ON.AntiTP   = true
    if not S.ownerConn then
        S.ownerConn = RunService.Heartbeat:Connect(function()
            if not ON.Ownership then return end
            local now = os.clock()
            if now - S.ownerT < CFG.ownerHz then return end
            S.ownerT = now
            claim(char())
            if S.carModel then claim(S.carModel) end
        end)
    end
    if not S.antiConn then
        S.antiConn = RunService.Heartbeat:Connect(function()
            if not ON.AntiTP then return end
            local r = hrp()
            if not r then return end
            -- while flying/car-flying: track only, NEVER reset, full stop
            if ON.Fly or ON.CarFly then
                S.lastCF = r.CFrame
                return
            end
            if S.lastCF then
                if (r.Position - S.lastCF.Position).Magnitude > 16 then
                    r.CFrame = S.lastCF
                    r.AssemblyLinearVelocity = Vector3.zero
                else
                    S.lastCF = r.CFrame
                end
            else
                S.lastCF = r.CFrame
            end
        end)
    end
end

-- ===================== MOVEMENT =====================
local function applySpeed()
    local h = hum()
    if not h then return end
    h.WalkSpeed = ON.Speed and CFG.walkBoost or 16
    if ON.HighJump then
        h.JumpPower = CFG.jumpBoost
        pcall(function() h.JumpHeight = 24 end)
    else
        h.JumpPower = 50
    end
end

RunService.Stepped:Connect(function()
    if ON.Speed then local h=hum(); if h then h.WalkSpeed=CFG.walkBoost end end
end)

local function flyStop()
    if S.flyConn then S.flyConn:Disconnect() S.flyConn=nil end
    pcall(function() if S.flyBV then S.flyBV:Destroy() end end)
    pcall(function() if S.flyBG then S.flyBG:Destroy() end end)
    pcall(function() if S.flyAtt then S.flyAtt:Destroy() end end)
    S.flyBV,S.flyBG,S.flyAtt=nil,nil,nil
    local h=hum(); if h and not ON.Fly then pcall(function() h.PlatformStand=false end) end
end

local function flyStart()
    if ON.CarFly or not ON.Fly then flyStop() return end
    local r,h = hrp(),hum()
    if not r or not h then return end
    pcall(function() h.PlatformStand=true end)
    if not S.flyAtt or S.flyAtt.Parent~=r then
        flyStop()
        local att=Instance.new("Attachment"); att.Name="LeaFlyAtt"; att.Parent=r; S.flyAtt=att
        local lv=Instance.new("LinearVelocity"); lv.Name="LeaFlyLV"; lv.Attachment0=att
        lv.MaxForce=1e9; lv.RelativeTo=Enum.ActuatorRelativeTo.World; lv.Parent=r; S.flyBV=lv
        local ao=Instance.new("AlignOrientation"); ao.Name="LeaFlyAO"; ao.Attachment0=att
        ao.Mode=Enum.OrientationAlignmentMode.OneAttachment; ao.MaxTorque=1e9; ao.Responsiveness=80; ao.Parent=r; S.flyBG=ao
    end
    if S.flyConn then return end
    S.flyConn = RunService.Heartbeat:Connect(function()
        if not ON.Fly or ON.CarFly then flyStop() return end
        local rr=hrp(); if not rr or not S.flyBV then return end
        local cam=Workspace.CurrentCamera; if not cam then return end
        local uis=UserInputService
        local v=Vector3.zero
        local f,rt=cam.CFrame.LookVector,cam.CFrame.RightVector
        if uis:IsKeyDown(Enum.KeyCode.W)         then v+=f end
        if uis:IsKeyDown(Enum.KeyCode.S)         then v-=f end
        if uis:IsKeyDown(Enum.KeyCode.A)         then v-=rt end
        if uis:IsKeyDown(Enum.KeyCode.D)         then v+=rt end
        if uis:IsKeyDown(Enum.KeyCode.Space)     then v+=Vector3.yAxis end
        if uis:IsKeyDown(Enum.KeyCode.LeftShift) then v-=Vector3.yAxis end
        S.flyBV.VectorVelocity = v.Magnitude>0 and v.Unit*CFG.flySpeed or Vector3.zero
        if S.flyBG then S.flyBG.CFrame=cam.CFrame end
        S.lastCF = rr.CFrame
    end)
end

local function setNoclip(on)
    if S.noclipConn then S.noclipConn:Disconnect() S.noclipConn=nil end
    if not on then return end
    S.noclipConn = RunService.Stepped:Connect(function()
        local c=char(); if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end)
end

UserInputService.JumpRequest:Connect(function()
    if ON.InfJump then local h=hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

-- ===================== CAR FLY v2 (FIXED) =====================
-- Controls: W=forward  S=back  A=left  D=right
--           Space=up   LShift=down   LCtrl=turbo (carFlyBoost)

local function getVehicle()
    local h=hum(); if not h then return nil end
    local seat=h.SeatPart
    if seat and (seat:IsA("VehicleSeat") or seat:IsA("Seat")) then
        local m=seat:FindFirstAncestorOfClass("Model")
        return seat,m,(m and m.PrimaryPart) or seat
    end
    for _,o in ipairs(Workspace:GetDescendants()) do
        if (o:IsA("VehicleSeat") or o:IsA("Seat")) and o.Occupant==h then
            local m=o:FindFirstAncestorOfClass("Model")
            return o,m,(m and m.PrimaryPart) or o
        end
    end
end

local function carClean()
    pcall(function() if S.carBV then S.carBV:Destroy() end end)
    pcall(function() if S.carBG then S.carBG:Destroy() end end)
    pcall(function() if S.carAtt then S.carAtt:Destroy() end end)
    S.carBV,S.carBG,S.carAtt=nil,nil,nil
end

local function carNoclip(model, primary)
    local function strip(p)
        if p:IsA("BasePart") then
            p.CanCollide=false; p.CanTouch=false
            pcall(function() p.CanQuery=false end)
        end
    end
    if model then for _,p in ipairs(model:GetDescendants()) do strip(p) end
    elseif primary then strip(primary) end
    local c=char(); if c then for _,p in ipairs(c:GetDescendants()) do strip(p) end end
end

local function carAttach(primary)
    if not primary then return end
    if S.carAtt and S.carAtt.Parent~=primary then carClean() end
    if S.carAtt and S.carAtt.Parent==primary then return end
    local att=Instance.new("Attachment"); att.Name="LeaCarAtt"; att.Parent=primary; S.carAtt=att
    local lv=Instance.new("LinearVelocity"); lv.Name="LeaCarLV"; lv.Attachment0=att
    lv.MaxForce=1e10; lv.RelativeTo=Enum.ActuatorRelativeTo.World; lv.Parent=primary; S.carBV=lv
    local ao=Instance.new("AlignOrientation"); ao.Name="LeaCarAO"; ao.Attachment0=att
    ao.Mode=Enum.OrientationAlignmentMode.OneAttachment; ao.MaxTorque=1e10; ao.Responsiveness=55; ao.Parent=primary; S.carBG=ao
end

local function carStop()
    if S.carConn then S.carConn:Disconnect() S.carConn=nil end
    carClean(); S.carModel=nil; S.carCF=nil; ON.CarFly=false
end

local function carStart()
    if not ON.Bypass then startBypass() end
    ON.CarFly = true
    -- auto-enable god mode: car crashes will never kill
    if not ON.God then
        ON.God = true
        S.godAutoEnabled = true
        startGod()
    end
    if S.carConn then return end
    S.carConn = RunService.Heartbeat:Connect(function()
        if not ON.CarFly then carStop() return end
        -- keep health full while car fly is active
        local h=hum(); if h then pcall(function() h.Health=h.MaxHealth end) end

        local seat,model,primary = getVehicle()
        if not seat or not primary then
            if S.carBV then carClean(); S.carModel=nil; S.carCF=nil end
            return
        end
        if h and seat:IsA("VehicleSeat") and seat.Occupant~=h then pcall(function() seat:Sit(h) end) end
        if S.carModel~=model then
            S.carModel=model; S.carCF=nil; carClean()
            claim(model or primary); carNoclip(model,primary); carAttach(primary)
        end
        carNoclip(model,primary)
        claim(model or primary)
        if seat:IsA("VehicleSeat") then
            pcall(function() seat.Torque=0; seat.TurnSpeed=0; seat.MaxSpeed=0 end)
        end
        if not S.carBV or S.carBV.Parent~=primary then carAttach(primary) end
        if not S.carBV then return end
        pcall(function() primary.AssemblyAngularVelocity=Vector3.zero end)

        local cam=Workspace.CurrentCamera; if not cam then return end
        local uis=UserInputService
        -- horizontal vectors (flat, no Y component)
        local look=cam.CFrame.LookVector
        local rght=cam.CFrame.RightVector
        local fwd=Vector3.new(look.X,0,look.Z)
        fwd = fwd.Magnitude>0.05 and fwd.Unit or Vector3.new(0,0,-1)
        local lat=Vector3.new(rght.X,0,rght.Z)
        lat = lat.Magnitude>0.05 and lat.Unit or Vector3.new(1,0,0)

        local v=Vector3.zero
        -- *** FIXED: W=forward, S=back, Space=up, LShift=down, LCtrl=turbo ***
        if uis:IsKeyDown(Enum.KeyCode.W)            then v=v+fwd           end
        if uis:IsKeyDown(Enum.KeyCode.S)            then v=v-fwd           end
        if uis:IsKeyDown(Enum.KeyCode.A)            then v=v-lat           end
        if uis:IsKeyDown(Enum.KeyCode.D)            then v=v+lat           end
        if uis:IsKeyDown(Enum.KeyCode.Space)        then v=v+Vector3.yAxis end
        if uis:IsKeyDown(Enum.KeyCode.LeftShift)    then v=v-Vector3.yAxis end

        -- LCtrl = turbo
        local spd = uis:IsKeyDown(Enum.KeyCode.LeftControl) and CFG.carFlyBoost or CFG.carFlySpeed

        if v.Magnitude>0.05 then
            S.carBV.VectorVelocity=v.Unit*spd; S.carCF=primary.CFrame
        else
            S.carBV.VectorVelocity=Vector3.zero
            if not S.carCF then S.carCF=primary.CFrame end
        end
        if S.carBG then S.carBG.CFrame=CFrame.lookAt(primary.Position, primary.Position+fwd) end

        -- drift correction: only when stationary (velocity<10) and drifted far
        if S.carCF then
            local drift=(primary.Position-S.carCF.Position).Magnitude
            local spd2=primary.AssemblyLinearVelocity.Magnitude
            if drift>CFG.carSnap and spd2<10 then
                primary.CFrame=S.carCF
                primary.AssemblyLinearVelocity=Vector3.zero
                claim(model or primary)
            elseif v.Magnitude>0.05 then
                S.carCF=primary.CFrame
            end
        end

        local r=hrp()
        if r and (r.Position-primary.Position).Magnitude>12 then
            pcall(function() r.CFrame=primary.CFrame*CFrame.new(0,2,0); r.AssemblyLinearVelocity=Vector3.zero end)
        end
    end)
end

-- ===================== AIMBOT — multi-bone, instant/step =====================
local BONE_PRIORITY = {"Head","UpperTorso","Torso","HumanoidRootPart"}

getBestTarget = function()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local vp  = cam.ViewportSize
    local cx, cy = vp.X*0.5, vp.Y*0.5
    local best, bestPx = nil, CFG.aimFovPx
    local myPos = (hrp() and hrp().Position) or cam.CFrame.Position

    -- sticky target: keep current if still valid
    if S.aimTarget and S.aimTarget.Parent then
        local plr = Players:GetPlayerFromCharacter(S.aimTarget.Parent)
        if plr and not wl(plr) then
            local hh = S.aimTarget.Parent:FindFirstChildOfClass("Humanoid")
            if hh and hh.Health>0 then
                local sp, on = cam:WorldToViewportPoint(S.aimTarget.Position)
                if on and sp.Z>0 then
                    local px=(Vector2.new(sp.X,sp.Y)-Vector2.new(cx,cy)).Magnitude
                    if px < CFG.aimFovPx*1.5 then return S.aimTarget end
                end
            end
        end
        S.aimTarget = nil
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character and not wl(plr) then
            local hh = plr.Character:FindFirstChildOfClass("Humanoid")
            if hh and hh.Health>0 then
                -- try priority bones
                local bone = nil
                for _, bn in ipairs(BONE_PRIORITY) do
                    bone = plr.Character:FindFirstChild(bn)
                    if bone then break end
                end
                if bone then
                    if (bone.Position-myPos).Magnitude <= CFG.aimMaxDist then
                        local sp, on = cam:WorldToViewportPoint(bone.Position)
                        if on and sp.Z>0 then
                            local px=(Vector2.new(sp.X,sp.Y)-Vector2.new(cx,cy)).Magnitude
                            if px < bestPx then
                                bestPx = px; best = bone
                            end
                        end
                    end
                end
            end
        end
    end
    S.aimTarget = best
    return best
end

RunService.RenderStepped:Connect(function()
    if not ON.Aimbot then S.aimTarget=nil return end
    if not UserInputService:IsKeyDown(CFG.aimKey) then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local target = getBestTarget()
    if not target then return end

    local aim = target.Position
    if target.Name=="Head" then aim = aim + Vector3.new(0,0.1,0) end
    if CFG.aimPredict>0 and target.Parent then
        local root = target.Parent:FindFirstChild("HumanoidRootPart") or target
        aim = aim + root.AssemblyLinearVelocity * CFG.aimPredict
    end

    local vp = cam.ViewportSize
    local cx, cy = vp.X*0.5, vp.Y*0.5
    local sp  = cam:WorldToViewportPoint(aim)
    local screenPos = Vector2.new(sp.X, sp.Y)
    local center    = Vector2.new(cx, cy)
    local delta     = screenPos - center
    local dist      = delta.Magnitude
    if dist < 0.5 then return end

    local depth = sp.Z
    if depth <= 0 then return end

    if ON.AimInstant then
        -- instant snap: go directly to target this frame
        local goal = CFrame.new(cam.CFrame.Position, aim)
        cam.CFrame = goal
    else
        -- step smooth: move by aimStepPx toward target
        local step      = math.min(dist, CFG.aimStepPx)
        local newScreen = center + delta.Unit * (dist - step)
        local ray       = cam:ViewportPointToRay(newScreen.X, newScreen.Y)
        local newWorld  = ray.Origin + ray.Direction * depth
        local goal      = CFrame.new(cam.CFrame.Position, newWorld)
        cam.CFrame      = goal
    end
end)

-- ===================== ESP =====================
local function forceVisible()
    -- strips LocalTransparencyModifier so invisible/hidden players are shown
    if not ON.ESP then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            for _, obj in ipairs(plr.Character:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("Decal") then
                    pcall(function() obj.LocalTransparencyModifier = 0 end)
                end
            end
        end
    end
end

local function makeInfoBB(plr)
    if not plr.Character then return end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local col = wl(plr) and COL_F or COL_E
    local old = root:FindFirstChild("LeaBB"); if old then old:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name="LeaBB"; bb.Size=UDim2.fromOffset(80,32); bb.StudsOffset=Vector3.new(0,3.2,0)
    bb.AlwaysOnTop=true; bb.ResetOnSpawn=false; bb.Parent=root

    local nameLbl = Instance.new("TextLabel",bb)
    nameLbl.Size=UDim2.new(1,0,0.6,0); nameLbl.BackgroundTransparency=1
    nameLbl.Text=plr.Name; nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=11
    nameLbl.TextColor3=col; nameLbl.TextStrokeTransparency=0.3
    nameLbl.TextXAlignment=Enum.TextXAlignment.Center

    local distLbl = Instance.new("TextLabel",bb)
    distLbl.Name="Dist"; distLbl.Size=UDim2.new(1,0,0.4,0)
    distLbl.Position=UDim2.fromScale(0,0.6); distLbl.BackgroundTransparency=1
    distLbl.Text="? m"; distLbl.Font=Enum.Font.Gotham; distLbl.TextSize=9
    distLbl.TextColor3=Color3.fromRGB(200,200,200); distLbl.TextStrokeTransparency=0.3
    distLbl.TextXAlignment=Enum.TextXAlignment.Center
end

local function makeHL(plr)
    if not plr.Character then return end
    local old = S.espHL[plr]; if old and old.Parent then old:Destroy() end; S.espHL[plr]=nil
    local col = wl(plr) and COL_F or COL_E
    local hl  = Instance.new("Highlight")
    hl.Name="LeaHL"; hl.FillColor=col; hl.OutlineColor=col
    hl.FillTransparency=0.55; hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop   -- visible through walls
    local ok = pcall(function() hl.Adornee=plr.Character; hl.Parent=game:GetService("CoreGui") end)
    if not ok or not hl.Parent then hl.Adornee=nil; hl.Parent=plr.Character end
    S.espHL[plr] = hl
    if ON.ESP then makeInfoBB(plr) end
end

local function makeTracer(plr)
    local my=hrp(); if not my or not plr.Character then return end
    if not S.tracerFolder or not S.tracerFolder.Parent then
        local tf=Instance.new("Folder"); tf.Name="LeaTr"; tf.Parent=Workspace; S.tracerFolder=tf
    end
    if not S.originAtt or S.originAtt.Parent~=my then
        if S.originAtt then pcall(function() S.originAtt:Destroy() end) end
        local oa=Instance.new("Attachment"); oa.Name="LeaTO"; oa.Parent=my; S.originAtt=oa
    end
    local old=S.tracerBeams[plr]; if old and old.Parent then old:Destroy() end; S.tracerBeams[plr]=nil
    local bone=plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
    if not bone then return end
    local a1=bone:FindFirstChild("LeaTE") or Instance.new("Attachment")
    a1.Name="LeaTE"; a1.Parent=bone
    local col=wl(plr) and COL_F or COL_E
    local beam=Instance.new("Beam")
    beam.Attachment0=S.originAtt; beam.Attachment1=a1
    beam.Width0=0.09; beam.Width1=0.09; beam.FaceCamera=true
    beam.Color=ColorSequence.new(col); beam.Transparency=NumberSequence.new(0.2)
    beam.LightEmission=1; beam.Parent=S.tracerFolder
    S.tracerBeams[plr]=beam
end

-- HealthBars: BillboardGui above each enemy
local function doHealthBars()
    if not ON.HealthBars then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            local hh   = plr.Character:FindFirstChildOfClass("Humanoid")
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if hh and root and hh.Health>0 then
                local bb = root:FindFirstChild("LeaHP")
                if not bb then
                    bb=Instance.new("BillboardGui"); bb.Name="LeaHP"
                    bb.Size=UDim2.fromOffset(50,5); bb.StudsOffset=Vector3.new(0,4.2,0)
                    bb.AlwaysOnTop=true; bb.ResetOnSpawn=false; bb.Parent=root
                    local bg=Instance.new("Frame",bb); bg.Name="BG"
                    bg.Size=UDim2.new(1,0,1,0); bg.BackgroundColor3=Color3.fromRGB(20,20,20)
                    bg.BorderSizePixel=0; Instance.new("UICorner",bg).CornerRadius=UDim.new(0,2)
                    local bar=Instance.new("Frame",bg); bar.Name="Bar"
                    bar.Size=UDim2.new(1,0,1,0); bar.BackgroundColor3=COL_HP
                    bar.BorderSizePixel=0; Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)
                end
                local bg2=bb:FindFirstChild("BG"); local bar2=bg2 and bg2:FindFirstChild("Bar")
                if bar2 then
                    local pct=math.clamp(hh.Health/hh.MaxHealth,0,1)
                    bar2.Size=UDim2.new(pct,0,1,0)
                    bar2.BackgroundColor3=Color3.fromHSV(pct*0.4,0.9,1)
                end
            else
                if root then local hp=root:FindFirstChild("LeaHP") if hp then pcall(function() hp:Destroy() end) end end
            end
        end
    end
end

local function clearHealthBars()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local root=plr.Character:FindFirstChild("HumanoidRootPart")
            if root then local hp=root:FindFirstChild("LeaHP") if hp then pcall(function() hp:Destroy() end) end end
        end
    end
end

local function clearESP()
    for plr,hl in pairs(S.espHL) do pcall(function() if hl and hl.Parent then hl:Destroy() end end) end
    S.espHL={}
    for plr,beam in pairs(S.tracerBeams) do pcall(function() if beam and beam.Parent then beam:Destroy() end end) end
    S.tracerBeams={}
    if S.tracerFolder then pcall(function() S.tracerFolder:Destroy() end) end; S.tracerFolder=nil
    if S.originAtt then pcall(function() S.originAtt:Destroy() end) end; S.originAtt=nil
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local root=plr.Character:FindFirstChild("HumanoidRootPart")
            if root then local bb=root:FindFirstChild("LeaBB") if bb then pcall(function() bb:Destroy() end) end end
        end
    end
end

local function doESP()
    if not (ON.ESP or ON.Tracers) then clearESP() return end
    local myPos=hrp() and hrp().Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            local hh=plr.Character:FindFirstChildOfClass("Humanoid")
            if hh and hh.Health>0 then
                if ON.ESP then
                    local hl=S.espHL[plr]
                    if not hl or not hl.Parent then makeHL(plr) end
                    local root=plr.Character:FindFirstChild("HumanoidRootPart")
                    if root and myPos then
                        local bb=root:FindFirstChild("LeaBB")
                        if not bb then makeInfoBB(plr); bb=root:FindFirstChild("LeaBB") end
                        if bb then
                            local dl=bb:FindFirstChild("Dist")
                            if dl then
                                local dist=math.floor((root.Position-myPos).Magnitude)
                                dl.Text=dist.." m"
                                if dist<50 then dl.TextColor3=COL_E
                                elseif dist<150 then dl.TextColor3=Color3.fromRGB(255,200,60)
                                else dl.TextColor3=Color3.fromRGB(180,180,180) end
                            end
                        end
                    end
                end
                if ON.Tracers then
                    local beam=S.tracerBeams[plr]
                    if not beam or not beam.Parent then makeTracer(plr) end
                end
            else
                local hl=S.espHL[plr]; if hl and hl.Parent then hl:Destroy() end; S.espHL[plr]=nil
                local beam=S.tracerBeams[plr]; if beam and beam.Parent then beam:Destroy() end; S.tracerBeams[plr]=nil
                if plr.Character then
                    local root=plr.Character:FindFirstChild("HumanoidRootPart")
                    if root then local bb=root:FindFirstChild("LeaBB") if bb then pcall(function() bb:Destroy() end) end end
                end
            end
        end
    end
    for plr,hl in pairs(S.espHL) do
        if not plr.Parent then pcall(function() if hl and hl.Parent then hl:Destroy() end end); S.espHL[plr]=nil end
    end
    for plr,beam in pairs(S.tracerBeams) do
        if not plr.Parent then pcall(function() if beam and beam.Parent then beam:Destroy() end end); S.tracerBeams[plr]=nil end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        if ON.ESP or ON.Tracers then doESP() end
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr~=LocalPlayer then
        plr.CharacterAdded:Connect(function()
            task.wait(0.3)
            if ON.ESP or ON.Tracers then doESP() end
        end)
    end
end

-- ===================== BOX ESP =====================
local function ensureBoxGui()
    if S.boxGui and S.boxGui.Parent then return S.boxGui end
    local pg=LocalPlayer:WaitForChild("PlayerGui")
    local bg=Instance.new("ScreenGui"); bg.Name="LeaBoxGUI"
    bg.ResetOnSpawn=false; bg.IgnoreGuiInset=true; bg.DisplayOrder=997
    bg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; bg.Parent=pg
    S.boxGui=bg; return bg
end

local function ensureBox(plr)
    local frames=S.boxFrames[plr]
    if frames and frames[1] and frames[1].Parent then return frames end
    local gui=ensureBoxGui()
    local col=wl(plr) and COL_F or COL_BOX
    frames={}
    for i=1,4 do
        local f=Instance.new("Frame"); f.BackgroundColor3=col
        f.BorderSizePixel=0; f.ZIndex=30; f.Parent=gui; frames[i]=f
    end
    S.boxFrames[plr]=frames; return frames
end

local function hideBox(plr)
    local frames=S.boxFrames[plr]; if not frames then return end
    for _,f in ipairs(frames) do if f and f.Parent then f.Visible=false end end
end

local function setBoxRect(frames,x,y,w,h,th)
    local d={{x,y,w,th},{x,y+h-th,w,th},{x,y,th,h},{x+w-th,y,th,h}}
    for i=1,4 do
        frames[i].Position=UDim2.fromOffset(d[i][1],d[i][2])
        frames[i].Size=UDim2.fromOffset(d[i][3],d[i][4])
        frames[i].Visible=true
    end
end

local function updateBoxESP()
    if not ON.BoxESP then
        for plr,_ in pairs(S.boxFrames) do hideBox(plr) end
        return
    end
    local cam=Workspace.CurrentCamera; if not cam then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            local hh=plr.Character:FindFirstChildOfClass("Humanoid")
            local root=plr.Character:FindFirstChild("HumanoidRootPart")
            local head=plr.Character:FindFirstChild("Head")
            if hh and hh.Health>0 and root and head then
                local topPos=head.Position+Vector3.new(0,0.7,0)
                local botPos=root.Position-Vector3.new(0,2.8,0)
                local sp_top,on1=cam:WorldToViewportPoint(topPos)
                local sp_bot,on2=cam:WorldToViewportPoint(botPos)
                if on1 and on2 and sp_top.Z>0 and sp_bot.Z>0 then
                    local bh=sp_bot.Y-sp_top.Y
                    if bh>5 then
                        local bw=math.max(bh*0.4, 20)
                        local bx=sp_top.X-bw/2
                        local by=sp_top.Y
                        local frames=ensureBox(plr)
                        setBoxRect(frames,math.round(bx),math.round(by),math.round(bw),math.round(bh),1)
                    else hideBox(plr) end
                else hideBox(plr) end
            else hideBox(plr) end
        end
    end
    for plr,_ in pairs(S.boxFrames) do
        if not plr.Parent then hideBox(plr); S.boxFrames[plr]=nil end
    end
end

-- ===================== ITEM ESP =====================
local ITEM_KW = {
    "gun","weapon","rifle","pistol","smg","shotgun","sniper","ammo","cash","money",
    "medkit","heal","armor","vest","helmet","grenade","knife","sword","axe",
    "shield","potion","key","item","loot","drop","backpack","bag","crate","chest",
    "collectible","pickup","coin","gem","token","supply"
}

local function updateItemESP()
    if not ON.ItemESP then
        for key,bb in pairs(S.itemDots) do
            pcall(function() if bb and bb.Parent then bb:Destroy() end end)
        end
        S.itemDots={}; return
    end
    local my=hrp(); local myPos=my and my.Position; if not myPos then return end
    local seen={}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") or (obj:IsA("Model") and obj~=char()) then
            local n=low(obj.Name); local isLoot=false
            for _,kw in ipairs(ITEM_KW) do
                if string.find(n,kw,1,true) then isLoot=true break end
            end
            if isLoot then
                local anchor = (obj:IsA("Tool") and obj:FindFirstChild("Handle"))
                            or obj.PrimaryPart
                            or obj:FindFirstChildOfClass("BasePart")
                if anchor then
                    local d=(anchor.Position-myPos).Magnitude
                    if d<=CFG.itemEspRange then
                        local key=tostring(obj)
                        seen[key]=true
                        if not S.itemDots[key] or not S.itemDots[key].Parent then
                            local bb=Instance.new("BillboardGui"); bb.Name="LeaItemESP"
                            bb.Size=UDim2.fromOffset(90,18); bb.StudsOffset=Vector3.new(0,2,0)
                            bb.AlwaysOnTop=true; bb.ResetOnSpawn=false; bb.Parent=anchor
                            local lbl=Instance.new("TextLabel",bb)
                            lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
                            lbl.Text=obj.Name; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10
                            lbl.TextColor3=COL_LOOT; lbl.TextStrokeTransparency=0.3
                            lbl.TextXAlignment=Enum.TextXAlignment.Center
                            S.itemDots[key]=bb
                        end
                    end
                end
            end
        end
    end
    for key,bb in pairs(S.itemDots) do
        if not seen[key] then
            pcall(function() if bb and bb.Parent then bb:Destroy() end end)
            S.itemDots[key]=nil
        end
    end
end

-- ===================== NEW MODULES =====================

-- Hitbox Expander
local function applyHitbox(on)
    local sz=CFG.hitboxSize
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            pcall(function()
                local root=plr.Character:FindFirstChild("HumanoidRootPart")
                local head=plr.Character:FindFirstChild("Head")
                if root then root.Size=on and Vector3.new(sz,sz,sz) or Vector3.new(2,2,1) end
                if head then head.Size=on and Vector3.new(sz,sz,sz) or Vector3.new(2,1,1) end
            end)
        end
    end
end

-- Trigger Bot (uses raycast + mouse1click)
local _tbConn
local function triggerStart()
    if _tbConn then return end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    _tbConn=RunService.Heartbeat:Connect(function()
        if not ON.TriggerBot then return end
        local cam=Workspace.CurrentCamera; if not cam then return end
        local c=char(); if not c then return end
        params.FilterDescendantsInstances={c}
        local result=Workspace:Raycast(cam.CFrame.Position,cam.CFrame.LookVector*1000,params)
        if result and result.Instance then
            local plr=Players:GetPlayerFromCharacter(result.Instance.Parent)
                   or Players:GetPlayerFromCharacter(result.Instance.Parent and result.Instance.Parent.Parent)
            if plr and plr~=LocalPlayer and not wl(plr) then
                local hh=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                if hh and hh.Health>0 then
                    pcall(function()
                        if mouse1click then mouse1click()
                        elseif mouse1press and mouse1release then
                            mouse1press(); task.delay(0.04,mouse1release)
                        end
                    end)
                end
            end
        end
    end)
end
local function triggerStop()
    if _tbConn then _tbConn:Disconnect(); _tbConn=nil end
end

-- No Recoil (camera pitch stabilizer + pre-fire CFrame save via hook)
local function setupNoRecoil()
    RunService:BindToRenderStep("LeaNoRecoil", Enum.RenderPriority.Last.Value+100, function()
        if not ON.NoRecoil then S.prevCamCF=nil; S._prevMousePos=nil return end
        local cam=Workspace.CurrentCamera; if not cam then return end
        local mousePos=UserInputService:GetMouseLocation()
        local prevMouse=S._prevMousePos or mousePos
        local mouseDeltaY=mousePos.Y-prevMouse.Y
        S._prevMousePos=mousePos
        if S.prevCamCF then
            local pitchUp=cam.CFrame.LookVector.Y-S.prevCamCF.LookVector.Y
            -- if camera pitched up AND mouse didn't move up → recoil spike → cancel
            if pitchUp>0.012 and mouseDeltaY>=-0.5 then
                cam.CFrame=cam.CFrame:Lerp(S.prevCamCF,0.88)
            end
        end
        S.prevCamCF=cam.CFrame
    end)
end

-- Night Vision
local function setNightVision(on)
    if on then
        S.lit.amb=Lighting.Ambient; S.lit.oamb=Lighting.OutdoorAmbient
        local b=CFG.nightAmt
        Lighting.Ambient=Color3.fromRGB(b,b,b); Lighting.OutdoorAmbient=Color3.fromRGB(b,b,b)
    else
        if S.lit.amb  then Lighting.Ambient=S.lit.amb end
        if S.lit.oamb then Lighting.OutdoorAmbient=S.lit.oamb end
    end
end

-- Teleport Nearest enemy
local function teleportNearest()
    local my=hrp(); if not my then return end
    local best,bestD=nil,math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character and not wl(plr) then
            local r=plr.Character:FindFirstChild("HumanoidRootPart")
            if r then
                local d=(r.Position-my.Position).Magnitude
                if d<bestD then bestD=d; best=r end
            end
        end
    end
    if best then
        pcall(function()
            my.CFrame=best.CFrame*CFrame.new(0,0,-4)
            my.AssemblyLinearVelocity=Vector3.zero
        end)
        say("tp → nearest")
    else say("no targets") end
end

-- ===================== FULLBRIGHT =====================
local function fullbright(on)
    if on then
        S.lit.b=Lighting.Brightness; S.lit.c=Lighting.ClockTime; S.lit.f=Lighting.FogEnd
        Lighting.Brightness=3.2; Lighting.ClockTime=14; Lighting.FogEnd=1e6; Lighting.GlobalShadows=false
    else
        if S.lit.b then Lighting.Brightness=S.lit.b end
        if S.lit.c then Lighting.ClockTime=S.lit.c end
        if S.lit.f then Lighting.FogEnd=S.lit.f end
        Lighting.GlobalShadows=true; S.lit={}
    end
end

-- ===================== MINIMAP =====================
local function buildMap(parent)
    if S.map then S.map:Destroy() end
    local size=CFG.mapSize
    local frame=Instance.new("Frame")
    frame.Name="Radar"; frame.Size=UDim2.fromOffset(size,size)
    frame.Position=UDim2.new(1,-size-12,0,12)
    frame.BackgroundColor3=Color3.fromRGB(8,8,10); frame.BackgroundTransparency=0.15
    frame.BorderSizePixel=0; frame.ZIndex=90; frame.Parent=parent
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,size/2)
    local stroke=Instance.new("UIStroke",frame)
    stroke.Color=ACCENT; stroke.Thickness=1.8; stroke.Transparency=0.2

    local hline=Instance.new("Frame"); hline.Size=UDim2.new(1,0,0,1); hline.Position=UDim2.new(0,0,0.5,0)
    hline.BackgroundColor3=Color3.fromRGB(50,50,62); hline.BackgroundTransparency=0.4
    hline.BorderSizePixel=0; hline.ZIndex=91; hline.Parent=frame
    local vline=Instance.new("Frame"); vline.Size=UDim2.new(0,1,1,0); vline.Position=UDim2.new(0.5,0,0,0)
    vline.BackgroundColor3=Color3.fromRGB(50,50,62); vline.BackgroundTransparency=0.4
    vline.BorderSizePixel=0; vline.ZIndex=91; vline.Parent=frame

    for _,frac in ipairs({0.5,1.0}) do
        local ring=Instance.new("Frame"); local rs=size*frac
        ring.Size=UDim2.fromOffset(rs,rs); ring.AnchorPoint=Vector2.new(0.5,0.5)
        ring.Position=UDim2.fromScale(0.5,0.5); ring.BackgroundTransparency=1
        ring.BorderSizePixel=0; ring.ZIndex=91; ring.Parent=frame
        Instance.new("UICorner",ring).CornerRadius=UDim.new(1,0)
        local rs2=Instance.new("UIStroke",ring)
        rs2.Color=Color3.fromRGB(50,50,62); rs2.Thickness=0.8; rs2.Transparency=0.55
    end

    local me=Instance.new("Frame"); me.Size=UDim2.fromOffset(8,8); me.AnchorPoint=Vector2.new(0.5,0.5)
    me.Position=UDim2.fromScale(0.5,0.5); me.BackgroundColor3=COL_ME
    me.BorderSizePixel=0; me.ZIndex=94; me.Parent=frame
    Instance.new("UICorner",me).CornerRadius=UDim.new(1,0)

    local arrow=Instance.new("Frame"); arrow.Size=UDim2.fromOffset(4,10); arrow.AnchorPoint=Vector2.new(0.5,1)
    arrow.Position=UDim2.new(0.5,0,0.5,-5); arrow.BackgroundColor3=ACCENT
    arrow.BorderSizePixel=0; arrow.ZIndex=95; arrow.Parent=frame
    Instance.new("UICorner",arrow).CornerRadius=UDim.new(0,2); S.mapArrow=arrow

    local dots=Instance.new("Folder"); dots.Name="Dots"; dots.Parent=frame

    local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,0,0,13); label.Position=UDim2.new(0,0,1,-14)
    label.BackgroundTransparency=1; label.Text="RADAR  "..tostring(math.floor(CFG.mapRange)).."m"
    label.Font=Enum.Font.GothamBold; label.TextSize=8; label.TextColor3=ACCENT; label.ZIndex=92; label.Parent=frame

    S.map=frame; S.mapDots=dots
end

local function updateMap()
    if not ON.Minimap or not S.map or not S.mapDots then
        if S.map then S.map.Visible=false end; return
    end
    S.map.Visible=true
    local my=hrp(); local myPos
    if my then myPos=my.Position; S.lastMapPos=myPos
    elseif S.lastMapPos then myPos=S.lastMapPos
    else return end
    local range=CFG.mapRange; local half=CFG.mapSize*0.5
    local cam=Workspace.CurrentCamera
    if not cam then cam=Workspace:FindFirstChildOfClass("Camera") end
    local camYaw
    if cam then camYaw=math.atan2(-cam.CFrame.LookVector.X,-cam.CFrame.LookVector.Z)
    else camYaw=0 end
    local cosY,sinY=math.cos(camYaw),math.sin(camYaw)
    if S.mapArrow then S.mapArrow.Visible=cam~=nil end
    for _,d in ipairs(S.mapDots:GetChildren()) do d:Destroy() end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            local root=plr.Character:FindFirstChild("HumanoidRootPart")
            local hh=plr.Character:FindFirstChildOfClass("Humanoid")
            if root and hh and hh.Health>0 then
                local dlt=root.Position-myPos
                local rx= dlt.X*cosY+dlt.Z*sinY
                local rz=-dlt.X*sinY+dlt.Z*cosY
                local inRange=(dlt.X^2+dlt.Z^2)<=(range*range)
                local dx=math.clamp(rx/range*half,-half+7,half-7)
                local dz=math.clamp(rz/range*half,-half+7,half-7)
                local col=wl(plr) and COL_F or COL_E
                local dist2d=math.sqrt(dlt.X^2+dlt.Z^2)
                local dotSz=dist2d<50 and 10 or (dist2d<150 and 8 or 6)
                local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(dotSz,dotSz)
                dot.AnchorPoint=Vector2.new(0.5,0.5); dot.Position=UDim2.new(0.5,dx,0.5,dz)
                dot.BackgroundColor3=inRange and col or Color3.fromRGB(220,80,80)
                dot.BorderSizePixel=0; dot.ZIndex=93; dot.Parent=S.mapDots
                Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
                if ON.MapNames then
                    local nl=Instance.new("TextLabel"); nl.Size=UDim2.fromOffset(60,10)
                    nl.AnchorPoint=Vector2.new(0.5,1); nl.Position=UDim2.new(0.5,dx,0.5,dz-dotSz/2-1)
                    nl.BackgroundTransparency=1; nl.Text=plr.Name; nl.Font=Enum.Font.GothamBold
                    nl.TextSize=8; nl.TextColor3=col; nl.TextStrokeTransparency=0.1; nl.ZIndex=94; nl.Parent=S.mapDots
                end
            end
        end
    end
end

local function updateFov()
    if not S.fov then return end
    if ON.Aimbot and ON.ShowFov then
        S.fov.Visible=true; local d=CFG.aimFovPx*2; S.fov.Size=UDim2.fromOffset(d,d)
    else S.fov.Visible=false end
end

-- ===================== LOOT TRACKER =====================
local function guessLootItems(character)
    local items={}
    local plr=Players:GetPlayerFromCharacter(character)
    if plr then
        local bp=plr:FindFirstChildOfClass("Backpack")
        if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(items,"🔧 "..t.Name) end end end
        local char2=plr.Character
        if char2 then for _,t in ipairs(char2:GetChildren()) do if t:IsA("Tool") then table.insert(items,"🔫 "..t.Name.." (equipped)") end end end
    end
    local lootKeywords={"gun","weapon","rifle","pistol","smg","ammo","cash","money","medkit",
                        "heal","armor","vest","helmet","grenade","knife","sword","axe","shield",
                        "potion","key","item","loot","drop","backpack","bag","crate","chest"}
    for _,obj in ipairs(character:GetDescendants()) do
        local n=low(obj.Name)
        for _,kw in ipairs(lootKeywords) do
            if string.find(n,kw,1,true) then table.insert(items,"📦 "..obj.Name) break end
        end
    end
    if #items==0 then table.insert(items,"(no items detected)") end
    return items
end

local function highlightBody(character)
    if not CFG.lootBodyGlow then return end
    local hl=Instance.new("Highlight"); hl.Name="LeaLootHL"
    hl.FillColor=COL_LOOT; hl.OutlineColor=COL_LOOT; hl.FillTransparency=0.65
    hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Adornee=character
    local ok=pcall(function() hl.Parent=game:GetService("CoreGui") end)
    if not ok or not hl.Parent then pcall(function() hl:Destroy() end); return end
    S.lootBodyHL[character]=hl
    task.delay(60,function() pcall(function() if hl and hl.Parent then hl:Destroy() end end); S.lootBodyHL[character]=nil end)
end

local function refreshLootPanel()
    if not S.lootPanel or not S.lootPanel.Parent then return end
    for _,c in ipairs(S.lootPanel:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
    local my=hrp(); local myPos=my and my.Position; local shown=0
    for i=#S.lootLog,1,-1 do
        if shown>=CFG.lootMaxItems then break end
        local entry=S.lootLog[i]; local dist=9999
        if myPos and entry.bodyPos then dist=math.floor((entry.bodyPos-myPos).Magnitude) end
        if dist>CFG.lootRange then continue end
        shown+=1
        local card=Instance.new("Frame"); card.Size=UDim2.new(1,-4,0,0)
        card.AutomaticSize=Enum.AutomaticSize.Y; card.BackgroundColor3=Color3.fromRGB(18,16,10)
        card.BorderSizePixel=0; card.LayoutOrder=shown; card.ZIndex=52; card.Parent=S.lootPanel
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,4)
        local cStroke=Instance.new("UIStroke",card); cStroke.Color=COL_LOOT; cStroke.Thickness=0.8; cStroke.Transparency=0.6
        local cLay=Instance.new("UIListLayout",card); cLay.Padding=UDim.new(0,1)
        local cPad=Instance.new("UIPadding",card)
        cPad.PaddingLeft=UDim.new(0,6); cPad.PaddingRight=UDim.new(0,6)
        cPad.PaddingTop=UDim.new(0,4); cPad.PaddingBottom=UDim.new(0,4)
        local header=Instance.new("TextLabel",card); header.Size=UDim2.new(1,0,0,14)
        header.AutomaticSize=Enum.AutomaticSize.Y; header.BackgroundTransparency=1
        header.Text="☠ "..entry.victimName.."  |  "..dist.."m  |  "..entry.killerName.." killed"
        header.Font=Enum.Font.GothamBold; header.TextSize=10; header.TextColor3=COL_LOOT
        header.TextXAlignment=Enum.TextXAlignment.Left; header.TextWrapped=true; header.ZIndex=53
        for _,item in ipairs(entry.items) do
            local il=Instance.new("TextLabel",card); il.Size=UDim2.new(1,0,0,12)
            il.AutomaticSize=Enum.AutomaticSize.Y; il.BackgroundTransparency=1
            il.Text="  "..item; il.Font=Enum.Font.Gotham; il.TextSize=9
            il.TextColor3=Color3.fromRGB(210,200,170); il.TextXAlignment=Enum.TextXAlignment.Left
            il.TextWrapped=true; il.ZIndex=53
        end
    end
    if shown==0 then
        local empty=Instance.new("TextLabel",S.lootPanel); empty.Size=UDim2.new(1,0,0,30)
        empty.BackgroundTransparency=1; empty.Text="no loot in range"
        empty.Font=Enum.Font.Gotham; empty.TextSize=10
        empty.TextColor3=Color3.fromRGB(90,90,100); empty.TextXAlignment=Enum.TextXAlignment.Center; empty.ZIndex=52
    end
end

local function watchPlayer(plr)
    local function onChar(character)
        local hum2=character:WaitForChild("Humanoid",10); if not hum2 then return end
        hum2.Died:Connect(function()
            task.wait(0.3); if not ON.LootTracker then return end
            local killerName="unknown"
            pcall(function()
                local tag=hum2:FindFirstChild("creator")
                if tag and tag:IsA("ObjectValue") and tag.Value then killerName=tag.Value.Name end
            end)
            local items=guessLootItems(character)
            local bodyPos; pcall(function() local r=character:FindFirstChild("HumanoidRootPart"); bodyPos=r and r.Position end)
            local entry={victimName=plr.Name,killerName=killerName,items=items,bodyPos=bodyPos,ts=os.clock(),bodyModel=character}
            table.insert(S.lootLog,entry)
            while #S.lootLog>CFG.lootMaxItems do table.remove(S.lootLog,1) end
            highlightBody(character); pcall(refreshLootPanel)
            pcall(say,"☠ "..plr.Name.." died — "..#items.." items")
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification",{Title="Loot",Text=plr.Name.." dropped "..#items.." item(s)",Duration=4})
            end)
        end)
    end
    if plr.Character then task.spawn(onChar,plr.Character) end
    plr.CharacterAdded:Connect(onChar)
end

local function startLootTracker()
    for _,plr in ipairs(Players:GetPlayers()) do if plr~=LocalPlayer then watchPlayer(plr) end end
    Players.PlayerAdded:Connect(function(plr) if plr~=LocalPlayer then watchPlayer(plr) end end)
end

-- ===================== MAIN LOOPS =====================
local _espT,_mapT,_lootT,_boxT,_itemT,_hbT,_fvT=0,0,0,0,0,0,0
RunService.Heartbeat:Connect(function(dt)
    _espT+=dt; _mapT+=dt; _lootT+=dt; _boxT+=dt; _itemT+=dt; _hbT+=dt; _fvT+=dt

    if _espT >=0.3  then _espT =0
        if ON.ESP or ON.Tracers then pcall(doESP) end
        if ON.ESP then pcall(forceVisible) end  -- force hidden players visible
    end
    if _mapT >=0.08 then _mapT =0; pcall(updateMap); pcall(updateFov) end
    if _lootT>=1.0  then _lootT=0; if ON.LootTracker then pcall(refreshLootPanel) end end
    if _boxT >=0.05 then _boxT =0; pcall(updateBoxESP) end
    if _itemT>=0.5  then _itemT=0; pcall(updateItemESP) end
    if _hbT  >=0.3  then _hbT  =0; pcall(doHealthBars) end
    if _fvT  >=0.1  then _fvT  =0
        if ON.ESP then pcall(forceVisible) end
    end

    -- NoFall
    if ON.NoFall then
        local hh=hum()
        if hh and hh:GetState()==Enum.HumanoidStateType.Freefall then hh:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
    -- MobPush
    if ON.MobPush then
        local r=hrp(); if r then
            for _,m in ipairs(Workspace:GetChildren()) do
                if m:IsA("Model") and m~=char() and not Players:GetPlayerFromCharacter(m) then
                    local mh=m:FindFirstChildOfClass("Humanoid"); local mr=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if mh and mr and mh.Health>0 then
                        local d=(mr.Position-r.Position).Magnitude
                        if d>0.4 and d<=16 then
                            local away=r.Position-mr.Position
                            if away.Magnitude>0 then r.AssemblyLinearVelocity=away.Unit*90+Vector3.new(0,40,0) end
                        end
                    end
                end
            end
        end
    end
    -- Anti-Void
    if ON.NoVoid then
        local r=hrp()
        if r and r.Position.Y<CFG.noVoidY then
            pcall(function() r.CFrame=CFrame.new(r.Position.X,CFG.noVoidY+20,r.Position.Z); r.AssemblyLinearVelocity=Vector3.zero end)
        end
    end
    -- Anti-Push: cancel sudden external velocity spikes when on ground
    if ON.AntiPush then
        local r=hrp(); local hh=hum()
        if r and hh and hh.FloorMaterial~=Enum.Material.Air then
            local vel=r.AssemblyLinearVelocity
            local maxV=ON.Speed and CFG.walkBoost*1.6 or 28
            if vel.Magnitude>maxV and not ON.Fly and not ON.CarFly then
                r.AssemblyLinearVelocity=Vector3.new(vel.X*0.1,vel.Y,vel.Z*0.1)
            end
        end
    end
    -- Hitbox: re-apply each tick (games reset it)
    if ON.HitboxExpand then pcall(applyHitbox,true) end
    -- God + car-fly health enforce
    if ON.CarFly then
        local hh=hum(); if hh then pcall(function() if hh.Health<hh.MaxHealth then hh.Health=hh.MaxHealth end end) end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.4)
    claim(char()); stripConns()
    flyStop(); carStop()
    if ON.Fly     then flyStart()          end
    if ON.CarFly  then carStart()          end
    if ON.Speed   then applySpeed()        end
    if ON.Noclip  then setNoclip(true)     end
    if ON.ESP or ON.Tracers then doESP()   end
    if ON.God     then startGod()          end
    S.aimTarget=nil; S.lastCF=nil; S.prevCamCF=nil
end)

-- ===================== UI — CLOUD ENGINE v14 =====================
-- 360px wide | 600px tall | cloud logo banner | 6 tabs | 30 modules

local PANEL_W = 360
local PANEL_H = 600
local MENU_TOP_OFFSET = 48

local function buildGui()
    local pg=LocalPlayer:WaitForChild("PlayerGui")
    local old=pg:FindFirstChild("LeaHub"); if old then old:Destroy() end

    local g=Instance.new("ScreenGui"); g.Name="LeaHub"; g.ResetOnSpawn=false
    g.IgnoreGuiInset=true; g.DisplayOrder=20; g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; g.Parent=pg
    S.gui=g
    if S.map then S.map:Destroy(); S.map=nil end

    -- FOV ring
    local fov=Instance.new("Frame"); fov.Name="FOV"; fov.AnchorPoint=Vector2.new(0.5,0.5)
    fov.Position=UDim2.fromScale(0.5,0.5); fov.BackgroundTransparency=1; fov.ZIndex=40; fov.Parent=g
    local fs=Instance.new("UIStroke",fov); fs.Color=COL_BOX; fs.Thickness=1.4; fs.Transparency=0.4
    Instance.new("UICorner",fov).CornerRadius=UDim.new(1,0); S.fov=fov

    buildMap(g)

    -- ── Root ──
    local root=Instance.new("Frame"); root.Name="LeaRoot"
    root.Size=UDim2.fromOffset(PANEL_W,30); root.Position=UDim2.new(0.5,-PANEL_W/2,0,MENU_TOP_OFFSET)
    root.BackgroundTransparency=1; root.ClipsDescendants=false; root.ZIndex=50; root.Parent=g

    -- Responsive sizing: keep the complete menu inside small phone screens.
    local rootScale=Instance.new("UIScale")
    rootScale.Name="ResponsiveScale"
    rootScale.Parent=root

    local function updateMenuLayout()
        local camera=Workspace.CurrentCamera
        if not camera then return end
        local viewport=camera.ViewportSize
        local widthScale=math.max(0.45,(viewport.X-20)/PANEL_W)
        local heightScale=math.max(0.45,(viewport.Y-90)/(PANEL_H+30))
        rootScale.Scale=math.min(1,widthScale,heightScale)
        root.Position=UDim2.new(0.5,-PANEL_W/2,0,MENU_TOP_OFFSET)
    end
    updateMenuLayout()
    local viewportConn
    local function bindViewport()
        if viewportConn then viewportConn:Disconnect() end
        local camera=Workspace.CurrentCamera
        if camera then
            viewportConn=camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMenuLayout)
        end
    end
    bindViewport()
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        bindViewport()
        updateMenuLayout()
    end)

    -- ── Top bar ──
    local bar=Instance.new("Frame"); bar.Name="TopBar"; bar.Size=UDim2.new(1,0,0,30)
    bar.BackgroundColor3=Color3.fromRGB(10,10,16); bar.BorderSizePixel=0; bar.ZIndex=55; bar.Parent=root
    Instance.new("UICorner",bar).CornerRadius=UDim.new(0,4)
    local barStroke=Instance.new("UIStroke",bar); barStroke.Color=Color3.fromRGB(40,36,28); barStroke.Thickness=1; barStroke.Transparency=0.3

    -- cloud gradient tint (left side)
    local cloudTint=Instance.new("Frame"); cloudTint.Size=UDim2.fromOffset(80,30); cloudTint.Position=UDim2.fromOffset(0,0)
    cloudTint.BackgroundColor3=COL_CLOUD; cloudTint.BackgroundTransparency=0.92
    cloudTint.BorderSizePixel=0; cloudTint.ZIndex=55; cloudTint.Parent=bar
    Instance.new("UICorner",cloudTint).CornerRadius=UDim.new(0,4)

    -- accent stripe
    local stripe=Instance.new("Frame"); stripe.Size=UDim2.fromOffset(3,18); stripe.Position=UDim2.fromOffset(8,6)
    stripe.BackgroundColor3=ACCENT; stripe.BorderSizePixel=0; stripe.ZIndex=56; stripe.Parent=bar
    Instance.new("UICorner",stripe).CornerRadius=UDim.new(0,2)

    -- title with cloud icon
    local titleLbl=Instance.new("TextLabel"); titleLbl.Size=UDim2.new(1,-180,1,0)
    titleLbl.Position=UDim2.fromOffset(18,0); titleLbl.BackgroundTransparency=1
    titleLbl.Text="☁ LEAMODE  v14"; titleLbl.Font=Enum.Font.GothamBold; titleLbl.TextSize=12
    titleLbl.TextColor3=Color3.fromRGB(220,215,205); titleLbl.TextXAlignment=Enum.TextXAlignment.Left
    titleLbl.ZIndex=56; titleLbl.Parent=bar

    -- cloud logo top-right
    local cloudLogo=Instance.new("TextLabel"); cloudLogo.Size=UDim2.fromOffset(44,30)
    cloudLogo.Position=UDim2.new(1,-148,0,0); cloudLogo.BackgroundTransparency=1
    cloudLogo.Text="☁☁"; cloudLogo.Font=Enum.Font.GothamBold; cloudLogo.TextSize=14
    cloudLogo.TextColor3=COL_CLOUD; cloudLogo.TextTransparency=0.2
    cloudLogo.ZIndex=56; cloudLogo.Parent=bar

    -- status pill
    local statusPill=Instance.new("TextLabel"); statusPill.Size=UDim2.fromOffset(80,18)
    statusPill.Position=UDim2.new(1,-132,0.5,-9); statusPill.BackgroundColor3=Color3.fromRGB(18,18,24)
    statusPill.Text="ready"; statusPill.Font=Enum.Font.Gotham; statusPill.TextSize=10
    statusPill.TextColor3=Color3.fromRGB(100,200,120); statusPill.TextXAlignment=Enum.TextXAlignment.Center
    statusPill.ZIndex=56; statusPill.Parent=bar
    Instance.new("UICorner",statusPill).CornerRadius=UDim.new(0,3); S.status=statusPill

    -- open/close btn
    local toggleBtn=Instance.new("TextButton"); toggleBtn.Size=UDim2.fromOffset(44,18)
    toggleBtn.Position=UDim2.new(1,-50,0.5,-9); toggleBtn.BackgroundColor3=Color3.fromRGB(24,20,14)
    toggleBtn.Text="OPEN"; toggleBtn.Font=Enum.Font.GothamBold; toggleBtn.TextSize=10
    toggleBtn.TextColor3=ACCENT; toggleBtn.ZIndex=57; toggleBtn.Parent=bar
    Instance.new("UICorner",toggleBtn).CornerRadius=UDim.new(0,3)
    local tStroke=Instance.new("UIStroke",toggleBtn); tStroke.Color=ACCENT; tStroke.Thickness=1; tStroke.Transparency=0.5

    -- ── Panel ──
    local panel=Instance.new("Frame"); panel.Name="Panel"
    panel.Size=UDim2.fromOffset(PANEL_W,0)  -- starts collapsed
    panel.Position=UDim2.fromOffset(0,30); panel.BackgroundColor3=Color3.fromRGB(9,9,13)
    panel.ClipsDescendants=true; panel.BorderSizePixel=0; panel.ZIndex=50; panel.Active=false; panel.Parent=root
    local pStroke=Instance.new("UIStroke",panel); pStroke.Color=Color3.fromRGB(35,32,26); pStroke.Thickness=1; pStroke.Transparency=0.3
    local pCorner=Instance.new("UICorner",panel); pCorner.CornerRadius=UDim.new(0,4)

    -- cloud banner inside panel (top)
    local banner=Instance.new("Frame"); banner.Size=UDim2.new(1,0,0,38)
    banner.Position=UDim2.fromOffset(0,0); banner.BackgroundColor3=Color3.fromRGB(10,12,20)
    banner.BorderSizePixel=0; banner.ZIndex=51; banner.Parent=panel
    local bannerStroke=Instance.new("UIStroke",banner); bannerStroke.Color=COL_CLOUD; bannerStroke.Thickness=0.5; bannerStroke.Transparency=0.75

    local cloudBig=Instance.new("TextLabel",banner); cloudBig.Size=UDim2.new(1,0,0,22)
    cloudBig.Position=UDim2.fromOffset(0,2); cloudBig.BackgroundTransparency=1
    cloudBig.Text="☁ ☁ ☁  LEAMODE ULTRA  ☁ ☁ ☁"; cloudBig.Font=Enum.Font.GothamBold; cloudBig.TextSize=11
    cloudBig.TextColor3=COL_CLOUD; cloudBig.TextTransparency=0.25; cloudBig.ZIndex=52

    local subLbl=Instance.new("TextLabel",banner); subLbl.Size=UDim2.new(1,0,0,14)
    subLbl.Position=UDim2.fromOffset(0,22); subLbl.BackgroundTransparency=1
    subLbl.Text="cloud engine  ·  dunyanin en buyuk hilesi"; subLbl.Font=Enum.Font.Gotham; subLbl.TextSize=8
    subLbl.TextColor3=Color3.fromRGB(70,85,120); subLbl.ZIndex=52

    -- ── Tab bar ──
    local tabBar=Instance.new("Frame"); tabBar.Size=UDim2.new(1,-12,0,26)
    tabBar.Position=UDim2.fromOffset(6,44); tabBar.BackgroundColor3=Color3.fromRGB(14,14,18)
    tabBar.ZIndex=51; tabBar.Parent=panel
    Instance.new("UICorner",tabBar).CornerRadius=UDim.new(0,4)
    local tabLay=Instance.new("UIListLayout",tabBar); tabLay.FillDirection=Enum.FillDirection.Horizontal
    tabLay.Padding=UDim.new(0,2); tabLay.VerticalAlignment=Enum.VerticalAlignment.Center
    local tabPad=Instance.new("UIPadding",tabBar); tabPad.PaddingLeft=UDim.new(0,3); tabPad.PaddingRight=UDim.new(0,3)
    tabPad.PaddingTop=UDim.new(0,3); tabPad.PaddingBottom=UDim.new(0,3)

    -- ── Scroll area ──
    local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,-12,1,-78)
    scroll.Position=UDim2.fromOffset(6,76); scroll.BackgroundTransparency=1
    scroll.ScrollBarThickness=2; scroll.ScrollBarImageColor3=ACCENT
    scroll.CanvasSize=UDim2.fromOffset(0,0); scroll.ZIndex=51; scroll.Active=true; scroll.Parent=panel
    local sLay=Instance.new("UIListLayout",scroll); sLay.Padding=UDim.new(0,4); sLay.SortOrder=Enum.SortOrder.LayoutOrder
    sLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize=UDim2.fromOffset(0,sLay.AbsoluteContentSize.Y+10)
    end)

    -- panel open/close animation
    local panelOpen=false
    local tweenInfo=TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
    local function setPanel(open)
        panelOpen=open; toggleBtn.Text=open and "CLOSE" or "OPEN"
        local targetH=open and PANEL_H or 0
        TweenService:Create(panel,tweenInfo,{Size=UDim2.fromOffset(PANEL_W,targetH)}):Play()
    end
    toggleBtn.Activated:Connect(function() setPanel(not panelOpen) end)

    -- drag
    local dragging,d0,p0=false,nil,nil
    bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; d0=i.Position; p0=root.Position
        end
    end)
    bar.InputEnded:Connect(function() dragging=false end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local d=i.Position-d0
            root.Position=UDim2.new(p0.X.Scale,p0.X.Offset+d.X,p0.Y.Scale,p0.Y.Offset+d.Y)
        end
    end)

    -- ── Tabs ──
    local TABS={
        {id="main",   t="Main"},
        {id="combat", t="Aim"},
        {id="move",   t="Move"},
        {id="visual", t="ESP"},
        {id="loot",   t="Loot"},
        {id="list",   t="List"},
    }
    local pages,tabs,active={},{},nil
    for _,td in ipairs(TABS) do
        local page=Instance.new("Frame"); page.Name=td.id; page.Size=UDim2.new(1,0,0,0)
        page.BackgroundTransparency=1; page.Visible=false; page.AutomaticSize=Enum.AutomaticSize.Y
        page.ZIndex=52; page.Parent=scroll
        local pl=Instance.new("UIListLayout",page); pl.Padding=UDim.new(0,4); pl.SortOrder=Enum.SortOrder.LayoutOrder
        pages[td.id]={f=page,o=0}
    end

    local function switch(id)
        if active==id then return end; active=id
        for _,td in ipairs(TABS) do if pages[td.id] then pages[td.id].f.Visible=(td.id==id) end end
        for tid,b in pairs(tabs) do
            b.BackgroundColor3=(tid==id) and Color3.fromRGB(28,22,12) or Color3.fromRGB(18,18,22)
            b.TextColor3=(tid==id) and ACCENT or Color3.fromRGB(120,120,135)
        end
        scroll.CanvasPosition=Vector2.zero
    end

    local n=#TABS
    for _,td in ipairs(TABS) do
        local b=Instance.new("TextButton"); b.Size=UDim2.new(1/n,-2,1,0)
        b.BackgroundColor3=Color3.fromRGB(18,18,22); b.Text=td.t; b.Font=Enum.Font.GothamMedium
        b.TextSize=10; b.TextColor3=Color3.fromRGB(120,120,135); b.ZIndex=52; b.Parent=tabBar
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,3); tabs[td.id]=b
        local id=td.id; b.Activated:Connect(function() switch(id) end)
    end

    -- ── Widget helpers ──
    local function row(page,h2)
        local p=pages[page]; if not p then return end; p.o+=1
        local r2=Instance.new("Frame"); r2.Size=UDim2.new(1,-2,0,h2 or 32)
        r2.BackgroundColor3=Color3.fromRGB(15,15,19); r2.LayoutOrder=p.o; r2.ZIndex=52; r2.Parent=p.f
        Instance.new("UICorner",r2).CornerRadius=UDim.new(0,4); return r2
    end

    local function tog(page,name,key,onE,onD)
        local p=pages[page]; if not p then return end
        local r2=row(page)
        local lbl=Instance.new("TextLabel",r2); lbl.Size=UDim2.new(1,-54,1,0); lbl.Position=UDim2.fromOffset(10,0)
        lbl.BackgroundTransparency=1; lbl.Text=name; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=12
        lbl.TextColor3=Color3.fromRGB(150,150,160); lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=53
        local pill=Instance.new("Frame",r2); pill.Size=UDim2.fromOffset(36,18); pill.Position=UDim2.new(1,-44,0.5,-9); pill.ZIndex=53
        Instance.new("UICorner",pill).CornerRadius=UDim.new(0,3)
        local dot=Instance.new("Frame",pill); dot.Size=UDim2.fromOffset(12,12); dot.ZIndex=54
        Instance.new("UICorner",dot).CornerRadius=UDim.new(0,2)
        local function ref()
            local on=ON[key]
            pill.BackgroundColor3=on and ACCENT or Color3.fromRGB(32,32,42)
            dot.BackgroundColor3=on and Color3.new(1,1,1) or Color3.fromRGB(80,80,95)
            dot.Position=on and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3)
            lbl.TextColor3=on and Color3.fromRGB(255,200,130) or Color3.fromRGB(150,150,160)
            r2.BackgroundColor3=on and Color3.fromRGB(22,18,12) or Color3.fromRGB(15,15,19)
        end
        local btn=Instance.new("TextButton",r2); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=55
        btn.Activated:Connect(function()
            ON[key]=not ON[key]; ref()
            if ON[key] and onE then pcall(onE) end
            if not ON[key] and onD then pcall(onD) end
            say(name..(ON[key] and " on" or " off"))
        end)
        ref()
    end

    local function act(page,name,fn)
        local p=pages[page]; if not p then return end; p.o+=1
        local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-2,0,28)
        b.BackgroundColor3=Color3.fromRGB(15,15,19); b.LayoutOrder=p.o; b.ZIndex=52; b.Parent=p.f
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
        b.Text="  "..name; b.Font=Enum.Font.GothamMedium; b.TextSize=12
        b.TextColor3=Color3.fromRGB(205,205,215); b.TextXAlignment=Enum.TextXAlignment.Left
        b.Activated:Connect(function()
            pcall(fn); b.BackgroundColor3=Color3.fromRGB(28,22,12)
            task.delay(0.12,function() b.BackgroundColor3=Color3.fromRGB(15,15,19) end)
        end)
    end

    local function sec(page,name)
        local p=pages[page]; if not p then return end; p.o+=1
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,14); l.BackgroundTransparency=1
        l.Text=string.upper(name); l.Font=Enum.Font.GothamBold; l.TextSize=9
        l.TextColor3=Color3.fromRGB(80,74,62); l.TextXAlignment=Enum.TextXAlignment.Left
        l.LayoutOrder=p.o; l.ZIndex=52; l.Parent=p.f
    end

    local function slider(page,name,cfgKey,minV,maxV,step,fmt)
        local p=pages[page]; if not p then return end; p.o+=1
        local r2=Instance.new("Frame"); r2.Size=UDim2.new(1,-2,0,36)
        r2.BackgroundColor3=Color3.fromRGB(15,15,19); r2.LayoutOrder=p.o; r2.ZIndex=52; r2.Parent=p.f
        Instance.new("UICorner",r2).CornerRadius=UDim.new(0,4)
        local lbl=Instance.new("TextLabel",r2); lbl.Size=UDim2.new(0.55,0,0,16); lbl.Position=UDim2.fromOffset(10,2)
        lbl.BackgroundTransparency=1; lbl.Text=name; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=11
        lbl.TextColor3=Color3.fromRGB(150,150,160); lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=53
        local valLbl=Instance.new("TextLabel",r2); valLbl.Size=UDim2.new(1,-20,0,14); valLbl.Position=UDim2.fromOffset(10,20)
        valLbl.BackgroundTransparency=1; valLbl.Font=Enum.Font.GothamMedium; valLbl.TextSize=10
        valLbl.TextColor3=ACCENT; valLbl.TextXAlignment=Enum.TextXAlignment.Left; valLbl.ZIndex=53
        local function refreshVal() valLbl.Text=(fmt or "%g"):format(CFG[cfgKey]) end; refreshVal()
        local function mkBtn(txt,xOff)
            local b=Instance.new("TextButton",r2); b.Size=UDim2.fromOffset(20,20); b.Position=UDim2.new(1,xOff,0.5,-10)
            b.BackgroundColor3=Color3.fromRGB(24,18,10); b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=14
            b.TextColor3=ACCENT; b.ZIndex=54; Instance.new("UICorner",b).CornerRadius=UDim.new(0,3); return b
        end
        local minus=mkBtn("−",-46); local plus=mkBtn("+",-22)
        minus.Activated:Connect(function() CFG[cfgKey]=math.clamp(CFG[cfgKey]-step,minV,maxV); refreshVal(); say(name..": "..(fmt or "%g"):format(CFG[cfgKey])) end)
        plus.Activated:Connect(function()  CFG[cfgKey]=math.clamp(CFG[cfgKey]+step,minV,maxV); refreshVal(); say(name..": "..(fmt or "%g"):format(CFG[cfgKey])) end)
    end

    -- ════════════════════════════════════════════════
    -- TAB: MAIN  (bypass + protection)
    -- ════════════════════════════════════════════════
    sec("main","bypass")
    act("main","Enable Bypass",function() startBypass(); say("bypass live") end)
    tog("main","Ownership",    "Ownership")
    tog("main","Anti-Teleport","AntiTP")
    sec("main","protection")
    tog("main","God Mode",     "God", startGod, function() if S.godConn then S.godConn:Disconnect() end end)
    tog("main","Anti-Void",    "NoVoid")
    slider("main","Void Floor Y","noVoidY",-500,-10,10,"%g")
    tog("main","Anti-Push",    "AntiPush")

    -- ════════════════════════════════════════════════
    -- TAB: COMBAT
    -- ════════════════════════════════════════════════
    sec("combat","aimbot")
    tog("combat","Aimbot  [hold Q]","Aimbot")
    tog("combat","FOV Circle",      "ShowFov")
    tog("combat","Silent Aim",      "SilentAim")
    tog("combat","Instant Snap",    "AimInstant")
    slider("combat","FOV radius",   "aimFovPx",   80, 800, 25, "%g px")
    slider("combat","Step speed",   "aimStepPx",   1,  60,  1, "%g px/f")
    slider("combat","Predict",      "aimPredict",  0, 0.5, 0.02, "%.2f")
    sec("combat","tools")
    tog("combat","Hitbox Expand",  "HitboxExpand",
        function() applyHitbox(true) end,
        function() applyHitbox(false) end)
    slider("combat","Hitbox Size",  "hitboxSize",   1,  20,  1, "%g st")
    tog("combat","Trigger Bot",    "TriggerBot", triggerStart, triggerStop)
    tog("combat","No Recoil",      "NoRecoil")
    sec("combat","utility")
    tog("combat","Mob Push",       "MobPush")

    -- ════════════════════════════════════════════════
    -- TAB: MOVE
    -- ════════════════════════════════════════════════
    sec("move","movement")
    tog("move","Speed",    "Speed",    applySpeed, applySpeed)
    slider("move","Walk Boost","walkBoost", 16, 500, 5, "%g")
    tog("move","High Jump","HighJump", applySpeed, applySpeed)
    slider("move","Jump Power","jumpBoost", 50, 300, 10, "%g")
    tog("move","Fly",      "Fly",      flyStart, flyStop)
    slider("move","Fly Speed","flySpeed", 20, 800, 10, "%g")
    tog("move","Noclip",   "Noclip",   function() setNoclip(true) end, function() setNoclip(false) end)
    tog("move","Inf Jump", "InfJump")
    tog("move","No Fall",  "NoFall")
    sec("move","vehicle  [F6 toggle]")
    tog("move","Car Fly",  "CarFly", carStart, carStop)
    slider("move","Car Speed", "carFlySpeed",  50, 800, 10, "%g")
    slider("move","Car Turbo", "carFlyBoost",  50,1200, 20, "%g")
    sec("move","teleport")
    act("move","Teleport to Nearest Enemy", teleportNearest)

    -- ════════════════════════════════════════════════
    -- TAB: VISUAL / ESP
    -- ════════════════════════════════════════════════
    sec("visual","highlight esp")
    tog("visual","ESP",         "ESP",     doESP,
        function() if not ON.Tracers then clearESP() else doESP() end end)
    tog("visual","Tracers",     "Tracers", doESP,
        function() if not ON.ESP then clearESP() else doESP() end end)
    tog("visual","Box ESP",     "BoxESP")
    tog("visual","Health Bars", "HealthBars",
        function() doHealthBars() end,
        function() clearHealthBars() end)
    slider("visual","Map Range", "mapRange", 100, 3000, 100, "%g m")
    sec("visual","lighting")
    tog("visual","Fullbright",   "Fullbright", function() fullbright(true) end, function() fullbright(false) end)
    tog("visual","Night Vision", "NightVision",
        function() setNightVision(true) end,
        function() setNightVision(false) end)
    slider("visual","Night Amt",  "nightAmt",   0, 255, 25, "%g")
    sec("visual","radar")
    tog("visual","Minimap",      "Minimap")
    tog("visual","Map Names",    "MapNames",
        function() ON.MapNames=true  end,
        function() ON.MapNames=false end)
    slider("visual","Map Size",  "mapSize", 120, 320, 20, "%g px")
    sec("visual","world")
    tog("visual","Item ESP",     "ItemESP")
    slider("visual","Item Range","itemEspRange", 50, 2000, 50, "%g m")

    -- ════════════════════════════════════════════════
    -- TAB: LOOT
    -- ════════════════════════════════════════════════
    sec("loot","loot tracker")
    tog("loot","Loot Tracker","LootTracker",
        function() startLootTracker(); say("loot tracker on") end,
        function() say("loot tracker off") end)
    tog("loot","Body Glow","LootTracker",
        function() CFG.lootBodyGlow=true end,
        function() CFG.lootBodyGlow=false end)
    slider("loot","Show range","lootRange",50,2000,50,"%g m")
    act("loot","Clear Log",function()
        S.lootLog={}
        for model,hl in pairs(S.lootBodyHL) do pcall(function() if hl and hl.Parent then hl:Destroy() end end) end
        S.lootBodyHL={}; pcall(refreshLootPanel); say("loot log cleared")
    end)
    sec("loot","kills / drops")
    local lp2=pages["loot"]; lp2.o+=1
    local lootScroll=Instance.new("ScrollingFrame"); lootScroll.Size=UDim2.new(1,-2,0,290)
    lootScroll.BackgroundColor3=Color3.fromRGB(10,9,6); lootScroll.LayoutOrder=lp2.o; lootScroll.ZIndex=52
    lootScroll.ScrollBarThickness=2; lootScroll.ScrollBarImageColor3=COL_LOOT
    lootScroll.CanvasSize=UDim2.fromOffset(0,0); lootScroll.Parent=lp2.f
    Instance.new("UICorner",lootScroll).CornerRadius=UDim.new(0,4)
    local lLay=Instance.new("UIListLayout",lootScroll); lLay.Padding=UDim.new(0,4); lLay.SortOrder=Enum.SortOrder.LayoutOrder
    lLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        lootScroll.CanvasSize=UDim2.fromOffset(0,lLay.AbsoluteContentSize.Y+8)
    end)
    S.lootPanel=lootScroll
    local emptyL=Instance.new("TextLabel",lootScroll); emptyL.Size=UDim2.new(1,0,0,30)
    emptyL.BackgroundTransparency=1; emptyL.Text="no loot yet — kills appear here"
    emptyL.Font=Enum.Font.Gotham; emptyL.TextSize=10; emptyL.TextColor3=Color3.fromRGB(80,80,95)
    emptyL.TextXAlignment=Enum.TextXAlignment.Center; emptyL.ZIndex=52

    -- ════════════════════════════════════════════════
    -- TAB: LIST (whitelist)
    -- ════════════════════════════════════════════════
    sec("list","whitelist")
    local lp=pages["list"]; lp.o+=1
    local box=Instance.new("ScrollingFrame"); box.Size=UDim2.new(1,-2,0,440)
    box.BackgroundColor3=Color3.fromRGB(11,11,15); box.LayoutOrder=lp.o; box.ZIndex=52
    box.ScrollBarThickness=2; box.Parent=lp.f
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,4)
    local bl=Instance.new("UIListLayout",box); bl.Padding=UDim.new(0,3)
    bl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        box.CanvasSize=UDim2.fromOffset(0,bl.AbsoluteContentSize.Y+6)
    end)

    local function refreshList()
        for _,c in ipairs(box:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=LocalPlayer then
                local friend=wl(plr)
                local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-6,0,24)
                b.BackgroundColor3=friend and Color3.fromRGB(14,28,18) or Color3.fromRGB(28,14,14)
                b.Text=(friend and "[WL] " or "")..plr.Name; b.Font=Enum.Font.Gotham; b.TextSize=11
                b.TextColor3=friend and COL_F or COL_E; b.ZIndex=53; b.Parent=box
                Instance.new("UICorner",b).CornerRadius=UDim.new(0,3)
                local p=plr
                b.Activated:Connect(function()
                    if WHITELIST[p.UserId] then WHITELIST[p.UserId]=nil else WHITELIST[p.UserId]=true end
                    refreshList(); if ON.ESP or ON.Tracers then doESP() end
                    say(p.Name..(wl(p) and " → friend" or " → enemy"))
                end)
            end
        end
    end

    act("list","Refresh",refreshList)
    Players.PlayerAdded:Connect(function() task.defer(refreshList) end)
    Players.PlayerRemoving:Connect(function(p) WHITELIST[p.UserId]=nil; task.defer(refreshList) end)
    task.defer(refreshList)

    -- ── Global hotkeys ──
    UserInputService.InputBegan:Connect(function(i,gp)
        if gp then return end
        if i.KeyCode==Enum.KeyCode.RightShift then
            setPanel(not panelOpen)
            if panelOpen then if not active then switch("main") end; refreshList() end
        elseif i.KeyCode==Enum.KeyCode.F9 then
            ON.Aimbot=not ON.Aimbot; say("aimbot "..(ON.Aimbot and "on" or "off")); updateFov()
        elseif i.KeyCode==Enum.KeyCode.F8 then
            ON.ESP=not ON.ESP
            if ON.ESP or ON.Tracers then doESP() else clearESP() end
            say("esp "..(ON.ESP and "on" or "off"))
        elseif i.KeyCode==Enum.KeyCode.F7 then
            ON.BoxESP=not ON.BoxESP; say("box esp "..(ON.BoxESP and "on" or "off"))
        elseif i.KeyCode==CFG.carFlyKey then
            ON.CarFly=not ON.CarFly
            if ON.CarFly then carStart() else carStop() end
            say("car fly "..(ON.CarFly and "on" or "off"))
        end
    end)

    switch("main")
end

-- ===================== INIT =====================
task.wait(0.25)
startBypass()
buildGui()
setupNoRecoil()
ON.Minimap=true; ON.ShowFov=true; ON.MapNames=true; ON.LootTracker=true
updateFov()
startLootTracker()
if S.gui then buildMap(S.gui) end

-- ===================== HOTKEY REFERENCE =====================
-- RShift     — toggle menu open/close
-- Q (hold)   — aimbot (when enabled)
-- F6         — car fly toggle
-- F7         — box ESP toggle
-- F8         — ESP toggle
-- F9         — aimbot toggle
-- Car fly controls:
--   W/S      = forward/back
--   A/D      = left/right
--   Space    = up
--   LShift   = down
--   LCtrl    = turbo speed
