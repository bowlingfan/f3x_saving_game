-- services
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
local players = game:GetService("Players")

-- remote events
local remoteEventsFolder = replicatedStorage:WaitForChild("remoteEvents")
local buildsDatabaseEvent = remoteEventsFolder.buildsDatabaseEvent
local statusMessageEvent = remoteEventsFolder.sendStatusMessage
local progressBarEvent = remoteEventsFolder.progressBarEvent
local cooldownEvent = remoteEventsFolder.cooldownEvent

-- ui
local screenGUI = script.Parent
local showButton = screenGUI.button
local container = screenGUI.container
local header = container.header
local main = container.main
local exitButton = header.exitButton

local warningContainer = screenGUI.warning
local warningHeader = warningContainer.header
local warningMain = warningContainer.main
local warningButtons = warningMain.buttons

-- variables
local player = players.LocalPlayer
local showingUI = false
local showingUIDebounce = false

local slotDelete

-- set up UI on launch
function setupUI()
	container.Size = UDim2.fromScale(0,0)
	container.Visible = false
	warningContainer.Size = UDim2.fromScale(0,0)
	warningContainer.Visible = false
	setupSaveSlots()
end

-- sets up the save slots user experience, binding click events.
function setupSaveSlots()
	for _, frame in main:GetChildren() do
		if frame:IsA("Frame") then
			local slotNumber = string.sub(frame.Name, string.len(frame.Name), string.len(frame.Name))

			frame.buttons.deleteButton.MouseButton1Down:Connect(function()
				confirmDeletion(slotNumber)
			end)

			frame.buttons.loadButton.MouseButton1Down:Connect(function()
				callLoad(slotNumber)
			end)

			frame.buttons.saveButton.MouseButton1Down:Connect(function()
				callSave(slotNumber)
			end)
		end
	end
end 

-- save button pressed
function callSave(slot)
	buildsDatabaseEvent:FireServer("save", slot)
end

-- load button pressed
function callLoad(slot)
	buildsDatabaseEvent:FireServer("load", slot)
end

-- confirmation of deletion after clicking confirm from a warning screen
function callDelete()
	buildsDatabaseEvent:FireServer("delete", slotDelete)
	tweenService:Create(warningContainer, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 0)}):Play()
end

-- pops up a warning screen to "confirm deletion" after pressing the delete button.
function confirmDeletion(slot)
	slotDelete = slot
	warningMain.msg.Text = "Are you sure you want to delete Slot " .. slot .. "?"
	warningContainer.Visible = true
	tweenService:Create(warningContainer, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.3, 0.5)}):Play()
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

-- connects with the 15 second cooldown that the saving system forces to prevent multiclicking on save/load/delete for lagging
-- hides the buttons and covers the right side of the UI (which is also where the save/load/delete buttons are located)
function updateCooldownUI(toShow)
	container.cooldown.Visible = toShow
	
	for _, slot in main:GetChildren() do
		if slot:IsA("Frame") then
			slot.buttons.Visible = not toShow
		end
	end
end

-- after saving or deleting, this informs the user of the storage used and date saved.
function updateUIFromBuildsEvent(slot, partsSaved, dateSaved,status)
	if status == "load" then return end
	local percentage = partsSaved ~= "---" and math.ceil((1 - (partsSaved / 20000)) * 100) or partsSaved
	local frame = "saveSlot" .. slot
	frame = main[frame]
	frame.information.storage.Text = "Storage: " .. percentage .. "%"
	frame.information.dateSaved.Text = "Saved: " .. dateSaved
end

-- run
setupUI()

-- event connections
showButton.MouseButton1Down:Connect(containerDisplay)
-- special: reusing a function to reduce redundancy
exitButton.MouseButton1Down:Connect(function() showingUI = true; containerDisplay() end)
-- special: triggers a tween
warningButtons.cancelButton.MouseButton1Down:Connect(function() tweenService:Create(warningContainer, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 0)}):Play() end)
warningHeader.exitButton.MouseButton1Down:Connect(function() tweenService:Create(warningContainer, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 0)}):Play() end)

warningButtons.confirmButton.MouseButton1Down:Connect(callDelete)
buildsDatabaseEvent.OnClientEvent:Connect(updateUIFromBuildsEvent)
cooldownEvent.OnClientEvent:Connect(updateCooldownUI)