-- Services
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

-- Optimization Function
local function optimizeObject(v)
    local character = player.Character
    if character and v:IsDescendantOf(character) then return end
    if v:IsA("BasePart") then
        v.Material = Enum.Material.SmoothPlastic
        v.CastShadow = false
        v.Reflectance = 0
        v.TopSurface = Enum.SurfaceType.Smooth
        v.BottomSurface = Enum.SurfaceType.Smooth
    elseif v:IsA("Decal") or v:IsA("Texture") then
        if v.Parent and not v.Parent:FindFirstChildOfClass("Humanoid") then
            v:Destroy()
        end
    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
        v.Enabled = false
    elseif v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
        v.Enabled = false
    end
end

-- Global States
getgenv().AutoInteract = false
getgenv().AutoBigEgg = false
getgenv().AutoPartFarm = false
getgenv().AutoRainbowEgg = false
getgenv().AutoTreadmill = false
getgenv().FlySpeed = 600

-- Configuration
local COLOR_BIGGEST = Color3.fromRGB(255, 0, 128)
local COLOR_NORMAL  = Color3.fromRGB(0, 255, 128)
local MIN_PARTS_COUNT = 20
local allAreaNames = {"Titan Temple", "Cherry Blossom", "Cosmic", "Prehistoric", "Abyss Ocean", "Desert", "Jungle", "Lake", "Snow", "Volcano"}
local selectedModules = {"Titan Temple"}
local RAINBOW_KEYWORDS = {"rainbow", "glow", "radicalhalo"}

-- Checkpoint CFrame
local originalCFrame = CFrame.new(538.479553, 70.8011246, -409.704681, 0.730235636, 8.46091197e-08, -0.683195353, -5.78969193e-08, 1, 6.19599163e-08, 0.683195353, -5.69043168e-09, 0.730235636)

-- Helper: Get Character Root Part safely
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

-- Helper: Tween to Checkpoint
local function tweenToCheckpointFirst(hrp, speed)
    if not hrp then return end
    local dist = (hrp.Position - originalCFrame.Position).Magnitude
    if dist < 10 then return end
    local duration = dist / speed
    local tweenInfo = TweenInfo.new(math.max(duration, 0.1), Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local highStartCF = CFrame.new(hrp.Position.X, hrp.Position.Y + 0, hrp.Position.Z) * hrp.CFrame.Rotation
    local tweenUp = TweenService:Create(hrp, TweenInfo.new(1, Enum.EasingStyle.Linear), {CFrame = highStartCF})
    tweenUp:Play()
    tweenUp.Completed:Wait()
    local tweenToOriginal = TweenService:Create(hrp, tweenInfo, {CFrame = originalCFrame})
    tweenToOriginal:Play()
    tweenToOriginal.Completed:Wait()
end

-- Helper: Wall/Reset Check
local function isWallOpenOrCountdownFinished()
    local playerGui = player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    local resetTimerGui = playerGui:FindFirstChild("ResetStartTimer") or Workspace:FindFirstChild("ResetStartTimer")
    if resetTimerGui and resetTimerGui.Enabled then
        local frame = resetTimerGui:FindFirstChild("Frame")
        if frame then
            local textLabel = frame:FindFirstChild("TextLabel")
            if textLabel and textLabel.Visible and textLabel.Text ~= "" then return false end
        end
    end
    local resetWall = Workspace:FindFirstChild("AreaEggResetWall") or Workspace:FindFirstChild("EggResetWall")
    if resetWall then
        local wallPart = resetWall:IsA("BasePart") and resetWall or resetWall:FindFirstChildWhichIsA("BasePart", true)
        if wallPart and wallPart.Transparency < 1 and wallPart.CanCollide then return false end
    end
    return true
end

-- Helper: Rainbow/Special Egg Check
local function isRainbowEgg(slot)
    if not slot or not slot.Name then return false end
    local slotNameLower = string.lower(slot.Name)
    for _, keyword in ipairs(RAINBOW_KEYWORDS) do
        if string.find(slotNameLower, keyword) then return true end
    end
    for _, item in ipairs(slot:GetDescendants()) do
        if item and item.Name then
            local itemNameLower = string.lower(item.Name)
            for _, keyword in ipairs(RAINBOW_KEYWORDS) do
                if string.find(itemNameLower, keyword) then return true end
            end
        end
    end
    return false
end

-- 1. Camera Control System
local distance = 12
local angleX = 0
local angleY = 15
local isRightMouseDown = false
local touchOrigin = nil

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseDown = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    elseif input.UserInputType == Enum.UserInputType.Touch then
        touchOrigin = input.Position
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseDown = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    elseif input.UserInputType == Enum.UserInputType.Touch then
        touchOrigin = nil
    end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if isRightMouseDown and input.UserInputType == Enum.UserInputType.MouseMovement then
        angleX = angleX - input.Delta.X * 0.4
        angleY = math.clamp(angleY - input.Delta.Y * 0.4, -60, 80)
    elseif input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
        if touchOrigin then
            local delta = input.Position - touchOrigin
            touchOrigin = input.Position
            angleX = angleX - delta.X * 0.3
            angleY = math.clamp(angleY - delta.Y * 0.3, -60, 80)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local rootPos = char.HumanoidRootPart.Position + Vector3.new(0, 2.5, 0)
        local rotation = CFrame.Angles(0, math.rad(angleX), 0) * CFrame.Angles(math.rad(angleY), 0, 0)
        local cameraPosition = rootPos + rotation * Vector3.new(0, 0, distance)
        camera.CFrame = CFrame.new(cameraPosition, rootPos)
    end
end)

-- 2. Fly & Noclip Loops
local bodyVelocity = nil
local bodyGyro = nil

RunService.Stepped:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChild("Humanoid")
        if not hum then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            if not bodyVelocity or bodyVelocity.Parent ~= hrp then
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.Velocity = Vector3.zero
                bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyVelocity.Parent = hrp
            end
            if not bodyGyro or bodyGyro.Parent ~= hrp then
                bodyGyro = Instance.new("BodyGyro")
                bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bodyGyro.CFrame = hrp.CFrame
                bodyGyro.Parent = hrp
            end
        else
            if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
            if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
        end
    end
end)

-- 3. Volume ESP System & 4. Multi-Part ESP System (រក្សាទុកដូចដើម)
local function getEggSize(slot)
    local targetPart = slot:FindFirstChild("Hitbox", true) or (slot:IsA("BasePart") and slot or slot:FindFirstChildWhichIsA("BasePart", true))
    if targetPart then
        local size = targetPart.Size
        return size.X * size.Y * size.Z, targetPart
    end
    return 0, nil
end

local function countParts(object)
    local count = object:IsA("BasePart") and 1 or 0
    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA("BasePart") then
            count += 1
        end
    end
    return count
end

-- 5. Priority Auto-Farm System & Treadmill System
task.spawn(function()
    local areaEggSlotsClient = Workspace:WaitForChild("AreaEggSlotsClient")
    local objects = Workspace:WaitForChild("__OBJECTS", 5)
    local areas = objects and objects:WaitForChild("Areas", 5)
    local guardAreas = areas and areas:WaitForChild("GuardAreas", 5)
    
    local FLY_OFFSET_HEIGHT = 3
    local HEIGHT_OFFSET = 1.5
    local MAX_PROXIMITY_DIST = 10
    local WAIT_AT_BASE = 1

    local function getGroundYForPosition(targetPosition)
        local closestY = targetPosition.Y
        local shortestDistance = math.huge
        if guardAreas then
            for _, part in ipairs(guardAreas:GetChildren()) do
                local basePart = part:IsA("BasePart") and part or (part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart", true))
                if basePart then
                    local dist = (Vector2.new(basePart.Position.X, basePart.Position.Z) - Vector2.new(targetPosition.X, targetPosition.Z)).Magnitude
                    if dist < shortestDistance then
                        shortestDistance = dist
                        closestY = basePart.Position.Y + (basePart.Size.Y / 2)
                    end
                end
            end
        end
        return closestY
    end

    local function isHitboxInAllowedArea(hitbox)
        if not hitbox then return false end
        local hitboxPos = hitbox.Position
        for _, name in ipairs(selectedModules) do
            local areaObj = guardAreas and guardAreas:FindFirstChild(name)
            if areaObj then
                local areaPart = areaObj:IsA("BasePart") and areaObj or (areaObj.PrimaryPart or areaObj:FindFirstChildWhichIsA("BasePart", true))
                if areaPart then
                    local dist = (Vector2.new(hitboxPos.X, hitboxPos.Z) - Vector2.new(areaPart.Position.X, areaPart.Position.Z)).Magnitude
                    if dist <= 500 then return true end
                end
            end
        end
        return false
    end

    local function getTweenInfo(startCF, targetCF)
        local dist = (startCF.Position - targetCF.Position).Magnitude
        local duration = dist / getgenv().FlySpeed 
        return TweenInfo.new(math.max(duration, 0.1), Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    end

    local function safeFirePrompt(prompt)
        if typeof(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
        elseif prompt and prompt:FindFirstChildOfClass("RemoteEvent") then
            prompt:FindFirstChildOfClass("RemoteEvent"):FireServer()
        end
    end

    local function interactNearbyPrompts()
        local hrp = getHRP()
        if not hrp then return end
        local currentPos = hrp.Position
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local parentPart = prompt.Parent
                if parentPart and parentPart:IsA("BasePart") then
                    if (parentPart.Position - currentPos).Magnitude <= MAX_PROXIMITY_DIST then
                        safeFirePrompt(prompt)
                    end
                end
            end
        end
    end

    -- =========================================
    -- Function: ទាញយកទីតាំងកណ្តាលរបស់សំបុក Lake
    -- =========================================
    local function getLakeNestCenter()
        local lakeNests = Workspace:FindFirstChild("__OBJECTS") 
            and Workspace.__OBJECTS:FindFirstChild("Areas") 
            and Workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")
            and Workspace.__OBJECTS.Areas.GuardAreas:FindFirstChild("Lake")
            and Workspace.__OBJECTS.Areas.GuardAreas.Lake:FindFirstChild("Nests")

        if lakeNests then
            -- យកសំបុកទី១ដែលវាលោតចេញមក
            for _, nest in ipairs(lakeNests:GetChildren()) do
                local nestPart = nest:IsA("BasePart") and nest or (nest.PrimaryPart or nest:FindFirstChildWhichIsA("BasePart", true))
                if nestPart then
                    return nestPart
                end
            end
        end
        return nil
    end

    -- =========================================
    -- Function: ឆែកមើលថាតើតួអង្គកំពុងកាន់ស៊ុតឬនៅ?
    -- =========================================
    local function isHoldingEgg()
        local char = player.Character
        if char then
            -- ឆែកមើលក្រែងលោវាជា Tool កាន់នៅនឹងដៃ
            if char:FindFirstChildWhichIsA("Tool") then return true end
            -- ឆែកមើលក្រែងលោវាជា Model ដែលជាប់នឹងខ្នង ឬដៃ
            for _, v in ipairs(char:GetChildren()) do
                if string.find(string.lower(v.Name), "egg") then return true end
            end
        end
        
        -- ឆែកមើលក្នុងកាបូប (Backpack) ក្រែងលោវាចូលទីនោះ
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            if backpack:FindFirstChildWhichIsA("Tool") then return true end
            for _, v in ipairs(backpack:GetChildren()) do
                if string.find(string.lower(v.Name), "egg") then return true end
            end
        end
        return false
    end

    -- =========================================
    -- Function: ទម្រង់លួចស៊ុត (Steal Egg) ថ្មីបំផុត
    -- =========================================
    local function stealEggAtLocation(targetSlot)
        local hrp = getHRP()
        if not hrp or not targetSlot then return end
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.zero

        tweenToCheckpointFirst(hrp, getgenv().FlySpeed)

        local guardAreasObj = Workspace:FindFirstChild("__OBJECTS") 
            and Workspace.__OBJECTS:FindFirstChild("Areas") 
            and Workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")
        local lakeArea = guardAreasObj and guardAreasObj:FindFirstChild("Lake")
        local lakeGuard = lakeArea and lakeArea:FindFirstChild("Guard")
        local lakeGuardHumanoid = lakeGuard and lakeGuard:FindFirstChild("Humanoid")

        -- ជំហានទី១៖ ទៅកាន់កណ្តាលសំបុក Lake ហើយចុចព្រាវៗរហូតដល់មាន Egg នៅនឹងដៃ
        local lakeNestPart = getLakeNestCenter()
        if lakeNestPart then
            local nestPos = lakeNestPart.Position
            local fGroundY = getGroundYForPosition(nestPos)
            local fFlyY = fGroundY + FLY_OFFSET_HEIGHT
            local fCollectCF = CFrame.new(nestPos.X, nestPos.Y + HEIGHT_OFFSET, nestPos.Z) * hrp.CFrame.Rotation
            local fHighCF = CFrame.new(nestPos.X, fFlyY, nestPos.Z) * hrp.CFrame.Rotation

            -- ហោះទៅពីលើសំបុក
            local tFlyF = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, fHighCF), {CFrame = fHighCF})
            tFlyF:Play() 
            tFlyF.Completed:Wait()

            -- ចុះមកកណ្តាលសំបុក
            local tDownF = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, fCollectCF), {CFrame = fCollectCF})
            tDownF:Play() 
            tDownF.Completed:Wait()

            hrp.Anchored = true
            hrp.CFrame = fCollectCF
            
            -- Loop ចុចព្រាវរហូតទាល់តែបានកាន់ស៊ុត (ដាក់ Timeout ៣០ដង ការពារគាំងរហូត)
            local attempts = 0
            while not isHoldingEgg() and attempts < 30 do
                interactNearbyPrompts()
                task.wait(0.2)
                attempts = attempts + 1
            end

            hrp.Anchored = false

            -- ហោះឡើងវិញ
            local tUpF = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, fHighCF), {CFrame = fHighCF})
            tUpF:Play() 
            tUpF.Completed:Wait()
        end

        -- ជំហានទី២៖ ហោះទៅបុក Guard (បន្ទាប់ពីបានស៊ុតរួច)
        if lakeGuardHumanoid then
            local guardPos, guardCF
            local rootPart = lakeGuardHumanoid.RootPart or (lakeGuardHumanoid.Parent and lakeGuardHumanoid.Parent:FindFirstChild("HumanoidRootPart"))
            
            if rootPart then
                guardCF = rootPart.CFrame
                guardPos = rootPart.Position
            elseif lakeGuardHumanoid.Parent and lakeGuardHumanoid.Parent:IsA("Model") then
                guardCF = lakeGuardHumanoid.Parent:GetPivot()
                guardPos = guardCF.Position
            end

            if guardPos and guardCF then
                local flyY = getGroundYForPosition(guardPos) + FLY_OFFSET_HEIGHT
                local highGuardCF = CFrame.new(guardPos.X, flyY, guardPos.Z)

                local tFlyG = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, highGuardCF), {CFrame = highGuardCF})
                tFlyG:Play() 
                tFlyG.Completed:Wait()

                local tDownG = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, guardCF), {CFrame = guardCF})
                tDownG:Play() 
                tDownG.Completed:Wait()

                task.wait(0.5)

                local tUpG = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, highGuardCF), {CFrame = highGuardCF})
                tUpG:Play() 
                tUpG.Completed:Wait()
            end
        end

        -- ជំហានទី៣៖ ទៅយកស៊ុតគោលដៅពិតប្រាកដ
        local targetHitbox = targetSlot:FindFirstChild("Hitbox", true) or (targetSlot:IsA("BasePart") and targetSlot) or targetSlot:FindFirstChildWhichIsA("BasePart", true)
        if targetHitbox and targetHitbox.Parent and targetHitbox:IsDescendantOf(Workspace) then
            local targetPos = targetHitbox.Position
            local groundY = getGroundYForPosition(targetPos)
            local flyY = groundY + FLY_OFFSET_HEIGHT
            local collectTargetCF = CFrame.new(targetPos.X, targetPos.Y + HEIGHT_OFFSET, targetPos.Z) * targetHitbox.CFrame.Rotation
            local highTargetCF = CFrame.new(targetPos.X, flyY, targetPos.Z) * targetHitbox.CFrame.Rotation

            local tweenFlyToEgg = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, highTargetCF), {CFrame = highTargetCF})
            tweenFlyToEgg:Play() 
            tweenFlyToEgg.Completed:Wait()

            local tweenDownToEgg = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, collectTargetCF), {CFrame = collectTargetCF})
            tweenDownToEgg:Play() 
            tweenDownToEgg.Completed:Wait()

            hrp.Anchored = true
            hrp.CFrame = collectTargetCF
            task.wait(0.1)
            interactNearbyPrompts()
            task.wait(0.1)
            hrp.Anchored = false

            local tweenBackUp = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, highTargetCF), {CFrame = highTargetCF})
            tweenBackUp:Play() 
            tweenBackUp.Completed:Wait()
        end

        -- ជំហានទី៤៖ ត្រលប់មក Base វិញ
        local tweenFlyBack = TweenService:Create(hrp, getTweenInfo(hrp.CFrame, originalCFrame), {CFrame = originalCFrame})
        tweenFlyBack:Play() 
        tweenFlyBack.Completed:Wait()

        task.wait(WAIT_AT_BASE)
    end
    -- =========================================

    local function getTargetEgg()
        local slots = areaEggSlotsClient:GetChildren()

        if getgenv().AutoRainbowEgg then
            for _, slot in ipairs(slots) do
                if isRainbowEgg(slot) then return slot end
            end
        end

        if getgenv().AutoPartFarm then
            local bestPartEgg = nil
            local maxParts = -1
            for _, slot in ipairs(slots) do
                local partsCount = countParts(slot)
                if partsCount >= MIN_PARTS_COUNT and partsCount > maxParts then
                    maxParts = partsCount
                    bestPartEgg = slot
                end
            end
            if bestPartEgg then return bestPartEgg end
        end

        if getgenv().AutoBigEgg then
            local bestBigEgg = nil
            local maxVolume = -1
            for _, slot in ipairs(slots) do
                local volume = getEggSize(slot)
                if volume >= 90 and volume > maxVolume then
                    maxVolume = volume
                    bestBigEgg = slot
                end
            end
            if bestBigEgg then return bestBigEgg end
        end

        if getgenv().AutoInteract then
            for _, slot in ipairs(slots) do
                local hitbox = slot:FindFirstChild("Hitbox", true)
                if hitbox and hitbox:IsA("BasePart") and isHitboxInAllowedArea(hitbox) then
                    return slot
                end
            end
        end

        return nil
    end

    local storedHumanoid = nil
    local function removeHumanoid()
        local char = player.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum:UnequipTools()
                storedHumanoid = hum
                hum.Parent = nil
            end
        end
    end
    local function restoreHumanoid()
        local char = player.Character
        if char and not char:FindFirstChild("Humanoid") and storedHumanoid then
            storedHumanoid.Parent = char
            workspace.CurrentCamera.CameraSubject = storedHumanoid
            storedHumanoid = nil
        end
    end

    -- Treadmill System
    local TWEEN_SPEED_TREADMILL = 100
    local HIP_OFFSET = 3
    local isCurrentlyOnTreadmill = false

    local function findMyPlot()
        local plotsFolder = workspace:FindFirstChild("Plots")
        if not plotsFolder then return nil end
        for _, plot in ipairs(plotsFolder:GetChildren()) do
            if plot.Name == player.Name or plot.Name == tostring(player.UserId) then
                return plot
            end
            for _, descendant in ipairs(plot:GetDescendants()) do
                if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and string.find(descendant.Text, player.Name) then
                    return plot
                elseif descendant:IsA("StringValue") and descendant.Value == player.Name then
                    return plot
                elseif descendant:IsA("ObjectValue") and descendant.Value == player then
                    return plot
                elseif (descendant:IsA("IntValue") or descendant:IsA("NumberValue")) and descendant.Value == player.UserId then
                    return plot
                end
            end
        end
        return nil
    end

    local function tweenToTreadmillRoot()
        local myPlot = findMyPlot()
        if not myPlot then return end
        local plotNumber = string.match(myPlot.Name, "%d+")
        if not plotNumber then return end
        local treadmillFolder = workspace:FindFirstChild("__ClientTreadmillRenders")
        if not treadmillFolder then return end
        local myTreadmill = treadmillFolder:FindFirstChild("TreadmillRender_" .. plotNumber)
        if myTreadmill then
            local rootPart = myTreadmill:FindFirstChild("Root", true)
            local targetCFrame
            if rootPart and rootPart:IsA("BasePart") then
                targetCFrame = rootPart.CFrame
            else
                targetCFrame = myTreadmill:IsA("Model") and myTreadmill:GetPivot() or (myTreadmill:IsA("BasePart") and myTreadmill.CFrame)
            end
            if targetCFrame then
                local hrp = getHRP()
                if not hrp then return end
                hrp.Anchored = false
                tweenToCheckpointFirst(hrp, TWEEN_SPEED_TREADMILL)
                local finalCFrame = targetCFrame * CFrame.new(0, HIP_OFFSET, 0)
                local distance = (hrp.Position - finalCFrame.Position).Magnitude
                local duration = distance / TWEEN_SPEED_TREADMILL
                local tweenInfo = TweenInfo.new(math.max(duration, 0.1), Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                local tween = TweenService:Create(hrp, tweenInfo, {CFrame = finalCFrame})
                tween:Play()
                tween.Completed:Wait()
                hrp.Anchored = false
            end
        end
    end

    local function leaveTreadmill()
        local askDoffRemote = nil
        pcall(function() askDoffRemote = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/Treadmill/AskDoff") end)
        if askDoffRemote and askDoffRemote:IsA("RemoteFunction") then
            pcall(function() askDoffRemote:InvokeServer() end)
        end
        local hrp = getHRP()
        if hrp then hrp.Anchored = false end
    end

    -- Main Loop
    while true do
        if isWallOpenOrCountdownFinished() then
            local targetSlot = getTargetEgg()
            if targetSlot then
                if isCurrentlyOnTreadmill then
                    leaveTreadmill()
                    isCurrentlyOnTreadmill = false
                    task.wait(0.5)
                end
                removeHumanoid()
                stealEggAtLocation(targetSlot) 
            else
                restoreHumanoid()
                if getgenv().AutoTreadmill then
                    if not isCurrentlyOnTreadmill then
                        tweenToTreadmillRoot()
                        isCurrentlyOnTreadmill = true
                    end
                else
                    if isCurrentlyOnTreadmill then
                        leaveTreadmill()
                        isCurrentlyOnTreadmill = false
                    end
                end
                task.wait(0.5)
            end
        else
            restoreHumanoid()
            if getgenv().AutoTreadmill then
                if not isCurrentlyOnTreadmill then
                    tweenToTreadmillRoot()
                    isCurrentlyOnTreadmill = true
                end
            else
                if isCurrentlyOnTreadmill then
                    leaveTreadmill()
                    isCurrentlyOnTreadmill = false
                end
            end
            task.wait(0.2)
        end
        task.wait(0.1)
    end
end)

-- 6. Rayfield UI Initialization
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local window = Rayfield:CreateWindow({
    Name = "[STEAL AN EGG] ToaToa Hub - By 2BK2 ",
    LoadingTitle = "Welcome to (ToaToa Hub) ",
    LoadingSubtitle = "by 2BK2",
    ConfigurationSaving = {Enabled = true, FolderName = "RayfieldTestConfig", FileName = "PlayerSettings" },
    Discord = {Enabled = false, Invite = "noinvite", RememberJoins = true },
    KeySystem = false,
})

local tab = window:CreateTab("Farm", 4483362458)

Rayfield:Notify({
    Title = "----ហាមចុចបើកអីទាំងអស់----\n!រង់ចាំបន្តិចសិន!",
    Content = "មិនទាន់លេងបានទេចាំអោយប្រព័ន្ធដំណើរការចប់សិន\nហាមចុចបើកមុខងារអីទាំងអស់",
    Duration = 10,
    Image = 4483362458,
})

tab:CreateDropdown({
    Name = '<font size="24"><b>ជ្រើសរើសទីតាំង</b></font>(Select Areas)',
    Options = allAreaNames,
    CurrentOption = selectedModules,
    MultipleOptions = true,
    Flag = "AreaDropdown",
    Callback = function(selected) selectedModules = selected end,
})

tab:CreateSlider({
    Name = '<font size="24"><b>កំណត់ល្បឿនហោះ</b></font>(Fly Speed)',
    Range = {600, 800},
    Increment = 10,
    Suffix = " Speed",
    CurrentValue = 600,
    Flag = "FlySpeedSlider", 
    Callback = function(Value) getgenv().FlySpeed = Value end,
})

tab:CreateToggle({
    Name = '<font size="24"><b>លួចតែស៊ុតនៅទីតាំងដែរបានជ្រើសរើស</b></font>(Select)',
    CurrentValue = false,
    Flag = "steal_dropdown",
    Callback = function(value) getgenv().AutoInteract = value end,
})

tab:CreateToggle({
    Name = '<font size="24"><b>លួចតែស៊ុតធំៗ</b></font>(Steal Big Egg)',
    CurrentValue = false,
    Flag = "steal_bigeggs",
    Callback = function(value) getgenv().AutoBigEgg = value end,
})

tab:CreateToggle({
    Name = '<font size="24"><b>លួចស៊ុត៧ពណ៏</b></font>(Rainbow, Devine)',
    CurrentValue = false,
    Flag = "auto_rainbow_egg",
    Callback = function(value) getgenv().AutoRainbowEgg = value end,
})

tab:CreateToggle({
    Name = '<font size="24"><b>លួចស៊ុតដែលមានស្លាប</b></font>(MASSIVE EGGS)',
    CurrentValue = false,
    Flag = "auto_part_farm",
    Callback = function(value) getgenv().AutoPartFarm = value end,
})

tab:CreateToggle({
    Name = '<font size="24"><b>រត់លើម៉ាស៊ីនពេលទំនេរ</b></font>(Auto Treadmill)',
    CurrentValue = false,
    Flag = "auto_treadmill",
    Callback = function(value) getgenv().AutoTreadmill = value end,
})

tab:CreateToggle({
    Name = '<font size="24"><b>បន្ថយការឡេគ</b></font>(Optimization)',
    CurrentValue = false,
    Flag = "Optimization",
    Callback = function(value)
        if value then
            for _, v in pairs(Workspace:GetDescendants()) do pcall(optimizeObject, v) end
            Workspace.DescendantAdded:Connect(function(v) pcall(optimizeObject, v) end)
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0
        end
    end,
})
