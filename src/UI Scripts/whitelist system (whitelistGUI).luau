-- services
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
local players = game:GetService("Players")

-- remote events
local remoteEventsFolder = replicatedStorage:WaitForChild("remoteEvents")
local whitelistedPlayersDatabaseEvent = remoteEventsFolder.whitelistedPlayersDatabaseEvent
local statusMessageEvent = remoteEventsFolder.sendStatusMessage

-- ui
local screenGUI = script.Parent
local showButton = screenGUI.button
local container = screenGUI.container
local header = container.header
local main = container.main
local exitButton = header.exitButton
local buttons = main.buttons
local listOfPlayers = main.listOfPlayers
local textBox = main.textBox

-- inside script --> templates and whatever
local playerTemplate = script.playerTemplate
local msgTemplate = script.msg
local pLAlphabetTemplate = script.alphabetPlayerListTemplate

-- variables
local player = players.LocalPlayer
local whitelistedPlayers = {}
local showingUI = false
local showingUIDebounce = false

-- set up UI on launch
function setupUI()
	textBox.inputBox.Text = ""
	container.Size = UDim2.fromScale(0,0)
	
	putAdminsIntoPlayerList()
end

-- creates player frames that are put into the list of players "whitelisted"
function createPlayerFrame(playerName)
	local clonedPlayerFrame = playerTemplate:Clone()
	clonedPlayerFrame.Name = playerName
	clonedPlayerFrame.Text = playerName
	--clonedPlayerFrame.Parent = listOfPlayers

	-- we sort the names by letter, and we sort every player frame into containers that hold a specific first letter of every player that is whitelisted.
	-- ex. frame "B" would hold all player names that start with B.
	local firstLetterOfPlayerName = string.upper(string.sub(playerName, 0, 1))
	if not listOfPlayers:FindFirstChild(firstLetterOfPlayerName) then
		local newLetterFrame = pLAlphabetTemplate:Clone()
		newLetterFrame.Name = firstLetterOfPlayerName
		newLetterFrame.Parent = listOfPlayers
		clonedPlayerFrame.Parent = newLetterFrame
	else
		clonedPlayerFrame.Parent = listOfPlayers:FindFirstChild(firstLetterOfPlayerName)
	end

	-- if players are admins cause we're special.
	if playerName == "bowlingfan21317" then
		script.bowlingfan21317.Parent = clonedPlayerFrame
		clonedPlayerFrame:SetAttribute("isPermanent", true)
	end
end

function putAdminsIntoPlayerList()
	createPlayerFrame("bowlingfan21317")
end

function getAllPlayersFromWhitelist()
	for letter, playersInLetter in whitelistedPlayers do
		for _, playerName in playersInLetter do
			createPlayerFrame(playerName)
		end
	end
end

-- press a button to either show or hide the UI itself
function containerDisplay()
	-- debounce so that the UI can actually hide itself using property .Visible
	if showingUIDebounce then return end
	showingUIDebounce = true
	showingUI = not showingUI
	
	if showingUI then
		container.Visible = true
		tweenService:Create(container, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.3, 0.5)}):Play()
		task.wait(1)
	else
		tweenService:Create(container, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 0)}):Play()
		task.wait(1)
		container.Visible = false
	end
	showingUIDebounce = false
end

-- allows for realtime searching of players: for every character added or removed into the textbox for searching players, this function runs.
function findPlayerFromInput()
	local input = textBox.inputBox.Text
	local numberInput = tonumber(input)

	if numberInput ~= nil then
		findWithNumber(numberInput)
	elseif input ~= "" then
		findWithString(input)
	else
		resetFinder()
	end
end

-- searches for a player name using a User ID.
-- this exactly retrieves a player name, in the cost of requiring the user to know a specific user ID.
function findWithNumber(input)
	local playerName
	local success, errorMsg = pcall(function()
		playerName = players:GetNameFromUserIdAsync(input)
	end)

	if success then
		findWithString(playerName)
	end
end

-- searches for a player name using a particular keyword.
-- this only searches for a match starting from left to right.
-- for example: bowlingfan21317
-- bowl,bowlingfan will find the needed username, while lingfan21317 and owling would not.
function findWithString(input)
	-- find the frame that stores all player names starting with the first letter inputted into the searchbox.
	local firstLetterOfPlayerName = string.upper(string.sub(input, 0, 1))
	for _, letterFrame in listOfPlayers:GetChildren() do
		if letterFrame:IsA("Frame") then
			letterFrame.Visible = false
			if letterFrame.Name == firstLetterOfPlayerName then
				letterFrame.Visible = true
			end
		end
	end

	-- find player names in the frame that all at least match the keyword typed from parameter input.
	if listOfPlayers:FindFirstChild(firstLetterOfPlayerName) then
		for _, playerLabel in listOfPlayers[firstLetterOfPlayerName]:GetChildren() do
			if playerLabel:IsA("TextLabel") then
				playerLabel.Visible = false
				playerLabel.TextColor3 = Color3.fromRGB(255,255,255)
				if string.find(string.lower(playerLabel.Name), string.lower(input)) ~= nil then
					-- we can find it, at least.
					playerLabel.Visible = true
					if playerLabel.Name == input then
						-- the username and the input EXACTLY match! mark it to let them know it exists.
						playerLabel.TextColor3 = Color3.fromRGB(176, 0, 182)
					end
				end
			end
		end
	end
end

-- if no characters exist, or the "clear input" button was pressed, reset the search such that all whitelisted players are shown.
function resetFinder()
	for _, letterFrame in listOfPlayers:GetChildren() do
		if letterFrame:IsA("Frame") and string.len(letterFrame.Name) == 1 then
			letterFrame.Visible = true
			
			for _, playerLabel in letterFrame:GetChildren() do
				if playerLabel:IsA("TextLabel") then
					playerLabel.Visible = true
					playerLabel.TextColor3 = Color3.fromRGB(255,255,255)
				end
			end
		end
	end
end

-- when pressing "add to whitelist":
-- ensure the value inputted is valid, and that the player doesn't already exist on the whitelist.
function validatedInput(input)
	if input == "" then return false, "can't input nothing." end
	local playerName = nil
	local success, errorMsg
	
	-- know whether the input is a user ID or string.
	local numberInput = tonumber(input)
	if numberInput ~= nil then
		success, errorMsg = pcall(function()
			playerName = players:GetNameFromUserIdAsync(input)
		end)
	else
		playerName = input
	end
	
	-- if inputting a user id, does it actually exist on roblox?
	if numberInput ~= nil and not success then return false, input .. " probably doesn't exist, try again?" end
	playerName = string.lower(playerName)
	local firstLetterOfPlayerName = string.upper(string.sub(playerName, 0, 1))
	if listOfPlayers:FindFirstChild(firstLetterOfPlayerName) then
		for _, playerFrame in listOfPlayers:FindFirstChild(firstLetterOfPlayerName):GetChildren() do
			-- does it already exist?
			if string.lower(playerFrame.Name) == playerName then
				return false, "already exists"
			end
		end
	end
	
	return true, playerName
end

function addToWhiteListPressed()
	local text = textBox.inputBox.Text
	local success, errorMsg = validatedInput(text)
	-- sendMessage sends a visible error message to the user that enacted this action.
	if not success then sendMessage(errorMsg) return end
	createPlayerFrame(errorMsg)
	whitelistedPlayersDatabaseEvent:FireServer(errorMsg, "add")
end

function removeFromWhiteListPressed()
	local removed = false
	local text = textBox.inputBox.Text
	local playerName = nil
	local success, errorMsg

	-- know whether the input is a user ID or string.
	local numberInput = tonumber(text)
	if numberInput ~= nil then
		success, errorMsg = pcall(function()
			playerName = players:GetNameFromUserIdAsync(text)
		end)
	else
		playerName = text
	end
	
	playerName = string.lower(playerName)
	-- if the user tries to remove the admins..
	if playerName == "bowlingfan21317" then sendMessage("really be trying to remove yourselves huh") return end
	local firstLetterOfPlayerName = string.upper(string.sub(playerName, 0, 1))
	if listOfPlayers:FindFirstChild(firstLetterOfPlayerName) then
		-- does player frame exist?
		local letterFrame = listOfPlayers:FindFirstChild(firstLetterOfPlayerName)
		if letterFrame:FindFirstChild(string.lower(playerName)) then
			removed = true
			-- remove now!
			letterFrame:FindFirstChild(string.lower(playerName)):Destroy()
		end
		
		if #letterFrame:GetChildren() == 1 then
			letterFrame:Destroy()
		end
	end
	
	if not removed then
		sendMessage("nothing was removed")
	end
	
	-- remove it from server to reflect changes.
	whitelistedPlayersDatabaseEvent:FireServer(playerName, "remove")
end

-- send an informational message explaining their mistakes or that something worked.
function sendMessage(msg)
	if container:FindFirstChild("msg") then
		container:FindFirstChild("msg"):Destroy()
	end

	local newMessage = msgTemplate:Clone()
	newMessage.display.Text = msg
	newMessage.Parent = container

	tweenService:Create(newMessage, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0, 0.5)}):Play()
	task.delay(1, function()
		if newMessage then
			tweenService:Create(newMessage, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0, -0.05)}):Play()
		end
	end)
end

function clearInputPressed()
	textBox.inputBox.Text = ""
	resetFinder()
end

-- run
setupUI()

-- event connections
showButton.MouseButton1Down:Connect(containerDisplay)
-- special: reusing a function to reduce redundancy
exitButton.MouseButton1Down:Connect(function() showingUI = true; containerDisplay() end)

textBox.inputBox:GetPropertyChangedSignal("Text"):Connect(findPlayerFromInput)
buttons.clearButton.MouseButton1Down:Connect(clearInputPressed)
buttons.addButton.MouseButton1Down:Connect(addToWhiteListPressed)
buttons.removeButton.MouseButton1Down:Connect(removeFromWhiteListPressed)
statusMessageEvent.OnClientEvent:Connect(sendMessage)

-- special: sets a variable that is received from the server sending information to the client and then calls the main function getAllPlayersFromWhitelist().
whitelistedPlayersDatabaseEvent.OnClientEvent:Connect(function(wlPlayersServer) whitelistedPlayers = wlPlayersServer getAllPlayersFromWhitelist() end)