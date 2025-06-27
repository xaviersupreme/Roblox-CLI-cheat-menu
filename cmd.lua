local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- The main table to hold all components of our Terminal application.
local Terminal = {}


Terminal.Config = {
    Font = Enum.Font.Code,
    FontSize = 16,
    DefaultTextColor = Color3.fromRGB(200, 200, 200),
    BackgroundColor = Color3.fromRGB(12, 12, 12),
    TitleBarColor = Color3.fromRGB(20, 20, 20),
    CursorBlinkRate = 0.53,
    MaxHistory = 50,
    InertialDamping = 0.92, -- how much the window slows down after dragging (closer to 1 is less friction)
}

Terminal.State = {
    -- UI State
    IsInitialized = false,
    IsDragging = false,
    IsResizing = false,
    DragVelocity = Vector2.zero,
    
    -- Command State
    CurrentPath = "C:\\Users\\Default",
    CommandHistory = {},
    HistoryIndex = 0,
    TextColor = Terminal.Config.DefaultTextColor,
    
    -- Feature State
    Aimbot = {
        Enabled = false,
        FieldOfView = 120,
        Smoothness = 5,
        TargetPart = "Head",
        TeamCheck = true,
        Target = nil,
    },
    ESP = {
        Enabled = false,
        BoxColor = Color3.fromRGB(255, 0, 255),
        NameColor = Color3.fromRGB(255, 105, 180),
        TeamCheck = true,
        Drawings = {},
    },
}

-- The virtual file system (VFS)
Terminal.VFS = {
    ["C:"] = {
        __type = "FOLDER",
        __creationTime = os.time(),
        Users = {
            __type = "FOLDER",
            __creationTime = os.time(),
            Default = {
                __type = "FOLDER",
                __creationTime = os.time(),
                Desktop = { __type = "FOLDER", __creationTime = os.time() },
                Documents = { __type = "FOLDER", __creationTime = os.time() },
                ["system.log"] = { __type = "FILE", content = "Terminal loaded successfully.", __creationTime = os.time() },
                ["notes.txt"] = { __type = "FILE", content = "1. Be productive.\n2. ???\n3. Profit.", __creationTime = os.time() },
            }
        }
    }
}

-- References to all UI elements will be stored here.
Terminal.UI = {}

-- Connections to events that need to be managed.
Terminal.Connections = {}


-- ============================================================================
-- 3. VIRTUAL FILE SYSTEM (VFS) ABSTRACTION
-- ============================================================================

Terminal.VFS.Functions = {}

--- Resolves a given path (absolute or relative) and returns the target node and its parent.
function Terminal.VFS.Functions.ResolvePath(path)
    local startNode
    local pathSegments

    -- determine if the path is absolute or relative
    if path:sub(1, 3):lower() == "c:\\" then
        startNode = Terminal.VFS["C:"]
        pathSegments = { path:match("c:\\(.*)") }
    else
        startNode = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath)
        pathSegments = { path }
    end
    
    if not startNode then return nil end

    local currentNode = startNode
    local parentNode = nil

    for segment in pathSegments[1]:gmatch("[^\\\\]+") do
        if segment == ".." then -- handle parent directory navigation
            -- to find the parent, we must resolve the path up to the current node
            local parentPath = Terminal.State.CurrentPath:match("(.*)\\[^\\]+")
            if parentPath then
                parentNode = currentNode
                currentNode = Terminal.VFS.Functions.ResolvePath(parentPath)
            else -- at root, can't go further up
                currentNode = startNode 
            end
        else
            if currentNode and currentNode[segment] then
                parentNode = currentNode
                currentNode = currentNode[segment]
            else
                return nil, nil -- path does not exist
            end
        end
    end

    return currentNode, parentNode
end


Terminal.Features = {}

-- esp logic
Terminal.Features.ESP = {
    ClearDrawings = function()
        for _, drawing in ipairs(Terminal.State.ESP.Drawings) do
            drawing:Remove()
        end
        Terminal.State.ESP.Drawings = {}
    end,
    
    Update = function()
        Terminal.Features.ESP.ClearDrawings()
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer or (Terminal.State.ESP.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil) then continue end
            
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if not (humanoid and humanoid.Health > 0 and rootPart) then continue end
            
            local head = character:FindFirstChild("Head")
            if not head then continue end
            
            local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            if onScreen then
                local headScreenPos = Camera:WorldToViewportPoint(head.Position)
                local scale = math.abs(headScreenPos.Y - screenPos.Y)
                local boxWidth = scale / 2
                
                -- create box
                local box = Drawing.new("Quad")
                box.PointA = Vector2.new(screenPos.X - boxWidth, headScreenPos.Y)
                box.PointB = Vector2.new(screenPos.X + boxWidth, headScreenPos.Y)
                box.PointC = Vector2.new(screenPos.X + boxWidth, screenPos.Y)
                box.PointD = Vector2.new(screenPos.X - boxWidth, screenPos.Y)
                box.Color = Terminal.State.ESP.BoxColor
                box.Thickness = 1
                box.Filled = false
                box.Visible = true
                table.insert(Terminal.State.ESP.Drawings, box)
                
                -- create name
                local name = Drawing.new("Text")
                name.Text = player.DisplayName
                name.Size = 14
                name.Color = Terminal.State.ESP.NameColor
                name.Center = true
                name.Outline = true
                name.Position = Vector2.new(screenPos.X, headScreenPos.Y - 16)
                name.Visible = true
                table.insert(Terminal.State.ESP.Drawings, name)
            end
        end
    end,
}

-- aimbot logic
Terminal.Features.Aimbot = {
    GetBestTarget = function()
        local bestTarget = nil
        local closestDistanceToCrosshair = math.huge
        local mousePosition = UserInputService:GetMouseLocation()
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer or (Terminal.State.Aimbot.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil) then continue end
            
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            
            if humanoid and humanoid.Health > 0 then
                local targetPart = character:FindFirstChild(Terminal.State.Aimbot.TargetPart)
                if targetPart then
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distanceToCrosshair = (Vector2.new(screenPosition.X, screenPosition.Y) - mousePosition).Magnitude
                        if distanceToCrosshair < Terminal.State.Aimbot.FieldOfView and distanceToCrosshair < closestDistanceToCrosshair then
                            bestTarget = targetPart
                            closestDistanceToCrosshair = distanceToCrosshair
                        end
                    end
                end
            end
        end
        return bestTarget
    end,
    
    Update = function()
        Terminal.State.Aimbot.Target = Terminal.Features.Aimbot.GetBestTarget()
        
        if Terminal.State.Aimbot.Target then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, Terminal.State.Aimbot.Target.Position)
            local newCFrame = Camera.CFrame:Lerp(targetCFrame, 1 / Terminal.State.Aimbot.Smoothness)
            Camera.CFrame = newCFrame
        end
    end,
}


Terminal.UIManager = {}

--- Prints a line of text to the console output.
function Terminal.UIManager.Print(text)
    local lineLabel = Instance.new("TextLabel")
    lineLabel.Name = "OutputLine"
    lineLabel.Text = tostring(text)
    lineLabel.TextColor3 = Terminal.State.TextColor
    lineLabel.Font = Terminal.Config.Font
    lineLabel.TextSize = Terminal.Config.FontSize
    lineLabel.TextXAlignment = Enum.TextXAlignment.Left
    lineLabel.TextYAlignment = Enum.TextYAlignment.Top
    lineLabel.Size = UDim2.new(1, 0, 0, Terminal.Config.FontSize + 2)
    lineLabel.BackgroundTransparency = 1
    lineLabel.Parent = Terminal.UI.OutputFrame
    
    -- ensure it's placed before the current input line
    if Terminal.UI.ActiveInputLine then
        lineLabel.LayoutOrder = Terminal.UI.ActiveInputLine.LayoutOrder
        Terminal.UI.ActiveInputLine.LayoutOrder += 1
    end
end

--- Creates a new interactive input line at the bottom.
function Terminal.UIManager.CreateNewInputLine()
    local lineFrame = Instance.new("Frame")
    lineFrame.Name = "InputLine"
    lineFrame.Size = UDim2.new(1, 0, 0, Terminal.Config.FontSize + 4)
    lineFrame.BackgroundTransparency = 1
    lineFrame.LayoutOrder = (Terminal.UI.ActiveInputLine and Terminal.UI.ActiveInputLine.LayoutOrder + 1) or 1
    
    local listLayout = Instance.new("UIListLayout", lineFrame)
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local promptLabel = Instance.new("TextLabel", lineFrame)
    promptLabel.Name = "PromptLabel"
    promptLabel.Text = Terminal.State.CurrentPath .. ">"
    promptLabel.TextColor3 = Terminal.State.TextColor
    promptLabel.Font = Terminal.Config.Font
    promptLabel.TextSize = Terminal.Config.FontSize
    promptLabel.BackgroundTransparency = 1
    promptLabel.Size = UDim2.fromOffset(TextService:GetTextSize(promptLabel.Text, promptLabel.TextSize, promptLabel.Font, Vector2.one * 10000).X, Terminal.Config.FontSize)
    
    local inputBox = Instance.new("TextBox", lineFrame)
    inputBox.Name = "InputBox"
    inputBox.TextColor3 = Terminal.State.TextColor
    inputBox.Font = Terminal.Config.Font
    inputBox.TextSize = Terminal.Config.FontSize
    inputBox.BackgroundTransparency = 1
    inputBox.Size = UDim2.new(1, -promptLabel.Size.X.Offset, 1, 0)
    inputBox.ClearTextOnFocus = false
    inputBox.Text = ""
    
    Terminal.UI.ActiveInputLine = lineFrame
    Terminal.UI.ActiveInputBox = inputBox
    
    lineFrame.Parent = Terminal.UI.OutputFrame
    
    task.wait() -- allow layout to update
    Terminal.UI.OutputFrame.CanvasPosition = Vector2.new(0, Terminal.UI.OutputFrame.CanvasSize.Y)
    
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            Terminal.CommandProcessor.ProcessInput(inputBox.Text)
        end
    end)
    
    inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        Terminal.State.HistoryIndex = #Terminal.State.CommandHistory + 1
    end)
    
    inputBox:CaptureFocus()
end


Terminal.CommandProcessor = {}

--- Parses and executes a raw input string.
function Terminal.CommandProcessor.ProcessInput(rawInput)
    local input = rawInput:match("^%s*(.-)%s*$") -- trim whitespace
    
    Terminal.UI.ActiveInputBox.TextEditable = false -- lock the used input box
    
    if input ~= "" then
        table.insert(Terminal.State.CommandHistory, input)
        if #Terminal.State.CommandHistory > Terminal.Config.MaxHistory then
            table.remove(Terminal.State.CommandHistory, 1)
        end
    end
    Terminal.State.HistoryIndex = #Terminal.State.CommandHistory + 1
    
    -- parse arguments, respecting quotes
    local args = {}
    for arg in rawInput:gmatch('"[^"]*"|%S+') do
        table.insert(args, arg:gsub('"', ''))
    end
    
    local commandName = table.remove(args, 1)
    
    if commandName then
        commandName = commandName:lower()
        
        -- check for command aliases
        local commandFunction = Terminal.Commands[commandName]
        if not commandFunction then
            for alias, target in pairs(Terminal.CommandAliases) do
                if commandName == alias then
                    commandFunction = Terminal.Commands[target]
                    break
                end
            end
        end
        
        if commandFunction then
            commandFunction(args)
        else
            Terminal.UIManager.Print("'" .. commandName .. "' is not recognized as an internal or external command,")
            Terminal.UIManager.Print("operable program or batch file.")
        end
    end
    
    Terminal.UIManager.CreateNewInputLine()
end


Terminal.Commands = {
    -- file and directory commands
    dir = function()
        local node, _ = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath)
        if not node or node.__type ~= "FOLDER" then Terminal.UIManager.Print("error: current directory is invalid."); return end
        
        Terminal.UIManager.Print(" Directory of " .. Terminal.State.CurrentPath .. "\n")
        local dirCount, fileCount = 0, 0
        
        for name, data in pairs(node) do
            if name:sub(1, 2) ~= "__" then
                local dateStr = os.date("%m/%d/%Y  %I:%M %p", data.__creationTime)
                if data.__type == "FOLDER" then
                    Terminal.UIManager.Print(string.format("%s    <DIR>          %s", dateStr, name))
                    dirCount = dirCount + 1
                elseif data.__type == "FILE" then
                    local size = #data.content
                    Terminal.UIManager.Print(string.format("%s %14d %s", dateStr, size, name))
                    fileCount = fileCount + 1
                end
            end
        end
        Terminal.UIManager.Print(string.format("\n%16d File(s)", fileCount))
        Terminal.UIManager.Print(string.format("%16d Dir(s)", dirCount))
    end,
    
    cd = function(args)
        local targetPath = args[1]
        if not targetPath then Terminal.UIManager.Print(Terminal.State.CurrentPath); return end
        
        if targetPath == ".." then
            local parentPath = Terminal.State.CurrentPath:match("(.*)\\[^\\]+")
            Terminal.State.CurrentPath = parentPath or "C:\\"
            return
        end

        local currentDir = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath)
        if currentDir[targetPath] and currentDir[targetPath].__type == "FOLDER" then
            if Terminal.State.CurrentPath:sub(-1) ~= "\\" then Terminal.State.CurrentPath = Terminal.State.CurrentPath .. "\\" end
            Terminal.State.CurrentPath = Terminal.State.CurrentPath .. targetPath
        else
            Terminal.UIManager.Print("The system cannot find the path specified.")
        end
    end,
    
    md = function(args)
        local dirName = args[1]
        if not dirName then Terminal.UIManager.Print("The syntax of the command is incorrect."); return end
        local parentNode, _ = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath)
        if parentNode[dirName] then Terminal.UIManager.Print("A subdirectory or file " .. dirName .. " already exists.")
        else parentNode[dirName] = { __type = "FOLDER", __creationTime = os.time() } end
    end,
    
    rd = function(args)
        local dirName = args[1]
        if not dirName then Terminal.UIManager.Print("The syntax of the command is incorrect."); return end
        local parentNode, _ = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath)
        local targetNode = parentNode[dirName]
        if not targetNode then Terminal.UIManager.Print("The system cannot find the file specified.")
        elseif targetNode.__type ~= "FOLDER" then Terminal.UIManager.Print("The specified path is not a directory.")
        elseif next(targetNode, "__creationTime") and next(targetNode, "__type") then Terminal.UIManager.Print("The directory is not empty.")
        else parentNode[dirName] = nil end
    end,

    del = function(args)
        local fileName = args[1]
        if not fileName then Terminal.UIManager.Print("The syntax of the command is incorrect."); return end
        local parentNode, _ = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath)
        if not parentNode[fileName] or parentNode[fileName].__type ~= "FILE" then Terminal.UIManager.Print("Could not find file specified.")
        else parentNode[fileName] = nil end
    end,
    
    ren = function(args)
        local oldName, newName = args[1], args[2]
        if not (oldName and newName) then Terminal.UIManager.Print("The syntax of the command is incorrect."); return end
        local parentNode, _ = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath)
        if not parentNode[oldName] then Terminal.UIManager.Print("The system cannot find the file specified.")
        elseif parentNode[newName] then Terminal.UIManager.Print("A duplicate file name exists, or the file cannot be found.")
        else parentNode[newName] = parentNode[oldName]; parentNode[oldName] = nil end
    end,
    
    type = function(args)
        local fileName = args[1]
        if not fileName then Terminal.UIManager.Print("The syntax of the command is incorrect."); return end
        local node, _ = Terminal.VFS.Functions.ResolvePath(Terminal.State.CurrentPath .. "\\" .. fileName)
        if not node or node.__type ~= "FILE" then Terminal.UIManager.Print("The system cannot find the file specified.")
        else Terminal.UIManager.Print(node.content) end
    end,
    
    -- utility commands
    cls = function() for _, c in ipairs(Terminal.UI.OutputFrame:GetChildren()) do if c.Name == "OutputLine" or c.Name == "InputLine" then c:Destroy() end end end,
    echo = function(args) Terminal.UIManager.Print(table.concat(args, " ")) end,
    exit = function() Terminal.Shutdown() end,
    help = function() local cl = {}; for c in pairs(Terminal.Commands) do table.insert(cl, c:upper()) end; table.sort(cl); Terminal.UIManager.Print(table.concat(cl, "   ")) end,
    title = function(args) Terminal.UI.TitleLabel.Text = table.concat(args, " ") end,
    ver = function() Terminal.UIManager.Print("\nLuau Terminal [Version 1.2.0]\n") end,
    date = function() Terminal.UIManager.Print("The current date is: " .. os.date("%m/%d/%Y")) end,
    time = function() Terminal.UIManager.Print("The current time is: " .. os.date("%I:%M:%S %p")) end,
    color = function(args)
        local colorCode = args[1]
        if not colorCode then
            Terminal.UI.OutputFrame.BackgroundColor3 = Terminal.Config.BackgroundColor
            Terminal.State.TextColor = Terminal.Config.DefaultTextColor
            Terminal.Commands.cls(); Terminal.UIManager.CreateNewInputLine()
            return
        end
        
        local colorMap = {["0"]=Color3.fromRGB(12,12,12),["1"]=Color3.fromRGB(0,55,218),["2"]=Color3.fromRGB(19,161,14),["3"]=Color3.fromRGB(58,150,221),["4"]=Color3.fromRGB(197,15,31),["5"]=Color3.fromRGB(136,23,152),["6"]=Color3.fromRGB(193,156,0),["7"]=Color3.fromRGB(204,204,204),["8"]=Color3.fromRGB(118,118,118),["9"]=Color3.fromRGB(59,120,255),["A"]=Color3.fromRGB(22,198,12),["B"]=Color3.fromRGB(97,214,214),["C"]=Color3.fromRGB(231,72,86),["D"]=Color3.fromRGB(180,0,158),["E"]=Color3.fromRGB(249,241,165),["F"]=Color3.fromRGB(242,242,242)};
        
        if #colorCode == 2 then
            local bgCode, fgCode = colorCode:sub(1,1):upper(), colorCode:sub(2,2):upper()
            if colorMap[bgCode] then Terminal.UI.OutputFrame.BackgroundColor3 = colorMap[bgCode] end
            if colorMap[fgCode] then Terminal.State.TextColor = colorMap[fgCode] end
            Terminal.Commands.cls(); Terminal.UIManager.CreateNewInputLine()
        else
            Terminal.UIManager.Print("Sets the default console foreground and background colors.")
        end
    end,
    
    -- feature commands
    aimbot = function(args)
        local subCommand = args[1] and args[1]:lower()
        if subCommand == "on" then
            Terminal.State.Aimbot.Enabled = true; Terminal.UIManager.Print("Aimbot has been enabled.")
        elseif subCommand == "off" then
            Terminal.State.Aimbot.Enabled = false; Terminal.UIManager.Print("Aimbot has been disabled.")
        elseif subCommand == "status" then
            Terminal.UIManager.Print("Aimbot is currently " .. (Terminal.State.Aimbot.Enabled and "enabled" or "disabled") .. ".")
        else
            Terminal.UIManager.Print("Usage: aimbot [on|off|status]")
        end
    end,
    
    esp = function(args)
        local subCommand = args[1] and args[1]:lower()
        if subCommand == "on" then
            Terminal.State.ESP.Enabled = true; Terminal.UIManager.Print("ESP has been enabled.")
        elseif subCommand == "off" then
            Terminal.State.ESP.Enabled = false; Terminal.Features.ESP.ClearDrawings(); Terminal.UIManager.Print("ESP has been disabled.")
        elseif subCommand == "status" then
            Terminal.UIManager.Print("ESP is currently " .. (Terminal.State.ESP.Enabled and "enabled" or "disabled") .. ".")
        else
            Terminal.UIManager.Print("Usage: esp [on|off|status]")
        end
    end,
}

Terminal.CommandAliases = {
    mkdir = "md",
    rmdir = "rd",
    rename = "ren",
    erase = "del",
}


--- Creates the UI and connects all events.
function Terminal.Initialize()
    if Terminal.State.IsInitialized then return end
    
    -- main screen gui
    Terminal.UI.ScreenGui = Instance.new("ScreenGui")
    Terminal.UI.ScreenGui.Name = "LuauTerminal"
    Terminal.UI.ScreenGui.ResetOnSpawn = false
    
    -- main window frame
    Terminal.UI.Window = Instance.new("Frame", Terminal.UI.ScreenGui)
    Terminal.UI.Window.Name = "Window"
    Terminal.UI.Window.Size = UDim2.fromOffset(800, 500)
    Terminal.UI.Window.Position = UDim2.new(0.5, -400, 0.5, -250)
    Terminal.UI.Window.BackgroundColor3 = Terminal.Config.BackgroundColor
    Terminal.UI.Window.ClipsDescendants = true
    
    -- title bar for dragging
    Terminal.UI.TitleBar = Instance.new("Frame", Terminal.UI.Window)
    Terminal.UI.TitleBar.Name = "TitleBar"
    Terminal.UI.TitleBar.Size = UDim2.new(1, 0, 0, 30)
    Terminal.UI.TitleBar.BackgroundColor3 = Terminal.Config.TitleBarColor
    
    Terminal.UI.TitleLabel = Instance.new("TextLabel", Terminal.UI.TitleBar)
    Terminal.UI.TitleLabel.Name = "TitleLabel"
    Terminal.UI.TitleLabel.Text = "Luau Terminal"
    Terminal.UI.TitleLabel.Font = Enum.Font.SourceSans
    Terminal.UI.TitleLabel.TextColor3 = Terminal.Config.DefaultTextColor
    Terminal.UI.TitleLabel.TextSize = 14
    Terminal.UI.TitleLabel.Position = UDim2.fromOffset(10, 0)
    Terminal.UI.TitleLabel.Size = UDim2.new(1, -20, 1, 0)
    Terminal.UI.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- output scrolling frame
    Terminal.UI.OutputFrame = Instance.new("ScrollingFrame", Terminal.UI.Window)
    Terminal.UI.OutputFrame.Name = "OutputFrame"
    Terminal.UI.OutputFrame.Position = UDim2.fromOffset(5, 30)
    Terminal.UI.OutputFrame.Size = UDim2.new(1, -10, 1, -35)
    Terminal.UI.OutputFrame.BackgroundColor3 = Terminal.Config.BackgroundColor
    Terminal.UI.OutputFrame.BorderSizePixel = 0
    Terminal.UI.OutputFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    Terminal.UI.OutputFrame.ScrollBarThickness = 8
    
    local listLayout = Instance.new("UIListLayout", Terminal.UI.OutputFrame)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    
    -- resize handle
    Terminal.UI.ResizeHandle = Instance.new("ImageButton", Terminal.UI.Window)
    Terminal.UI.ResizeHandle.Name = "ResizeHandle"
    Terminal.UI.ResizeHandle.Image = "rbxassetid://1644481079"
    Terminal.UI.ResizeHandle.ImageColor3 = Color3.fromRGB(100, 100, 100)
    Terminal.UI.ResizeHandle.BackgroundTransparency = 1
    Terminal.UI.ResizeHandle.Size = UDim2.fromOffset(15, 15)
    Terminal.UI.ResizeHandle.AnchorPoint = Vector2.new(1, 1)
    Terminal.UI.ResizeHandle.Position = UDim2.new(1, 0, 1, 0)
    Terminal.UI.ResizeHandle.ZIndex = 10
    
    -- cursor
    Terminal.UI.Cursor = Instance.new("Frame", Terminal.UI.OutputFrame)
    Terminal.UI.Cursor.Name = "Cursor"
    Terminal.UI.Cursor.Size = UDim2.fromOffset(8, Terminal.Config.FontSize)
    Terminal.UI.Cursor.BackgroundColor3 = Terminal.State.TextColor
    Terminal.UI.Cursor.BorderSizePixel = 0
    Terminal.UI.Cursor.ZIndex = 5
    
    -- connect input events
    Terminal.Connections.DragBegan = Terminal.UI.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Terminal.State.IsDragging = true; Terminal.State.DragVelocity = Vector2.zero
        end
    end)
    
    Terminal.Connections.DragEnded = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Terminal.State.IsDragging = false; Terminal.State.IsResizing = false
        end
    end)

    Terminal.Connections.ResizeBegan = Terminal.UI.ResizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Terminal.State.IsResizing = true
        end
    end)
    
    Terminal.Connections.HistoryInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and Terminal.UI.ActiveInputBox and Terminal.UI.ActiveInputBox:IsFocused() then
            if input.KeyCode == Enum.KeyCode.Up then
                Terminal.State.HistoryIndex = math.max(1, Terminal.State.HistoryIndex - 1)
                Terminal.UI.ActiveInputBox.Text = Terminal.State.CommandHistory[Terminal.State.HistoryIndex] or ""
            elseif input.KeyCode == Enum.KeyCode.Down then
                Terminal.State.HistoryIndex = math.min(#Terminal.State.CommandHistory + 1, Terminal.State.HistoryIndex + 1)
                Terminal.UI.ActiveInputBox.Text = Terminal.State.CommandHistory[Terminal.State.HistoryIndex] or ""
            end
        end
    end)
    
    -- connect the main loop for updates
    local lastMousePosition = UserInputService:GetMouseLocation()
    Terminal.Connections.MainLoop = RunService.RenderStepped:Connect(function(deltaTime)
        local currentMousePosition = UserInputService:GetMouseLocation()
        local mouseDelta = currentMousePosition - lastMousePosition
        
        if Terminal.State.IsDragging then
            Terminal.State.DragVelocity = mouseDelta / deltaTime
            Terminal.UI.Window.Position += UDim2.fromOffset(mouseDelta.X, mouseDelta.Y)
        else
            if Terminal.State.DragVelocity.Magnitude > 0.1 then
                Terminal.UI.Window.Position += UDim2.fromOffset(Terminal.State.DragVelocity.X * deltaTime, Terminal.State.DragVelocity.Y * deltaTime)
                Terminal.State.DragVelocity *= Terminal.Config.InertialDamping
            end
        end

        if Terminal.State.IsResizing then
            Terminal.UI.Window.Size += UDim2.fromOffset(mouseDelta.X, mouseDelta.Y)
        end
        
        if Terminal.UI.ActiveInputBox and Terminal.UI.ActiveInputBox:IsFocused() then
            local text = Terminal.UI.ActiveInputBox.Text
            local cursorPositionInString = Terminal.UI.ActiveInputBox.CursorPosition - 1
            local textUpToCursor = text:sub(1, cursorPositionInString)
            local textBounds = TextService:GetTextSize(textUpToCursor, Terminal.Config.FontSize, Terminal.Config.Font, Terminal.UI.ActiveInputBox.AbsoluteSize)
            
            Terminal.UI.Cursor.Position = UDim2.fromOffset(
                Terminal.UI.ActiveInputBox.AbsolutePosition.X - Terminal.UI.OutputFrame.AbsolutePosition.X + textBounds.X,
                Terminal.UI.ActiveInputBox.AbsolutePosition.Y - Terminal.UI.OutputFrame.AbsolutePosition.Y
            )
        end
        
        lastMousePosition = currentMousePosition
    end)
    
    -- connect the separate feature loop
    Terminal.Connections.FeatureLoop = RunService.RenderStepped:Connect(function()
        if Terminal.State.Aimbot.Enabled then Terminal.Features.Aimbot.Update() end
        if Terminal.State.ESP.Enabled then Terminal.Features.ESP.Update() end
    end)
    
    -- start cursor blink loop
    Terminal.Connections.CursorBlinkLoop = task.spawn(function()
        while Terminal.State.IsInitialized do
            local isVisible = false
            if Terminal.UI.ActiveInputBox and Terminal.UI.ActiveInputBox:IsFocused() then
                isVisible = not Terminal.UI.Cursor.Visible
            end
            Terminal.UI.Cursor.Visible = isVisible
            task.wait(Terminal.Config.CursorBlinkRate)
        end
    end)

    -- initial lines
    Terminal.UIManager.Print("Luau Terminal [Version 1.2.0]")
    Terminal.UIManager.Print("(c) Luau Systems. All rights reserved.")
    Terminal.UIManager.Print("")
    Terminal.UIManager.CreateNewInputLine()
    
    Terminal.UI.ScreenGui.Parent = CoreGui
    Terminal.State.IsInitialized = true
end

--- Gracefully shuts down the Terminal, cleaning up all resources.
function Terminal.Shutdown()
    if not Terminal.State.IsInitialized then return end
    
    Terminal.State.IsInitialized = false
    
    -- disconnect all event connections
    for name, connection in pairs(Terminal.Connections) do
        if connection then
            connection:Disconnect()
            Terminal.Connections[name] = nil
        end
    end
    
    -- clear drawings and destroy ui
    Terminal.Features.ESP.ClearDrawings()
    if Terminal.UI.ScreenGui then
        Terminal.UI.ScreenGui:Destroy()
    end
    
    print("Luau Terminal has been shut down.")
end


-- start the command prompt
Terminal.Initialize()

print("Luau Terminal Loaded. Type 'help' for a list of commands.")
