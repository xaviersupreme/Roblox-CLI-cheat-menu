local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local username = Players.LocalPlayer.Name
local prompt = `C:\\Users\\{username}> `
local version = "Microsoft Windows [Version 10.0.22631.3737]"
local windowSize = Vector2.new(640, 300)
local lightCyan = Color3.fromRGB(0, 161, 214)
local white = Color3.fromRGB(255, 255, 255)
local silver = Color3.fromRGB(192, 192, 192)
local black = Color3.fromRGB(0, 0, 0)
local red = Color3.fromRGB(255, 0, 0)
local darkRed = Color3.fromRGB(128, 0, 0)
local gray = Color3.fromRGB(128, 128, 128)

local robloxUserInfo = {
    username = username,
    userId = tostring(Players.LocalPlayer.UserId),
    joinDate = "2023-01-15",
    accountAge = tostring(math.max(0, math.floor((tick() - Players.LocalPlayer.AccountAge * 86400) / 86400))) .. " days",
    displayName = Players.LocalPlayer.DisplayName,
    lastLogin = os.date("%Y-%m-%d %H:%M:%S")
}

local hackCode = {
    aimbot = {
        "[0x0001] Initializing aimbot module...",
        "Loading memory hooks: 0x7FFB1234",
        "Patching vector3_t: aim_smooth=0.1",
        "Injecting mouse_rel: fov=100px",
        "Aimbot thread started: 0xDEADBEEF"
    },
    esp = {
        "[0x0002] Initializing ESP module...",
        "Scanning playerlist: 0xFF123456",
        "DrawingAPI hook: box_color=0xFF0000",
        "Nametag render: outline=true",
        "ESP thread started: 0xCAFEBABE"
    },
    speed = {
        "[0x0003] Initializing speed module...",
        "Accessing humanoid: 0xABCDEF12",
        "Patching walkspeed: multiplier=2.0",
        "Bypassing physics: 0x7890ABCD",
        "Speed hack active: 0xF00DBAAD"
    },
    noclip = {
        "[0x0004] Initializing noclip module...",
        "Hooking collision: 0x456789EF",
        "Setting CanCollide: false",
        "Physics override: 0x11223344",
        "Noclip thread started: 0xAABBCCDD"
    },
    triggerbot = {
        "[0x0005] Initializing triggerbot module...",
        "Hooking mouse input: 0x12345678",
        "Patching raycast: hitbox=true",
        "Binding fire event: 0x87654321",
        "Triggerbot thread started: 0xBEEFBABE"
    },
    fly = {
        "[0x0006] Initializing fly module...",
        "Accessing physics: 0xA1B2C3D4",
        "Patching gravity: multiplier=0.0",
        "Binding WASD controls: 0xD4C3B2A1",
        "Fly thread started: 0xFEEDFACE"
    }
}

local cheatStates = {
    aimbot = false,
    esp = false,
    speed = false,
    noclip = false,
    triggerbot = false,
    fly = false
}
local cmdHistory = {}
local currentInput = ""
local isVisible = true
local isMinimized = false
local isDragging = false
local isLogging = false
local dragStartPos = nil
local dragStartFramePos = nil

local espDrawings = {}
local espConnections = {}
local aimbotConnection = nil
local noclipConnection = nil
local triggerbotConnection = nil
local flyConnection = nil
local flyBodyVelocity = nil
local flyBodyGyro = nil

local gui = Instance.new("ScreenGui")
gui.Name = "CmdCheatUI"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = lightCyan
frame.BorderColor3 = white
frame.BorderSizePixel = 1
frame.Parent = gui

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 20)
titleBar.BackgroundColor3 = silver
titleBar.BorderSizePixel = 0
titleBar.Parent = frame

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -70, 1, 0)
titleText.Position = UDim2.new(0, 5, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "C:\\Windows\\System32\\cmd.exe"
titleText.TextColor3 = black
titleText.TextSize = 12
titleText.Font = Enum.Font.SourceSans
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 16, 0, 16)
minimizeButton.Position = UDim2.new(1, -37, 0, 2)
minimizeButton.BackgroundColor3 = silver
minimizeButton.BorderColor3 = gray
minimizeButton.BorderSizePixel = 1
minimizeButton.Text = "−"
minimizeButton.TextColor3 = black
minimizeButton.TextSize = 12
minimizeButton.Font = Enum.Font.SourceSans
minimizeButton.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 16, 0, 16)
closeButton.Position = UDim2.new(1, -18, 0, 2)
closeButton.BackgroundColor3 = red
closeButton.BorderColor3 = darkRed
closeButton.BorderSizePixel = 1
closeButton.Text = "X"
closeButton.TextColor3 = white
closeButton.TextSize = 12
closeButton.Font = Enum.Font.SourceSans
closeButton.Parent = titleBar

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 20)
header.Position = UDim2.new(0, 0, 0, 20)
header.BackgroundColor3 = lightCyan
header.BorderSizePixel = 0
header.Text = "*** STOP: 0x0000DEAD (CLI_CHEAT_INITIALIZED) ***"
header.TextColor3 = white
header.TextSize = 12
header.Font = Enum.Font.SourceSans
header.TextXAlignment = Enum.TextXAlignment.Center
header.Parent = frame

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -10, 0, 235)
inputBox.Position = UDim2.new(0, 5, 0, 45)
inputBox.BackgroundTransparency = 1
inputBox.TextColor3 = white
inputBox.TextSize = 14
inputBox.Font = Enum.Font.SourceSans
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.TextYAlignment = Enum.TextYAlignment.Top
inputBox.TextWrapped = true
inputBox.ClearTextOnFocus = false
inputBox.Text = prompt
inputBox.Parent = frame

local function trimString(str)
    return str:match("^%s*(.-)%s*$")
end

local function safeCall(func)
    local success, result = pcall(func)
    if not success then
        warn(`Error: {result}`)
        table.insert(cmdHistory, `{prompt}{currentInput}\n> Internal error: {result}`)
        currentInput = ""
        updateTextBox()
    end
end

local function updateTextBox()
    safeCall(function()
        local content = table.concat(cmdHistory, "\n")
        if content ~= "" then
            content = content .. "\n"
        end
        content = content .. prompt .. currentInput
        inputBox.Text = content
        inputBox.CursorPosition = #inputBox.Text + 1
    end)
end

local function getNearestPlayer()
    local localPlayer = Players.LocalPlayer
    local character = localPlayer.Character
    if not character or not character:FindFirstChild("Head") then return nil end
    local localPos = character.Head.Position
    local nearestPlayer = nil
    local minDist = 100
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            local dist = (head.Position - localPos).Magnitude
            local screenPos, onScreen = Camera:WorldToScreenPoint(head.Position)
            if onScreen and dist < minDist and (not game:GetService("Teams") or player.Team ~= localPlayer.Team) then
                minDist = dist
                nearestPlayer = player
            end
        end
    end
    return nearestPlayer
end

local function toggleAimbot(enabled)
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
    if enabled then
        aimbotConnection = RunService.RenderStepped:Connect(function()
            local target = getNearestPlayer()
            if target and target.Character and target.Character:FindFirstChild("Head") then
                local headPos = target.Character.Head.Position
                local currentPos = Camera.CFrame.Position
                local targetCFrame = CFrame.new(currentPos, headPos)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 0.2)
            end
        end)
    end
end

local function createESP(player)
    if player == Players.LocalPlayer or espDrawings[player] then return end
    
    if not Drawing then
        warn("Drawing API not available")
        return
    end
    
    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Color = player.Team and player.Team.TeamColor.Color or Color3.fromRGB(255, 0, 0)
    box.Filled = false
    local name = Drawing.new("Text")
    name.Size = 16
    name.Color = Color3.fromRGB(255, 255, 255)
    name.Outline = true
    espDrawings[player] = {box = box, name = name}
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not cheatStates.esp or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Head") then
            box.Visible = false
            name.Visible = false
            return
        end
        local root = player.Character.HumanoidRootPart
        local screenPos, onScreen = Camera:WorldToScreenPoint(root.Position)
        if onScreen then
            local scale = 1000 / math.max(1, (Camera.CFrame.Position - root.Position).Magnitude)
            local size = Vector2.new(1000 * scale, 2000 * scale)
            box.Size = size
            box.Position = Vector2.new(screenPos.X - size.X / 2, screenPos.Y - size.Y / 2)
            box.Visible = true
            name.Text = player.DisplayName or player.Name
            name.Position = Vector2.new(screenPos.X, screenPos.Y - size.Y / 2 - 20)
            name.Visible = true
        else
            box.Visible = false
            name.Visible = false
        end
    end)
    
    espConnections[player] = connection
    
    local function cleanup()
        if espDrawings[player] then
            espDrawings[player].box:Remove()
            espDrawings[player].name:Remove()
            espDrawings[player] = nil
        end
        if espConnections[player] then
            espConnections[player]:Disconnect()
            espConnections[player] = nil
        end
    end
    
    player.CharacterRemoving:Connect(cleanup)
    Players.PlayerRemoving:Connect(function(removedPlayer)
        if removedPlayer == player then
            cleanup()
        end
    end)
end

local function toggleESP(enabled)
    if enabled then
        if Drawing then
            for _, player in pairs(Players:GetPlayers()) do
                createESP(player)
            end
            Players.PlayerAdded:Connect(createESP)
        else
            warn("Drawing API not available for ESP")
        end
    else
        for player, drawing in pairs(espDrawings) do
            drawing.box:Remove()
            drawing.name:Remove()
            if espConnections[player] then
                espConnections[player]:Disconnect()
            end
        end
        espDrawings = {}
        espConnections = {}
    end
end

local function toggleSpeed(enabled)
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = enabled and 100 or 16
    end
end

local function toggleNoclip(enabled)
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if enabled then
        noclipConnection = RunService.Stepped:Connect(function()
            local character = Players.LocalPlayer.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        local character = Players.LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function toggleTriggerbot(enabled)
    if triggerbotConnection then
        triggerbotConnection:Disconnect()
        triggerbotConnection = nil
    end
    if enabled then
        triggerbotConnection = RunService.RenderStepped:Connect(function()
            local mouse = Players.LocalPlayer:GetMouse()
            local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {Players.LocalPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
            if result and result.Instance then
                local targetCharacter = result.Instance:FindFirstAncestorOfClass("Model")
                if targetCharacter and targetCharacter:FindFirstChild("Humanoid") then
                    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
                    if targetPlayer and (not game:GetService("Teams") or targetPlayer.Team ~= Players.LocalPlayer.Team) then
                        if mouse1press and mouse1release then
                            mouse1press()
                            task.wait(0.01)
                            mouse1release()
                        end
                    end
                end
            end
        end)
    end
end

local function toggleFly(enabled)
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    if enabled then
        local character = Players.LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart

            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyGyro.CFrame = rootPart.CFrame
            flyBodyGyro.Parent = rootPart

            flyConnection = RunService.RenderStepped:Connect(function()
                local moveDir = Vector3.new(0, 0, 0)
                local speed = 50
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + Camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - Camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - Camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + Camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end
                if moveDir.Magnitude > 0 then
                    flyBodyVelocity.Velocity = moveDir.Unit * speed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
                flyBodyGyro.CFrame = Camera.CFrame
            end)
        end
    end
end

local function triggerLogAnimation(command, enabled)
    if isLogging then return end
    isLogging = true
    local lines = {}
    for i, line in ipairs(hackCode[command]) do
        lines[i] = line
    end
    
    if not enabled then
        for i, line in ipairs(lines) do
            lines[i] = line:gsub("started", "stopped"):gsub("Initializing", "Shutting down"):gsub("active", "deactivated")
        end
    end
    
    local totalLines = #lines
    local index = 1
    local initialResponse = `> {command:sub(1,1):upper()}{command:sub(2)} {enabled and "enabled" or "disabled"}`
    table.insert(cmdHistory, `{prompt}{currentInput}\n{initialResponse}`)
    currentInput = ""
    updateTextBox()

    local function displayNextLine()
        if index <= totalLines then
            table.insert(cmdHistory, lines[index])
            updateTextBox()
            index = index + 1
            
            if index <= totalLines then
                task.wait(0.5)
                displayNextLine()
            else
                isLogging = false
            end
        else
            isLogging = false
        end
    end

    task.wait(0.5)
    displayNextLine()
end

inputBox.FocusLost:Connect(function(enterPressed)
    safeCall(function()
        if not enterPressed or isLogging then return end
        
        local command = trimString(currentInput:lower())
        local response = ""
        
        if command == "aimbot" or command == "esp" or command == "speed" or command == "noclip" or command == "triggerbot" or command == "fly" then
            cheatStates[command] = not cheatStates[command]
            if command == "aimbot" then toggleAimbot(cheatStates.aimbot) end
            if command == "esp" then toggleESP(cheatStates.esp) end
            if command == "speed" then toggleSpeed(cheatStates.speed) end
            if command == "noclip" then toggleNoclip(cheatStates.noclip) end
            if command == "triggerbot" then toggleTriggerbot(cheatStates.triggerbot) end
            if command == "fly" then toggleFly(cheatStates.fly) end
            triggerLogAnimation(command, cheatStates[command])
        elseif command == "net user" then
            response = `User name                {robloxUserInfo.username}\n` ..
                      `User ID                  {robloxUserInfo.userId}\n` ..
                      `Display Name             {robloxUserInfo.displayName}\n` ..
                      `Account Created          {robloxUserInfo.joinDate}\n` ..
                      `Account Age              {robloxUserInfo.accountAge}\n` ..
                      `Last Logon               {robloxUserInfo.lastLogin}`
            table.insert(cmdHistory, `{prompt}{currentInput}\n{response}`)
            currentInput = ""
            updateTextBox()
        elseif command == "toggle" then
            isVisible = not isVisible
            frame.Visible = isVisible
            response = `> UI {isVisible and "shown" or "hidden"}`
            table.insert(cmdHistory, `{prompt}{currentInput}\n{response}`)
            currentInput = ""
            updateTextBox()
        elseif command == "cmds" then
            response = "> Available commands: aimbot, esp, speed, noclip, triggerbot, fly, net user, toggle, cmds, dir, cls, ver, echo"
            table.insert(cmdHistory, `{prompt}{currentInput}\n{response}`)
            currentInput = ""
            updateTextBox()
        elseif command == "dir" then
            response = "Volume in drive C has no label.\n" ..
                      "Volume Serial Number is 1234-5678\n\n" ..
                      "Directory of C:\\Windows\\System32\n\n" ..
                      "aimbot.exe    esp.exe    speed.exe    noclip.exe\n" ..
                      "triggerbot.exe fly.exe    toggle.exe   cmds.exe\n" ..
                      "dir.exe       cls.exe    ver.exe      echo.exe\n" ..
                      "netuser.exe"
            table.insert(cmdHistory, `{prompt}{currentInput}\n{response}`)
            currentInput = ""
            updateTextBox()
        elseif command == "cls" then
            cmdHistory = {}
            currentInput = ""
            updateTextBox()
        elseif command == "ver" then
            response = version
            table.insert(cmdHistory, `{prompt}{currentInput}\n{response}`)
            currentInput = ""
            updateTextBox()
        elseif command == "echo" then
            response = "ECHO is on."
            table.insert(cmdHistory, `{prompt}{currentInput}\n{response}`)
            currentInput = ""
            updateTextBox()
        elseif command ~= "" then
            response = `"${currentInput}" is not recognized as an internal or external command,\noperable program or batch file.`
            table.insert(cmdHistory, `{prompt}{currentInput}\n{response}`)
            currentInput = ""
            updateTextBox()
        else
            currentInput = ""
            updateTextBox()
        end
    end)
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
    safeCall(function()
        if isLogging then 
            updateTextBox()
            return 
        end
        
        local text = inputBox.Text
        local promptLen = #prompt
        
        if #text < promptLen or text:sub(1, promptLen) ~= prompt then
            updateTextBox()
            return
        end
        
        currentInput = text:sub(promptLen + 1)
    end)
end)

titleBar.InputBegan:Connect(function(input)
    safeCall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStartPos = input.Position
            dragStartFramePos = frame.Position
        end
    end)
end)

titleBar.InputEnded:Connect(function(input)
    safeCall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
end)

UserInputService.InputChanged:Connect(function(input)
    safeCall(function()
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStartPos
            frame.Position = UDim2.new(
                dragStartFramePos.X.Scale,
                dragStartFramePos.X.Offset + delta.X,
                dragStartFramePos.Y.Scale,
                dragStartFramePos.Y.Offset + delta.Y
            )
        end
    end)
end)

minimizeButton.MouseButton1Click:Connect(function()
    safeCall(function()
        isMinimized = not isMinimized
        frame.Size = isMinimized and UDim2.new(0, windowSize.X, 0, 20) or UDim2.new(0, windowSize.X, 0, windowSize.Y)
        inputBox.Visible = not isMinimized
        header.Visible = not isMinimized
    end)
end)

closeButton.MouseButton1Click:Connect(function()
    safeCall(function()
        isVisible = false
        frame.Visible = false
    end)
end)

minimizeButton.MouseEnter:Connect(function()
    minimizeButton.BackgroundColor3 = Color3.fromRGB(208, 208, 208)
end)
minimizeButton.MouseLeave:Connect(function()
    minimizeButton.BackgroundColor3 = silver
end)
closeButton.MouseEnter:Connect(function()
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 51, 51)
end)
closeButton.MouseLeave:Connect(function()
    closeButton.BackgroundColor3 = red
end)

Players.LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(1)
    if cheatStates.speed then
        toggleSpeed(true)
    end
    if cheatStates.noclip then
        toggleNoclip(true)
    end
    if cheatStates.fly then
        toggleFly(true)
    end
end)
