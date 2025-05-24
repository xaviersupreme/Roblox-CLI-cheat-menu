local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
if not player then return end

local username = player.Name
local ageInDays = player.AccountAge
local ageInYears = math.floor(ageInDays / 365)
local joinYear = DateTime.now().Year - ageInYears

local prompt = string.format("C:\\Users\\%s> ", username)
local version = "Microsoft Windows [Version 10.0.22631.3737]"

local windowSize = Vector2.new(640, 300)
local lightCyan = Color3.fromRGB(0, 161, 214)
local white = Color3.fromRGB(255, 255, 255)
local silver = Color3.fromRGB(192, 192, 192)
local black = Color3.fromRGB(0, 0, 0)
local red = Color3.fromRGB(255, 0, 0)
local darkRed = Color3.fromRGB(128, 0, 0)
local gray = Color3.fromRGB(128, 128, 128)

local function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then warn(string.format("[Vanguard-AI Error] %s", tostring(result))) end
    return success, result
end

local function string_trim(s) return s:match("^%s*(.-)%s*$") end
local function string_startsWith(s, prefix) return s:sub(1, #prefix) == prefix end

local robloxUserInfo = {
    username = player.Name,
    userId = tostring(player.UserId),
    joinDate = string.format("%d-XX-XX (Approx)", joinYear),
    accountAge = string.format("%d days (~%d years)", ageInDays, ageInYears),
    displayName = player.DisplayName,
    lastLogin = DateTime.now():FormatLocalTime("YYYY-MM-DD HH:mm:ss", "en-us")
}
local hackCode = {
    aimbot = {"[0x0001] Initializing aimbot module...","Loading memory hooks: 0x7FFB1234","Patching vector3_t: aim_smooth=0.1","Injecting mouse_rel: fov=100px","Aimbot thread started: 0xDEADBEEF"},
    esp = {"[0x0002] Initializing ESP module...","Scanning playerlist: 0xFF123456","DrawingAPI hook: box_color=0xFF0000","Nametag render: outline=true","ESP thread started: 0xCAFEBABE"},
    speed = {"[0x0003] Initializing speed module...","Accessing humanoid: 0xABCDEF12","Patching walkspeed: multiplier=2.0","Bypassing physics: 0x7890ABCD","Speed hack active: 0xF00DBAAD"},
    noclip = {"[0x0004] Initializing noclip module...","Hooking collision: 0x456789EF","Setting CanCollide: false","Physics override: 0x11223344","Noclip thread started: 0xAABBCCDD"}
}

local cheatStates = { aimbot = false, esp = false, speed = false, noclip = false }
local cmdHistory = {}
local currentInput = ""
local isVisible = true
local isMinimized = false
local isDragging = false
local isLogging = false
local dragStartPos = nil
local dragStartFramePos = nil
local isUpdatingInternally = false

local gui = Instance.new("ScreenGui") gui.Name = "CmdCheatUI" gui.ResetOnSpawn = false gui.Parent = CoreGui
local frame = Instance.new("Frame") frame.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y) frame.Position = UDim2.new(0, 10, 0, 10) frame.BackgroundColor3 = lightCyan frame.BorderColor3 = white frame.BorderSizePixel = 1 frame.Parent = gui frame.Active = true frame.ClipsDescendants = true
local titleBar = Instance.new("Frame") titleBar.Size = UDim2.new(1, 0, 0, 20) titleBar.BackgroundColor3 = silver titleBar.BorderSizePixel = 0 titleBar.Parent = frame titleBar.Active = true
local titleText = Instance.new("TextLabel") titleText.Size = UDim2.new(1, -70, 1, 0) titleText.Position = UDim2.new(0, 5, 0, 0) titleText.BackgroundTransparency = 1 titleText.Text = "C:\\Windows\\System32\\cmd.exe" titleText.TextColor3 = black titleText.TextSize = 12 titleText.Font = Enum.Font.SourceSans titleText.TextXAlignment = Enum.TextXAlignment.Left titleText.Parent = titleBar
local minimizeButton = Instance.new("TextButton") minimizeButton.Size = UDim2.new(0, 16, 0, 16) minimizeButton.Position = UDim2.new(1, -37, 0, 2) minimizeButton.BackgroundColor3 = silver minimizeButton.BorderColor3 = gray minimizeButton.BorderSizePixel = 1 minimizeButton.Text = "−" minimizeButton.TextColor3 = black minimizeButton.TextSize = 12 minimizeButton.Font = Enum.Font.SourceSans minimizeButton.Parent = titleBar minimizeButton.AutoButtonColor = false
local closeButton = Instance.new("TextButton") closeButton.Size = UDim2.new(0, 16, 0, 16) closeButton.Position = UDim2.new(1, -18, 0, 2) closeButton.BackgroundColor3 = red closeButton.BorderColor3 = darkRed closeButton.BorderSizePixel = 1 closeButton.Text = "X" closeButton.TextColor3 = white closeButton.TextSize = 12 closeButton.Font = Enum.Font.SourceSans closeButton.Parent = titleBar closeButton.AutoButtonColor = false
local header = Instance.new("TextLabel") header.Size = UDim2.new(1, 0, 0, 20) header.Position = UDim2.new(0, 0, 0, 20) header.BackgroundColor3 = lightCyan header.BorderSizePixel = 0 header.Text = "*** STOP: 0x0000DEAD (CLI_CHEAT_INITIALIZED) ***" header.TextColor3 = white header.TextSize = 12 header.Font = Enum.Font.SourceSans header.TextXAlignment = Enum.TextXAlignment.Center header.Parent = frame
local inputBox = Instance.new("TextBox") inputBox.Size = UDim2.new(1, -10, 1, -50) inputBox.Position = UDim2.new(0, 5, 0, 45) inputBox.BackgroundColor3 = lightCyan inputBox.BackgroundTransparency = 0 inputBox.TextColor3 = white inputBox.TextSize = 14 inputBox.Font = Enum.Font.SourceSans inputBox.TextXAlignment = Enum.TextXAlignment.Left inputBox.TextYAlignment = Enum.TextYAlignment.Top inputBox.TextWrapped = true inputBox.ClearTextOnFocus = false inputBox.MultiLine = true inputBox.Parent = frame

local function updateTextBox()
    safeCall(function()
        isUpdatingInternally = true
        local historyText = table.concat(cmdHistory, "\n")
        local content = historyText
        if content ~= "" then content = content .. "\n" end
        content = content .. prompt .. currentInput
        inputBox.Text = content
        task.wait()
        inputBox.CursorPosition = #inputBox.Text + 1
        isUpdatingInternally = false
    end)
end

local function addHistoryAndClear(cmd, response)
    safeCall(function()
        local fullPrompt = prompt .. cmd
        table.insert(cmdHistory, fullPrompt)
        if response and response ~= "" then table.insert(cmdHistory, response) end
        currentInput = ""
        updateTextBox()
    end)
end

local function triggerLogAnimation(command, enabled)
    safeCall(function()
        if isLogging then return end
        isLogging = true
        local inputForLog = currentInput
        local originalLines = hackCode[command]
        local lines = {}
        for _, line in ipairs(originalLines) do table.insert(lines, line) end
        if not enabled then
            for i, line in ipairs(lines) do
                lines[i] = line:gsub("started", "stopped"):gsub("Initializing", "Shutting down"):gsub("active", "deactivated")
            end
        end
        local initialResponse = string.format("> %s %s (simulated)", command:sub(1,1):upper()..command:sub(2), enabled and "enabled" or "disabled")
        table.insert(cmdHistory, string.format("%s%s\n%s", prompt, inputForLog, initialResponse))
        currentInput = ""
        updateTextBox()
        task.spawn(function()
            safeCall(function()
                for _, line in ipairs(lines) do
                    task.wait(0.3)
                    table.insert(cmdHistory, line)
                    updateTextBox()
                end
                isLogging = false
                currentInput = ""
                updateTextBox()
                inputBox:CaptureFocus()
            end)
        end)
    end)
end

local function processCommand(fullInput)
    safeCall(function()
        local command = string_trim(fullInput):lower()
        local response = ""
        if command == "" then addHistoryAndClear("", nil); return end
        if cheatStates[command] ~= nil then
            cheatStates[command] = not cheatStates[command]
            triggerLogAnimation(command, cheatStates[command])
            return
        elseif command == "net user" then
            response = string.format("User name          %s\n", robloxUserInfo.username) ..
                       string.format("User ID            %s\n", robloxUserInfo.userId) ..
                       string.format("Display Name       %s\n", robloxUserInfo.displayName) ..
                       string.format("Account Created    %s\n", robloxUserInfo.joinDate) ..
                       string.format("Account Age        %s\n", robloxUserInfo.accountAge) ..
                       string.format("Last Logon         %s", robloxUserInfo.lastLogin)
        elseif command == "toggle" then
            isVisible = not isVisible; frame.Visible = isVisible
            response = string.format("> UI %s", isVisible and "shown" or "hidden")
        elseif command == "cmds" then
            response = "> Available commands: aimbot, esp, speed, noclip, net user, toggle, cmds, dir, cls, ver, echo"
        elseif command == "dir" then
            response = "dir\n" ..
                       "aimbot.exe    esp.exe     speed.exe     noclip.exe\n" ..
                       "toggle.exe    cmds.exe    dir.exe       cls.exe\n" ..
                       "ver.exe       echo.exe    netuser.exe"
        elseif command == "cls" then
            cmdHistory = {}; currentInput = ""; updateTextBox(); return
        elseif command == "ver" then
            response = version
        elseif string_startsWith(command, "echo") then
            local msg = string_trim(command:sub(5))
            response = msg ~= "" and msg or "ECHO is on."
        else
            response = string.format("\"%s\" is not recognized...", command)
        end
        addHistoryAndClear(fullInput, response)
    end)
end

inputBox.FocusLost:Connect(function(enterPressed)
    safeCall(function()
        if enterPressed and not isLogging then processCommand(currentInput) end
    end)
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
    safeCall(function()
        if isUpdatingInternally or isLogging then return end
        local text = inputBox.Text
        local historyText = table.concat(cmdHistory, "\n")
        local expectedPrefix = historyText
        if expectedPrefix ~= "" then expectedPrefix = expectedPrefix .. "\n" end
        expectedPrefix = expectedPrefix .. prompt
        if string_startsWith(text, expectedPrefix) then
            currentInput = text:sub(#expectedPrefix + 1)
        else
            updateTextBox()
        end
    end)
end)

titleBar.InputBegan:Connect(function(input)
    safeCall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true; dragStartPos = input.Position; dragStartFramePos = frame.Position
        end
    end)
end)

titleBar.InputEnded:Connect(function(input)
    safeCall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
    end)
end)

UserInputService.InputChanged:Connect(function(input)
    safeCall(function()
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStartPos
            frame.Position = UDim2.new(dragStartFramePos.X.Scale, dragStartFramePos.X.Offset + delta.X, dragStartFramePos.Y.Scale, dragStartFramePos.Y.Offset + delta.Y)
        end
    end)
end)

minimizeButton.MouseButton1Click:Connect(function()
    safeCall(function()
        isMinimized = not isMinimized
        frame.Size = isMinimized and UDim2.new(0, windowSize.X, 0, 20) or UDim2.new(0, windowSize.X, 0, windowSize.Y)
        header.Visible = not isMinimized; inputBox.Visible = not isMinimized
        if not isMinimized then frame.Visible = true; isVisible = true end
    end)
end)

closeButton.MouseButton1Click:Connect(function()
    safeCall(function() gui:Destroy() end)
end)

minimizeButton.MouseEnter:Connect(function() safeCall(function() minimizeButton.BackgroundColor3 = Color3.fromRGB(208, 208, 208) end) end)
minimizeButton.MouseLeave:Connect(function() safeCall(function() minimizeButton.BackgroundColor3 = silver end) end)
closeButton.MouseEnter:Connect(function() safeCall(function() closeButton.BackgroundColor3 = Color3.fromRGB(255, 51, 51) end) end)
closeButton.MouseLeave:Connect(function() safeCall(function() closeButton.BackgroundColor3 = red end) end)

safeCall(function()
    updateTextBox()
    inputBox:CaptureFocus()
end)
