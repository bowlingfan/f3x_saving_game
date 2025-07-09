-- services
local players = game:GetService("Players")
local dataStores = game:GetService("DataStoreService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")

-- data stores
local whitelistedPlayersDatabase = dataStores:GetDataStore("whitelistedPlayersDatabase")
local savedBuildsDatabase = dataStores:GetDataStore("savedBuildsDatabase")
local whitelistedPlayers = {}
local savedBuilds = {["1"] = {}, 
					 ["2"] = {}, 
					 ["3"] = {}}
local loadedWhitelistedPlayers, loadedSavedBuilds = false, false
-- ui
local uiFolder = script.UI
local savedBuildsGUI = uiFolder.savedBuildsGUI
local whitelistGUI = uiFolder.whitelistGUI
local progressBarGUI = uiFolder.progressBarGUI

-- variables
local remoteEventsFolder = script.remoteEvents
local ownerID = game.CreatorId
local temporaryAdmins = {43838303}

-- remoteEvents
local buildsDatabaseEvent = remoteEventsFolder.buildsDatabaseEvent
local whitelistedPlayersDatabaseEvent = remoteEventsFolder.whitelistedPlayersDatabaseEvent
local statusMessageEvent = remoteEventsFolder.sendStatusMessage
local progressBarEvent = remoteEventsFolder.progressBarEvent
local cooldownEvent = remoteEventsFolder.cooldownEvent

remoteEventsFolder.Parent = replicatedStorage

local slotModificationRunning = false

-- squash for SERDE (compressing data to be saved on roblox datastores)
local squash = require(script["Squash SER-DE"])

local sq_T = squash.T
local sq_uint = squash.uint
local sq_vlq = squash.vlq() --variable length quantities
local sq_bool = squash.boolean()
local sq_str = squash.string()
local sq_float = squash.number(4)
local sq_arr = squash.array
local sq_opt = squash.opt
local sq_record = squash.record

local partDataSerdes = sq_record {
	Shape = sq_T(sq_opt(sq_str)),
	Material = sq_T(sq_str),
	Transparency = sq_T(sq_float),
	Reflectance = sq_T(sq_float),
	Anchored = sq_T(sq_bool),
	CanCollide = sq_T(sq_bool),
	Position = sq_T(sq_record {
		X = sq_T(sq_float),
		Y = sq_T(sq_float),
		Z = sq_T(sq_float),
	}),
	Size = sq_T(sq_record {
		X = sq_T(sq_vlq),
		Y = sq_T(sq_vlq),
		Z = sq_T(sq_vlq),
	}),
	Rotation = sq_T(sq_record {
		X = sq_T(sq_float),
		Y = sq_T(sq_float),
		Z = sq_T(sq_float),
	}),
	Color = sq_T(sq_record {
		R = sq_T(sq_float),
		G = sq_T(sq_float),
		B = sq_T(sq_float),
	}),
	Surface = sq_T(sq_record {
		FrontSurface = sq_T(sq_str),
		BackSurface = sq_T(sq_str), 
		TopSurface = sq_T(sq_str),
		BottomSurface = sq_T(sq_str),
		LeftSurface = sq_T(sq_str),
		RightSurface = sq_T(sq_str),
	}),
	Mesh = sq_T(sq_opt(sq_record {
		MeshType = sq_T(sq_str),
		Scale = sq_T(sq_record {
			X = sq_T(sq_vlq),
			Y = sq_T(sq_vlq),
			Z = sq_T(sq_vlq),
		}),
		Offset = sq_T(sq_record {
			X = sq_T(sq_vlq),
			Y = sq_T(sq_vlq),
			Z = sq_T(sq_vlq),
		}),
		MeshId = sq_T(sq_opt(sq_str)),
		TextureId = sq_T(sq_opt(sq_str)),
		VertexColor = sq_T(sq_opt(sq_record {
			X = sq_T(sq_vlq),
			Y = sq_T(sq_vlq),
			Z = sq_T(sq_vlq),
		})),
	})),
	Decals = sq_T(sq_opt(sq_arr(sq_str))),
	Textures = sq_T(sq_opt(sq_arr(sq_str))),
	SpotLight = sq_T(sq_opt(sq_record {
		Angle = sq_T(sq_uint(2)),
		Range = sq_T(sq_uint(1)),
		Color = sq_T(sq_record {
			R = sq_T(sq_float),
			G = sq_T(sq_float),
			B = sq_T(sq_float),
		}),
		Brightness = sq_T(sq_float),
		Face = sq_T(sq_str),
		Shadows = sq_T(sq_bool),
	})),
	PointLight = sq_T(sq_opt(sq_record {
		Color = sq_T(sq_record {
			R = sq_T(sq_float),
			G = sq_T(sq_float),
			B = sq_T(sq_float),
		}),
		Range = sq_T(sq_uint(1)),
		Brightness = sq_T(sq_float),
		Shadows = sq_T(sq_bool),
	})),
	SurfaceLight = sq_T(sq_opt(sq_record {
		Angle = sq_T(sq_uint(2)),
		Range = sq_T(sq_uint(1)),
		Color = sq_T(sq_record {
			R = sq_T(sq_float),
			G = sq_T(sq_float),
			B = sq_T(sq_float),
		}),
		Brightness = sq_T(sq_float),
		Face = sq_T(sq_str),
		Shadows = sq_T(sq_bool),
	})),
	Smoke = sq_T(sq_opt(sq_record {
		Color = sq_T(sq_record {
			R = sq_T(sq_float),
			G = sq_T(sq_float),
			B = sq_T(sq_float),
		}),
		Opacity = sq_T(sq_float),
		RiseVelocity = sq_T(sq_float),
		Size = sq_T(sq_float),
	})),
	Fire = sq_T(sq_opt(sq_record {
		Color = sq_T(sq_record {
			R = sq_T(sq_float),
			G = sq_T(sq_float),
			B = sq_T(sq_float),
		}),
		SecondaryColor = sq_T(sq_record {
			R = sq_T(sq_float),
			G = sq_T(sq_float),
			B = sq_T(sq_float),
		}),
		Heat = sq_T(sq_float),
		Size = sq_T(sq_float),
	})),
	Sparkles = sq_T(sq_opt(sq_record {
		SparkleColor = sq_T(sq_record {
			R = sq_T(sq_float),
			G = sq_T(sq_float),
			B = sq_T(sq_float),
		}),
	})),
}

function isPlayerOnWhiteList(playerNameCheck)
	for letter, playersInLetter in whitelistedPlayers do
		for _, playerName in playersInLetter do
			if string.lower(playerName) == string.lower(playerNameCheck) then
				return true
			end
		end
	end
	
	return false
end

-- we have 2 data stores: whitelistedPlayers and savedBuilds, so we try to get their data from the datastore/database.
function loadSavedData()
	-- booleans loadedWhitelistedPlayers, loadedSavedBuilds exist to prevent getting data from the server too many times which prior, already was successful.
	if not loadedWhitelistedPlayers then
		local success, whitelistedData = pcall(function()
			return whitelistedPlayersDatabase:GetAsync("whitelistedPlayers")
		end)

		if success and whitelistedData ~= nil then
			loadedWhitelistedPlayers = true
			whitelistedPlayers = whitelistedData
		end
	end
	
	if not loadedSavedBuilds then
		for i = 1, 3 do
			local success, savedBuildsData = pcall(function()
				return savedBuildsDatabase:GetAsync(i)
			end)

			if success and savedBuildsData ~= nil then
				loadedSavedBuilds = true
				savedBuilds[tostring(i)] = savedBuildsData
			end
		end
	end
end

function playerAddedEvent(player)
	progressBarGUI:Clone().Parent = player.PlayerGui

	if player.UserId == ownerID or table.find(temporaryAdmins, player.UserId) then
		loadSavedData()
		savedBuildsGUI:Clone().Parent = player.PlayerGui
		whitelistGUI:Clone().Parent = player.PlayerGui
		
		-- display onto admin clients
		whitelistedPlayersDatabaseEvent:FireClient(player, whitelistedPlayers)
		for i = 1, 3 do
			local index = tostring(i)
			if savedBuilds[index] and savedBuilds[index][2] and savedBuilds[index][3] then
				buildsDatabaseEvent:FireClient(player, i, savedBuilds[index][2], savedBuilds[index][3])
			end
		end
	elseif not isPlayerOnWhiteList(player.Name) then -- uhoh player is not on whitelist, kick them NOW!
		player:Kick("not accessible.")
	end 
end

-- if anything needs to be changed for the list of players whitelisted.
function whitelistPlayersChanged(player, playerName, status)
	local firstLetterOfPlayerName = string.upper(string.sub(playerName, 0, 1))

	-- check whether we're adding or removing players from the whitelist.
	if status == "add" then
		if not whitelistedPlayers[firstLetterOfPlayerName] then
			whitelistedPlayers[firstLetterOfPlayerName] = {}
		end
		table.insert(whitelistedPlayers[firstLetterOfPlayerName], playerName)
	elseif status == "remove" then
		-- there are a few errors but they don't affect anything so i don't care lol
		local indexToRemove = table.find(whitelistedPlayers[firstLetterOfPlayerName], playerName)
		if indexToRemove then
			table.remove(whitelistedPlayers[firstLetterOfPlayerName], indexToRemove)
		end
		if #whitelistedPlayers[firstLetterOfPlayerName] <= 0 then
			table.clear(whitelistedPlayers[firstLetterOfPlayerName])
			whitelistedPlayers[firstLetterOfPlayerName] = nil
		end
	end

	local success, errorMessage = pcall(function()
		whitelistedPlayersDatabase:SetAsync("whitelistedPlayers", whitelistedPlayers)
	end)

	if not success then
		statusMessageEvent:FireClient(player, "unsuccessful..")
		warn(errorMessage)
	else
		if status == "add" then
			statusMessageEvent:FireClient(player, "successfully added player!")
		elseif status == "remove" then
			statusMessageEvent:FireClient(player, "successfully removed player!")
		end
	end
end

function saveBuilds(player, slot)
	slot = tostring(slot)
	local dateSaved = os.date("%x", os.time())
	local partsSaved = 0
	-- the slot we want to save data in
	local partsData = savedBuilds[slot]
	local allBuiltParts = workspace:GetChildren()
	progressBarEvent:FireAllClients("show", nil, #allBuiltParts - #players:GetPlayers() - 3, "save")
	
	savedBuilds[slot] = {}
	partsData = savedBuilds[slot]

	-- for every part in workspace
	for _, part in allBuiltParts do
		-- disregards anything that isn't a part --> includes models and folders.
		if not part:IsA("BasePart") or part:IsA("Terrain") then continue end
		if partsSaved >= 20000 then break end -- hit the limit
		
		-- preparation for buffering data
		local sq_cursor = squash.cursor()
		-- updates the progress bar to show progress of saving
		partsSaved += 1
		progressBarEvent:FireAllClients("update", partsSaved, #allBuiltParts - #players:GetPlayers() - 3, "save")
		
		-- first part stores main data about part like the location, size, and whatnot.
		-- NOTE: every property in the part is stored as a dictionary: property, value
		-- if the value is a Vector3, a Color3 or something with multiple values, we create an array to store each individual value that is a part of this multi-valued property.
		local partData = {}
		if part:IsA("Part") then
			partData.Shape = part.Shape.Name
		end
		partData.Material = part.Material.Name
		partData.Transparency = part.Transparency
		partData.Reflectance = part.Reflectance
		partData.Anchored = part.Anchored
		partData.CanCollide = part.CanCollide
		
		partData.Position = {
			["X"] = part.Position.X,
			["Y"] = part.Position.Y,
			["Z"] = part.Position.Z,
		}
		partData.Size = {
			["X"] = part.Size.X,
			["Y"] = part.Size.Y,
			["Z"] = part.Size.Z,
		}
		partData.Rotation = {
			["X"] = part.Rotation.X,
			["Y"] = part.Rotation.Y,
			["Z"] = part.Rotation.Z,
		}
		partData.Color = {
			["R"] = part.Color.R,
			["G"] = part.Color.G,
			["B"] = part.Color.B,
		}
		partData.Surface = {
			["FrontSurface"] = part.FrontSurface.Name,
			["BackSurface"] = part.BackSurface.Name,
			["TopSurface"] = part.TopSurface.Name,
			["BottomSurface"] = part.BottomSurface.Name,
			["LeftSurface"] = part.LeftSurface.Name,
			["RightSurface"] = part.RightSurface.Name,
		}

		-- second part stores data about effects that are in the part, so extra cool details.
		for _, effects in part:GetChildren() do
			-- there  are a lot of if statements. excuse them. it was.. kind of needed
			if effects:IsA("SpecialMesh") then
				partData.Mesh = {}
				partData.Mesh.MeshType = effects.MeshType.Name
				partData.Mesh.Scale = {
					["X"] = effects.Scale.X,
					["Y"] = effects.Scale.Y,
					["Z"] = effects.Scale.Z,
				}
				partData.Mesh.Offset = {
					["X"] = effects.Offset.X,
					["Y"] = effects.Offset.Y,
					["Z"] = effects.Offset.Z,
				}

				if effects.MeshType.Name == "FileMesh" then
					partData.Mesh.MeshId = effects.MeshId
					partData.Mesh.TextureId = effects.TextureId
					partData.Mesh.VertexColor = {
						["X"] = effects.VertexColor.X,
						["Y"] = effects.VertexColor.Y,
						["Z"] = effects.VertexColor.Z,
					}
				end
			elseif effects:IsA("Decal") then
				-- you can have multiple decals on a part thanks to F3X, so we need to compress the data even further by putting all data utilized by F3X into one string.
				partData.Decals = {}
				local data = effects.Face.Name .. ";" .. effects.Texture  .. ";" .. effects.Transparency
				table.insert(partData.Decals, data)
			elseif effects:IsA("Texture") then
				-- you can have multiple textures on a part thanks to F3X, so we need to compress the data even further by putting all data utilized by F3X into one string.
				partData.Textures = {}
				local data = effects.Face.Name .. ";" .. effects.Texture  .. ";" .. effects.Transparency .. ";" .. effects.StudsPerTileU .. ";" .. effects.StudsPerTileV
				table.insert(partData.Textures, data)
			-- for some reason F3X only allows you to have one of the following effects down below.
			elseif effects:IsA("SpotLight") then
				partData.SpotLight = {}
				partData.SpotLight.Angle = effects.Angle
				partData.SpotLight.Range = effects.Range
				partData.SpotLight.Color = {
					["R"] = effects.Color.R,
					["G"] = effects.Color.G,
					["B"] = effects.Color.B,
				}
				partData.SpotLight.Brightness = effects.Brightness
				partData.SpotLight.Face = effects.Face.Name
				partData.SpotLight.Shadows = effects.Shadows
			elseif effects:IsA("PointLight") then
				partData.PointLight = {}
				partData.PointLight.Color = {
					["R"] = effects.Color.R,
					["G"] = effects.Color.G,
					["B"] = effects.Color.B,
				}
				partData.PointLight.Range = effects.Range
				partData.PointLight.Brightness = effects.Brightness
				partData.PointLight.Shadows = effects.Shadows
			elseif effects:IsA("SurfaceLight") then
				partData.SurfaceLight = {}
				partData.SurfaceLight.Angle = effects.Angle
				partData.SurfaceLight.Range = effects.Range
				partData.SurfaceLight.Color = {
					["R"] = effects.Color.R,
					["G"] = effects.Color.G,
					["B"] = effects.Color.B,
				}
				partData.SurfaceLight.Brightness = effects.Brightness
				partData.SurfaceLight.Face = effects.Face.Name
				partData.SurfaceLight.Shadows = effects.Shadows
			elseif effects:IsA("Smoke") then
				partData.Smoke = {}
				partData.Smoke.Color = {
					["R"] = effects.Color.R,
					["G"] = effects.Color.G,
					["B"] = effects.Color.B,
				}
				partData.Smoke.Opacity = effects.Opacity
				partData.Smoke.RiseVelocity = effects.RiseVelocity
				partData.Smoke.Size = effects.Size
			elseif effects:IsA("Fire") then
				partData.Fire = {}
				partData.Fire.Color = {
					["R"] = effects.Color.R,
					["G"] = effects.Color.G,
					["B"] = effects.Color.B,
				}
				partData.Fire.SecondaryColor = {
					["R"] = effects.SecondaryColor.R,
					["G"] = effects.SecondaryColor.G,
					["B"] = effects.SecondaryColor.B,
				}
				partData.Fire.Heat = effects.Heat
				partData.Fire.Size = effects.Size
			elseif effects:IsA("Sparkles") then
				partData.Sparkles = {}
				partData.Sparkles.SparkleColor = {
					["R"] = effects.SparkleColor.R,
					["G"] = effects.SparkleColor.G,
					["B"] = effects.SparkleColor.B,
				}
			end
		end

		-- serialize the data or encrypt it.
		partDataSerdes.ser(sq_cursor, partData)
		-- inserts it into the variable partsData so we can compress the data with serialization and save it as a slot.
		-- part.Name will be important when we need to classify the part that is being used like a Truss or a Wedge or a Part.
		table.insert(partsData, {sq_cursor, part.Name})
	end -- end of imporant operation: saving all parts.
	
	-- its time to save, this is the most important operation so we give it 5 tries and send any issues to the console.
	-- saves a list of parts and their properties, how many parts were saved and when it was saved.
	local toSaveFollowingData = {partsData, partsSaved, dateSaved}
	for i = 1, 5 do
		local success, errorMessage = pcall(function()
			savedBuildsDatabase:SetAsync(slot, toSaveFollowingData)
			savedBuilds[slot] = toSaveFollowingData
		end)

		if not success then
			warn(errorMessage)
			task.wait(2)
		else
			buildsDatabaseEvent:FireClient(player, slot, partsSaved, dateSaved)
			progressBarEvent:FireAllClients("hide", nil, nil)
			break
		end
	end
	
	delayToHideCooldown()
end

-- special types so that the loops in function loadBuilds know how to handle these "so called properties"
local specialTypes = {"Mesh", "Decals", "Textures", "SpotLight", "PointLight", "SurfaceLight", "Smoke", "Fire", "Sparkles"}
-- multiple different types of parts, so we need to store what kind of part will be added to the main game when loading from saved data.
function makePart(className)
	if className == "Truss" then
		return "TrussPart"
	elseif className == "Seat" then
		return "Seat"
	elseif className == "VehicleSeat" then
		return "VehicleSeat"
	elseif className == "CornerWedge" then
		return "CornerWedgePart"
	elseif className == "Wedge" then
		return "WedgePart"
	elseif className == "SpawnLocation" then
		return "SpawnLocation"
	else
		return "Part"
	end	
end

function loadBuilds(player, slot)
	slot = tostring(slot)
	-- ensure the slot actually has something and isn't nothing
	if savedBuilds[slot] == nil then return end
	-- counter of how many parts have loaded to use for displaying the progress bar.
	local loadedParts = 0
	progressBarEvent:FireAllClients("show", loadedParts, savedBuilds[slot][2], "load")
	-- loops through EVERY part in the saved slot.
	for _, bufferedPartData in savedBuilds[slot][1] do
		loadedParts += 1
		local newPart = Instance.new(makePart(bufferedPartData[2]))
		-- convert the data from buffered data to readable data
		local bufVal = squash.tobuffer(bufferedPartData[1])
		local cursor = squash.frombuffer(bufVal)
		local partData = partDataSerdes.des(cursor)
		
		-- for every property and value in the readable part data:
		for property, value in partData do
			-- if the property isn't an effect (ex. smoke, sparkles, spotlight) then:
			if not table.find(specialTypes, property) then
				-- check if the property is a table which implies that it's either a Surface (multiple options), a Color3 or a Vector3.
				if type(value) ~= "table" then
					-- just assign as when we made the saving happen, we made the variable names in partData the exact same as the part's properties.
					newPart[property] = value
				else
					if property == "Surface" then
						-- versatile; there could be 1 or 6 different surfaces being changed so we use a loop.
						for surface, surfaceValue in value do
							newPart[surface] = Enum.SurfaceType[surfaceValue]
						end
					elseif property == "Shape" then
						newPart[property] = Enum.SurfaceType[value]
					elseif property == "Color" then
						newPart[property] = Color3.new(value.R, value.G, value.B)
					else
						newPart[property] = Vector3.new(value.X, value.Y, value.Z)
					end
				end
			else
				-- if it's not decals or textures (since we formatted them into one string) then:
				if property ~= "Decals" and property ~= "Textures" then
					-- ensure the property when we use Instance.new() is a valid className.
					property = property == "Mesh" and "SpecialMesh" or property
					local effect = Instance.new(property)
					effect.Parent = newPart
					
					-- do the same magic as before (shown above)
					for effectProperty, e_Value in value do
						if type(e_Value) ~= "table" then
							effect[effectProperty] = e_Value
						elseif effectProperty == "Scale" or effectProperty == "Offset" or effectProperty == "VertexColor" then
							effect[effectProperty] = Vector3.new(e_Value.X, e_Value.Y, e_Value.Z)
						else
							effect[effectProperty] = Color3.new(e_Value.R, e_Value.G, e_Value.B)
						end
					end
				else
					-- otherwise, we know that the remaining properties are the decals and textures given to a particular part
					-- so we can just recompile the information given with the longstring!
					property = string.sub(property, 0, #property - 1)
					for _, longStringData in value do
						local effect = Instance.new(property)
						effect.Parent = newPart
						
						-- split the string into an array
						local data = string.split(longStringData, ";")
						-- now connect the data together with the created effect (either decal or texture).
						effect.Face = data[1]
						effect.Texture = data[2]
						effect.Transparency = data[3]
						
						if #data > 3 then
							effect.StudsPerTileU = data[4]
							effect.StudsPerTileV = data[5]
						end
					end
				end
			end
		end -- end of important operation: loading a part

		
		progressBarEvent:FireAllClients("update", loadedParts, savedBuilds[slot][2], "load")
		newPart.Parent = workspace
	end -- end of important operation: loading EVERY part.
	
	progressBarEvent:FireAllClients("hide", nil, nil)
	buildsDatabaseEvent:FireClient(player, nil,nil,nil,"load")
	delayToHideCooldown()
end

function deleteBuild(player, slot)
	slot = tostring(slot)
	
	local success, errorMessage = pcall(function()
		savedBuildsDatabase:RemoveAsync(slot)
	end)

	if not success then
		warn(errorMessage)
	else
		table.clear(savedBuilds[slot])
		savedBuilds[slot] = nil
		buildsDatabaseEvent:FireClient(player, slot, "---", "N/A")
	end
	
	delayToHideCooldown()
end

-- make a cooldown to prevent admins from spamming the save/load/delete buttons which can lag players heavily depending on device.
function delayToHideCooldown()
	task.delay(15, function()
		cooldownEvent:FireAllClients(false)
		slotModificationRunning = false
	end)
end

-- if anything needs to change for the saved builds datastore.
function buildsDataChanged(player, status, slot)
	-- ensure that the save/load/delete operations WILL not be interrupted.
	if slotModificationRunning then return end
	slotModificationRunning = true
	cooldownEvent:FireAllClients(true)
	if status == "save" then
		saveBuilds(player, slot)
	elseif status == "load" then
		loadBuilds(player, slot)
	elseif status == "delete" then
		deleteBuild(player, slot)
	end
end

-- event connections
players.PlayerAdded:Connect(playerAddedEvent)
buildsDatabaseEvent.OnServerEvent:Connect(buildsDataChanged)
whitelistedPlayersDatabaseEvent.OnServerEvent:Connect(whitelistPlayersChanged)
