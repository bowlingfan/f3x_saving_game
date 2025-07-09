-- services
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
local players = game:GetService("Players")

-- remote events
local remoteEventsFolder = replicatedStorage:WaitForChild("remoteEvents")
local buildsDatabaseEvent = remoteEventsFolder.buildsDatabaseEvent
local progressBarEvent = remoteEventsFolder.progressBarEvent

-- ui
local screenGUI = script.Parent
local bar = screenGUI.bar
local fill = bar.fill
local progressLabel = bar.progress

progressBarEvent.OnClientEvent:Connect(function(status, progress, total, slotMod)
	-- changes text based on if we're saving or loading slots
	if slotMod == "save" then
		bar.label.Text = "Saving... (You may experience lag.)"
	elseif slotMod == "load" then
		bar.label.Text = "Loading... (You may experience lag.)"
	elseif status ~= "hide" then
		return
	end

	if status == "show" then
		fill.Size = UDim2.fromScale(0,1)
		progressLabel.Text = 0 .. " / " .. total
		bar.Visible = true
	elseif status == "update" then
		progressLabel.Text = progress .. " / " .. total
		fill.Size = UDim2.fromScale(progress / total, 1)
	elseif status == "hide" then
		bar.Visible = false
	end
end)