local old_InitLobbyComm = InitLobbyComm
local old_CreateUI = CreateUI
local old_DoSlotBehavior = DoSlotBehavior
local PingTable = {}
local trollThread

function AddCustomMenuSlots()
	table.insert(slotMenuData.player.client, 'override_cpu')
	table.insert(slotMenuData.player.host, 'override_cpu')
    table.insert(slotMenuData.player.client, 'override_obs')
	table.insert(slotMenuData.player.client, 'override_kick')
	table.insert(slotMenuData.open.client, 'override_close')
	table.insert(slotMenuData.closed.client, 'override_open')
	table.insert(slotMenuData.open.client, 'override_add_player')
	slotMenuStrings['override_add_player'] = 'Add fake player'
	slotMenuStrings['override_cpu'] = 'Fake high CPU rating'
    slotMenuStrings['override_obs'] = 'Move player to observer'
	slotMenuStrings['override_kick'] = 'Kick player'
	slotMenuStrings['override_close'] = 'Close slot'
	slotMenuStrings['override_open'] = 'Open slot'
	for i = 1, LobbyComm.maxPlayerSlots, 1 do
        table.insert(slotMenuData.player.client, 'override_move_player_to_slot' .. i)
        slotMenuStrings['override_move_player_to_slot' .. i] = 'Move player to slot ' .. i
    end
end
local ConnectionStatusInfo = {
    'Player is not connected to someone',
    'Connected',
    'Not Connected',
    'No connection info available',
}

function GetFakePlayerData()
	fakeNames = { 'Drakis', 'Hobelik', 'DzizuSS', 'aFo', 'Bombel', 'eiVoN', 'Butch', 'Buzz', 'Froggy', 'meatball', 'colt', 'fester', 'Slasher', 'bane', 'basyl', 'lazak', }
	fakeCountries = { 'de', 'fr', 'gb', 'ca', 'ru', 'au', }
	math.randomseed(math.random(1,1000))
	local fakeName = ''
	repeat
		fakeName = fakeNames[ math.random( 16 ) ]
	until(FindIDForName(fakeName) == nil)
	local fakeCountry = fakeCountries[ math.random( 6 ) ]
	local fakeRating = math.random(1,10)*100
	local fakeNumgames = math.random(20,500)
	local fakeFaction = math.random(1,4)
    return PlayerData(
        {
            PlayerName = fakeName,
            OwnerID = hostID,
            Human = true,
            PlayerColor = 1,
            Faction = fakeFaction,
            PlayerClan = '',
            PL = fakeRating,
            NG = fakeNumgames,
            MEAN = 1500,
            DEV = 100,
            Country = fakeCountry,
        }
    )
end
function GetLocalPlayerData()
    return PlayerData(
        {
            PlayerName = localPlayerName,
            OwnerID = localPlayerID,
            Human = true,
            PlayerColor = 6,
            Faction = GetSanitisedLastFaction(),
            PlayerClan = argv.playerClan,
            PL = playerRating,
            NG = argv.numGames,
            MEAN = argv.playerMean,
            DEV = argv.playerDeviation,
            Country = 'aq',
        }
    )
end
function CreateUI(maxPlayers)
	old_CreateUI(maxPlayers)
    GUI.pingThread = ForkThread(
    function()
        while lobbyComm do
		local LocalPingTable = {}
            for slot, player in gameInfo.PlayerOptions:pairs() do
                if player.Human and player.OwnerID ~= localPlayerID then
					GUI.slots[slot].pingStatus:Show()
					GUI.slots[slot].pingStatus:SetRange(0, 500)
                    local peer = lobbyComm:GetPeer(player.OwnerID)
                    local ping = peer.ping
                    local connectionStatus = CalcConnectionStatus(peer)
                    GUI.slots[slot].pingStatus.ConnectionStatus = connectionStatus
                    GUI.slots[slot].pingStatus.OwnerID = player.OwnerID
					if ping then
                        ping = math.floor(ping)
                        GUI.slots[slot].pingStatus.PingActualValue = ping
                        GUI.slots[slot].pingStatus:SetValue(ping)
						
                        if ping < 400 then GUI.slots[slot].pingStatus._bar:SetSolidColor('ff50ff50') 
						elseif ping < 450 then GUI.slots[slot].pingStatus._bar:SetSolidColor('ffffee00') 
						else GUI.slots[slot].pingStatus._bar:SetSolidColor('ffff5050') end
						if GUI.slots[slot].pingStatus.ConnectionStatus ~= 2 then GUI.slots[slot].pingStatus._bar:SetSolidColor('ffff5050') end
						
						for k, r in PingTable do
							for j, p in r do
								if p > 450 and player.OwnerID == k then GUI.slots[slot].pingStatus._bar:SetSolidColor('ffff5050') end 
							end
						end
						
						GUI.slots[slot].pingStatus._bar.Height:Set(4)
						LocalPingTable[player.OwnerID] = ping
					else 
						GUI.slots[slot].pingStatus._bar.Height:Set(4)
						GUI.slots[slot].pingStatus:SetValue(500)
						GUI.slots[slot].pingStatus._bar:SetSolidColor('ffff5050')
                    end
                end
            end
			lobbyComm:BroadcastData({Type='PingData', sourceID=localPlayerID, PingData=LocalPingTable})
            WaitSeconds(0.0001)
        end
    end)

	unx = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/unx/', '', 11)
	LayoutHelpers.AtLeftTopIn(unx, GUI.panel, 300, 20)
	unx.Height:Set(35)
	unx.Width:Set(80)
	unx.oldHandleEvent = unx.HandleEvent
	unx.HandleEvent = function(self, event)
		if event.Type == 'ButtonPress' then
			lobbyComm:BroadcastData({ Type = 'SetAllPlayerNotReady' })
			lobbyComm:SendData(hostID, {Type = 'SetPlayerNotReady', Slot = FindSlotForID(hostID)})
			SetPlayerOption(FindSlotForID(localPlayerID), 'Ready', false)
		end
		unx.oldHandleEvent(self, event)
	end
	
	spamVoice = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/sound_btn/', '', 11)
	LayoutHelpers.AtLeftTopIn(spamVoice, GUI.panel, 245, 20)
	spamVoice.Height:Set(35)
	spamVoice.Width:Set(80)
	spamVoice.oldHandleEvent = spamVoice.HandleEvent
	spamVoice.HandleEvent = function(self, event)
		if event.Type == 'ButtonPress' then
			lobbyComm:BroadcastData(
                {
                    Type = 'SlotAssigned',
                    Slot = FindSlotForID(hostID),
                    Options = gameInfo.PlayerOptions[FindSlotForID(hostID)]:AsTable(),
                }
            )
		end
		spamVoice.oldHandleEvent(self, event)
	end
	
	trololo = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/generic_btn/', '', 11)
	LayoutHelpers.AtLeftTopIn(trololo, GUI.panel, 190, 20)
	trololo.Height:Set(35)
	trololo.Width:Set(80)
	trololo.oldHandleEvent = trololo.HandleEvent
	trololo.HandleEvent = function(self, event)
		if event.Type == 'ButtonPress' then
			if not trollThread then
				trollThread = ForkThread(
				function()
				while true do
						for islot = 1, LobbyComm.maxPlayerSlots, 1 do
							if gameInfo.PlayerOptions[islot] then
								--color 
								tempColor = GetAvailableColor()
								if localPlayerID == hostID then 
									lobbyComm:BroadcastData({ Type = 'SetColor', Color = tempColor, Slot = islot })
								else lobbyComm:SendData(hostID, { Type = 'RequestColor', Color = tempColor, Slot = islot }) end
								SetPlayerColor(gameInfo.PlayerOptions[islot], tempColor)
								--CPU
								tempCPU = math.random(50, 450)
								lobbyComm:BroadcastData({ Type = 'CPUBenchmark', PlayerName = gameInfo.PlayerOptions[islot].PlayerName, Result = tempCPU })
								if localPlayerID == hostID then 
									CPU_Benchmarks[gameInfo.PlayerOptions[islot].PlayerName] = tempCPU
									SetSlotCPUBar(islot, gameInfo.PlayerOptions[islot])
								end
								--team
								tempTeam = math.random(1, 6)
								SetPlayerOption(islot, 'Team', tempTeam)
								lobbyComm:BroadcastData(
								{
									Type = 'AutoTeams',
									Team = tempTeam,
									Slot = islot,
								})
								--faction
								tempFaction = math.random(1, 4)
								local optF = {}
								optF['Faction'] = tempFaction
								SetPlayerOption(islot, 'Faction', tempFaction)
								lobbyComm:BroadcastData(
								{
									Type = 'PlayerOptions',
									Options = optF,
									Slot = islot,
								})
								--swap players
								local numPlayers = LobbyComm.maxPlayerSlots
								slot1 = math.random(1,numPlayers)
								slot2 = math.random(1,numPlayers)
								if gameInfo.PlayerOptions[slot1] and gameInfo.PlayerOptions[slot2] then
									if localPlayerID == hostID then
										DoSlotSwap(slot1, slot2)
									else
										lobbyComm:BroadcastData(
											{
												Type = 'SwapPlayers',
												Slot1 = slot1,
												Slot2 = slot2,
											}
										)
									end
								end
							end
						end
						UpdateGame()
						WaitSeconds(1)
					end
				end)
			else 
				KillThread(trollThread)
				trollThread	= false			
			end
		end
		trololo.oldHandleEvent(self, event)
	end
	
	AddCustomMenuSlots()
	GUI.observerList.OnClick = function(self, row, event)
            UIUtil.QuickDialog(GUI, 'Select function',
                                    'Kick player', function()
										if localPlayerID == hostID then
											if gameInfo.Observers[row+1].OwnerID == hostID then
												return
											else
												SendSystemMessage("lobui_0756", gameInfo.Observers[row+1].PlayerName)
												lobbyComm:EjectPeer(gameInfo.Observers[row+1].OwnerID, "KickedByHost")
											end
										else
											lobbyComm:BroadcastData(
												{
													Type = 'Peer_Really_Disconnected',
													Options = gameInfo.Observers[row+1].PlayerName,
													Slot = row+1,
													Observ = true,
												}
											)
										end
                                    end,
                                    'Move to slot', function()
										local slot3 = 0
										for ii = 1,16 do
											if gameInfo.PlayerOptions[ii] == nil then 
												slot3 = ii
												break
											end
										end
										if localPlayerID == hostID then
											HostUtils.ConvertObserverToPlayer(FindObserverSlotForID(localPlayerID))
										else
											lobbyComm:SendData(
												hostID,
												{
													Type = 'RequestConvertToPlayer',
													ObserverSlot = row+1,
													PlayerSlot = slot3,
												}
											)
										end
									end,
                                    'Close', function()
									 return
									end, nil,
                                    true,
                                    {worldCover = false, enterButton = 1, escapeButton = 2})
    end
	
end

function DisableSlot(slot, exceptReady)
    GUI.slots[slot].team:Enable()
    GUI.slots[slot].color:Enable()
	if (gameInfo.PlayerOptions[slot].OwnerID ~= hostID) then
		GUI.slots[slot].faction:Enable()
	end
    if not exceptReady then
        GUI.slots[slot].ready:Enable()
    end
end

function SetSlotCPUBar(slot, playerInfo)
    if GUI.slots[slot].CPUSpeedBar then
        GUI.slots[slot].CPUSpeedBar:Hide()
        if playerInfo.Human then
            local b = CPU_Benchmarks[playerInfo.PlayerName]
            if b then
                if b > GUI.slots[slot].CPUSpeedBar.barMax then
                    b = GUI.slots[slot].CPUSpeedBar.barMax
                end
                GUI.slots[slot].CPUSpeedBar:SetValue(b)
                GUI.slots[slot].CPUSpeedBar.CPUActualValue = b
				
				if b < 250 then GUI.slots[slot].CPUSpeedBar._bar:SetSolidColor('ff50ff50') 
				elseif b < 350 then GUI.slots[slot].CPUSpeedBar._bar:SetSolidColor('ffffee00') 
				else GUI.slots[slot].CPUSpeedBar._bar:SetSolidColor('ffff5050') end
				
				GUI.slots[slot].CPUSpeedBar.Height:Set(4)
                GUI.slots[slot].CPUSpeedBar:Show()
            end
        end
    end
end

function DoSlotBehavior(slot, key, name)   
	if key == 'override_obs' then
		local data = {}
        data.pId = gameInfo.PlayerOptions[slot].OwnerID
		lobbyComm:SendData(hostID, {Type = 'RequestConvertToObserver', RequestedSlot = FindSlotForID(data.pId)})
	elseif key == 'override_cpu' then
		lobbyComm:BroadcastData({ Type = 'CPUBenchmark', PlayerName = FindNameForID(gameInfo.PlayerOptions[slot].OwnerID), Result = 753 })
		if localPlayerID == hostID then 
			CPU_Benchmarks[gameInfo.PlayerOptions[slot].PlayerName] = 753
			SetSlotCPUBar(slot, gameInfo.PlayerOptions[slot])
		end
	elseif key == 'override_add_player' then
		local fakePlayerOptions = GetFakePlayerData():AsTable()
		lobbyComm:SendData(hostID,
            {
                Type = 'AddPlayer',
                PlayerOptions = fakePlayerOptions
            }
        )
		lobbyComm:BroadcastData({ Type = 'CPUBenchmark', PlayerName = fakePlayerOptions.PlayerName, Result = math.random(200,360) })
	elseif key == 'override_kick' then
		local data = {}
        data.pId = gameInfo.PlayerOptions[slot].OwnerID
		local mName = { PlayerName = FindNameForID(data.pId) }
		lobbyComm:BroadcastData(
                {
                    Type = 'Peer_Really_Disconnected',
                    Options = mName,
                    Slot = slot,
                    Observ = false,
                }
			)
	elseif key == 'override_close' then 
		lobbyComm:BroadcastData(
                {
                    Type = 'SlotClosed',
                    Slot = slot,
                    Closed = true
                }
            )
		gameInfo.ClosedSlots[slot] = true
		ClearSlotInfo(slot)
	elseif key == 'override_open' then 
		lobbyComm:BroadcastData(
                {
                    Type = 'SlotClosed',
                    Slot = slot,
                    Closed = false
                }
            )
		gameInfo.ClosedSlots[slot] = false
		ClearSlotInfo(slot)
	elseif string.sub(key, 1, 28) == 'override_move_player_to_slot' then
		local destSlot = 0
		if string.len(key) == 29 then destSlot = tonumber(string.sub(key, 29)) end
		if string.len(key) == 30 then destSlot = tonumber(string.sub(key, 29, 30)) end
		lobbyComm:SendData(hostID, {Type = 'MovePlayer', CurrentSlot = slot,
                                   RequestedSlot = destSlot})
	else
		old_DoSlotBehavior(slot, key, name)
    end
end

function Ping_AddControlTooltip(control, delay, slotNumber)
    local pingText = function()
        local pingInfo
        if GUI.slots[slotNumber].pingStatus.PingActualValue then
            pingInfo = GUI.slots[slotNumber].pingStatus.PingActualValue
        else
            pingInfo = LOC('<LOC lobui_0458>UnKnown')
        end
        return LOC('<LOC lobui_0452>Ping: ') .. pingInfo
    end
	
    local pingBody = function()
        local conInfo
        if GUI.slots[slotNumber].pingStatus.ConnectionStatus then
            conInfo = GUI.slots[slotNumber].pingStatus.ConnectionStatus
        else
            conInfo = 4
        end
		
        local notConnected = {}
		local connectionText = ' '
		
        if conInfo ~= 2 then
            local allPlayers = {}
            for slot, player in gameInfo.PlayerOptions:pairs() do
                if not table.find(allPlayers, player.OwnerID) then
                    table.insert(allPlayers, player.OwnerID)
                end
            end
           
            for slot, observer in gameInfo.Observers:pairs() do
                if not table.find(allPlayers, observer.OwnerID) then
                    table.insert(allPlayers, observer.OwnerID)
                end
            end
           
            for k, id in allPlayers do
                if FindSlotForID(id) == slotNumber then
                    local peer = lobbyComm:GetPeer(id)
                    for k2, other in allPlayers do
                        if id ~= other and not table.find(peer.establishedPeers, other) then
                            table.insert(notConnected, lobbyComm:GetPeer(other).name)
                        end
                    end
                end
            end
			
			if not (next(notConnected) == nil) then
				connectionText = connectionText .. '('
				for _, name in notConnected do
					connectionText = connectionText .. name .. ', '
				end
				connectionText = string.sub(connectionText, 1, string.len(connectionText)-2) .. ')'
			end
        end
       
		local pingsText = ''
        for k, pings in pairs(PingTable) do
            if FindSlotForID(k) == slotNumber then
				local temp = true
                for id, ping in pings do
                    if ping > 450 then 
						if temp then 
							pingsText = '\nHigh ping to following players:\n' 
							temp = false
						end
						pingsText = pingsText .. '\n' .. FindNameForID(id) .. ' (' .. ping .. ' ms)' 
					end
                end
            end
        end
        body = ConnectionStatusInfo[conInfo] .. connectionText .. pingsText
        return (body)
    end
    Lobby_AddControlTooltip(control,
                            delay,
                            slotNumber,
                            pingText,
                            pingBody)
end

function CreateSlotsUI(makeLabel)
    local Combo = import('/lua/ui/controls/combo.lua').Combo
    local BitmapCombo = import('/lua/ui/controls/combo.lua').BitmapCombo
    local StatusBar = import('/lua/maui/statusbar.lua').StatusBar
    local ColumnLayout = import('/lua/ui/controls/columnlayout.lua').ColumnLayout

    -- The dimensions of the columns used for slot UI controls.
    local COLUMN_POSITIONS = {1, 21, 47, 91, 133, 395, 465, 535, 605, 677, 749}
    local COLUMN_WIDTHS = {20, 20, 45, 45, 257, 59, 59, 59, 62, 62, 51}

    local labelGroup = ColumnLayout(GUI.playerPanel, COLUMN_POSITIONS, COLUMN_WIDTHS)

    GUI.labelGroup = labelGroup
    labelGroup.Width:Set(791)
    labelGroup.Height:Set(21)
    LayoutHelpers.AtLeftTopIn(labelGroup, GUI.playerPanel, 5, 5)

    local slotLabel = makeLabel("#", 14)
    labelGroup:AddChild(slotLabel)

    -- No label required for the second column (flag), so skip it. (Even eviler hack)
    labelGroup.numChildren = labelGroup.numChildren + 1

    local ratingLabel = makeLabel("R", 14)
    labelGroup:AddChild(ratingLabel)

    local numGamesLabel = makeLabel("G", 14)
    labelGroup:AddChild(numGamesLabel)

    local nameLabel = makeLabel(LOC("<LOC NICKNAME>Nickname"), 14)
    labelGroup:AddChild(nameLabel)

    local colorLabel = makeLabel(LOC("<LOC lobui_0214>Color"), 14)
    labelGroup:AddChild(colorLabel)

    local factionLabel = makeLabel(LOC("<LOC lobui_0215>Faction"), 14)
    labelGroup:AddChild(factionLabel)

    local teamLabel = makeLabel(LOC("<LOC lobui_0216>Team"), 14)
    labelGroup:AddChild(teamLabel)

    if not singlePlayer then
        labelGroup:AddChild(makeLabel(LOC("<LOC lobui_0450>CPU"), 14))
        labelGroup:AddChild(makeLabel(LOC("<LOC lobui_0451>Ping"), 14))
        labelGroup:AddChild(makeLabel(LOC("<LOC lobui_0218>Ready"), 14))
    end

    for i= 1, LobbyComm.maxPlayerSlots do
        -- Capture the index in the current closure so it's accessible on callbacks
        local curRow = i

        -- The background is parented on the GUI so it doesn't vanish when we hide the slot.
        local slotBackground = Bitmap(GUI, UIUtil.SkinnableFile("/SLOT/slot-dis.dds"))

        -- Inherit dimensions of the slot control from the background image.
        local newSlot = ColumnLayout(GUI.playerPanel, COLUMN_POSITIONS, COLUMN_WIDTHS)
        newSlot.Width:Set(slotBackground.Width)
        newSlot.Height:Set(slotBackground.Height)

        LayoutHelpers.AtLeftTopIn(slotBackground, newSlot)
        newSlot.SlotBackground = slotBackground

        -- Default mouse behaviours for the slot.
        local defaultHandler = function(self, event)
            if curRow > numOpenSlots then
                return
            end

            local associatedMarker = GUI.mapView.startPositions[curRow]
            if event.Type == 'MouseEnter' then
                if gameInfo.GameOptions['TeamSpawn'] == 'fixed' then
                    associatedMarker.indicator:Play()
                end
            elseif event.Type == 'MouseExit' then
                associatedMarker.indicator:Stop()
            elseif event.Type == 'ButtonDClick' then
                DoSlotBehavior(curRow, 'occupy', '')
            end

            return Group.HandleEvent(self, event)
        end
        newSlot.HandleEvent = defaultHandler

        -- Slot number
        local slotNumber = UIUtil.CreateText(newSlot, i, 14, 'Arial')
        slotNumber.Width:Set(COLUMN_WIDTHS[1])
        slotNumber.Height:Set(newSlot.Height)
        newSlot:AddChild(slotNumber)
        newSlot.tooltipnumber = Tooltip.AddControlTooltip(slotNumber, 'slot_number')

        -- COUNTRY
        -- Added a bitmap on the left of Rating, the bitmap is a Flag of Country
        local flag = Bitmap(newSlot, UIUtil.SkinnableFile("/countries/world.dds"))
        newSlot.KinderCountry = flag
        flag.Width:Set(COLUMN_WIDTHS[2])
        newSlot:AddChild(flag)

        -- TODO: Factorise this boilerplate.
        -- Rating
        local ratingText = UIUtil.CreateText(newSlot, "", 14, 'Arial')
        newSlot.ratingText = ratingText
        ratingText:SetColor('B9BFB9')
        ratingText:SetDropShadow(true)
        newSlot:AddChild(ratingText)

        -- NumGame
        local numGamesText = UIUtil.CreateText(newSlot, "", 14, 'Arial')
        newSlot.numGamesText = numGamesText
        numGamesText:SetColor('B9BFB9')
        numGamesText:SetDropShadow(true)
        Tooltip.AddControlTooltip(numGamesText, 'num_games')
        newSlot:AddChild(numGamesText)

        -- Name
        local nameLabel = Combo(newSlot, 14, 12, true, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.name = nameLabel
        nameLabel._text:SetFont('Arial Gras', 15)
        newSlot:AddChild(nameLabel)
        nameLabel.Width:Set(COLUMN_WIDTHS[5])
        -- left deal with name clicks
        nameLabel.OnEvent = defaultHandler
        nameLabel.OnClick = function(self, index, text)
            DoSlotBehavior(curRow, self.slotKeys[index], text)
        end

        -- Hide the marker when the dropdown is hidden
        nameLabel.OnHide = function()
            local associatedMarker = GUI.mapView.startPositions[curRow]
            if associatedMarker then
                associatedMarker.indicator:Stop()
            end
        end

        -- Color
        local colorSelector = BitmapCombo(newSlot, gameColors.PlayerColors, 1, true, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.color = colorSelector

        newSlot:AddChild(colorSelector)
        colorSelector.Width:Set(COLUMN_WIDTHS[6])
        colorSelector.OnClick = function(self, index)
            if not lobbyComm:IsHost() then
                lobbyComm:SendData(hostID, { Type = 'RequestColor', Color = index, Slot = curRow })
                SetPlayerColor(gameInfo.PlayerOptions[curRow], index)
                UpdateGame()
            else
                if IsColorFree(index) then
                    lobbyComm:BroadcastData({ Type = 'SetColor', Color = index, Slot = curRow })
                    SetPlayerColor(gameInfo.PlayerOptions[curRow], index)
                    UpdateGame()
                else
                    self:SetItem(gameInfo.PlayerOptions[curRow].PlayerColor)
                end
            end
        end
        colorSelector.OnEvent = defaultHandler
        Tooltip.AddControlTooltip(colorSelector, 'lob_color')

        -- Faction
        -- builds the faction tables, and then adds random faction icon to the end
        local factionBmps = {}
        local factionTooltips = {}
        local factionList = {}
        for index, tbl in FactionData.Factions do
            factionBmps[index] = tbl.SmallIcon
            factionTooltips[index] = tbl.TooltipID
            factionList[index] = tbl.Key
        end
        table.insert(factionBmps, "/faction_icon-sm/random_ico.dds")
        table.insert(factionTooltips, 'lob_random')
        table.insert(factionList, 'random')
        allAvailableFactionsList = factionList

        local factionSelector = BitmapCombo(newSlot, factionBmps, table.getn(factionBmps), nil, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.faction = factionSelector
        newSlot.AvailableFactions = factionList
        newSlot:AddChild(factionSelector)
        factionSelector.Width:Set(COLUMN_WIDTHS[7])
        factionSelector.OnClick = function(self, index)
            if curRow == FindSlotForID(FindIDForName(localPlayerName)) then
				SetPlayerOption(curRow, 'Faction', index)
                local fact = GUI.slots[FindSlotForID(localPlayerID)].AvailableFactions[index]
                for ind,value in allAvailableFactionsList do
                    if fact == value then
                        GUI.factionSelector:SetSelected(ind)
                        break
                    end
                end
			else 
				local optF = {}
				optF['Faction'] = index
				lobbyComm:BroadcastData(
				{
					Type = 'PlayerOptions',
					Options = optF,
					Slot = curRow,
				})
			end
            Tooltip.DestroyMouseoverDisplay()
        end
        Tooltip.AddControlTooltip(factionSelector, 'lob_faction')
        Tooltip.AddComboTooltip(factionSelector, factionTooltips)
        factionSelector.OnEvent = defaultHandler

        -- Team
        local teamSelector = BitmapCombo(newSlot, teamIcons, 1, false, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.team = teamSelector
        newSlot:AddChild(teamSelector)
        teamSelector.Width:Set(COLUMN_WIDTHS[8])
        teamSelector.OnClick = function(self, index, text)
            Tooltip.DestroyMouseoverDisplay()
            if IsLocallyOwned(curRow) then 
				SetPlayerOption(curRow, 'Team', index)
				lobbyComm:BroadcastData(
				{
					Type = 'AutoTeams',
					Team = index,
					Slot = curRow,
				})
			else
				gameInfo.PlayerOptions[curRow]['Team'] = index
				lobbyComm:BroadcastData(
				{
					Type = 'AutoTeams',
					Team = index,
					Slot = curRow,
				})
			end
        end
        Tooltip.AddControlTooltip(teamSelector, 'lob_team')
        Tooltip.AddComboTooltip(teamSelector, teamTooltips)
        teamSelector.OnEvent = defaultHandler

        -- if not singlePlayer then
        -- CPU
        local barMax = 450
        local barMin = 0
        local CPUGroup = Group(newSlot)
        newSlot.CPUGroup = CPUGroup
        CPUGroup.Width:Set(COLUMN_WIDTHS[9])
        CPUGroup.Height:Set(newSlot.Height)
        newSlot:AddChild(CPUGroup)
        local CPUSpeedBar = StatusBar(CPUGroup, barMin, barMax, false, false,
        UIUtil.UIFile('/game/unit_bmp/bar_black_bmp.dds'),
        UIUtil.UIFile('/game/unit_bmp/bar_purple_bmp.dds'),
        true)
        newSlot.CPUSpeedBar = CPUSpeedBar
        LayoutHelpers.AtTopIn(CPUSpeedBar, CPUGroup, 7)
        LayoutHelpers.AtLeftIn(CPUSpeedBar, CPUGroup, 0)
        LayoutHelpers.AtRightIn(CPUSpeedBar, CPUGroup, 0)
        CPU_AddControlTooltip(CPUSpeedBar, 0, curRow)
        CPUSpeedBar.CPUActualValue = 450
        CPUSpeedBar.barMax = barMax

        -- Ping
        barMax = 1000
        barMin = 0
        local pingGroup = Group(newSlot)
        newSlot.pingGroup = pingGroup
        pingGroup.Width:Set(COLUMN_WIDTHS[10])
        pingGroup.Height:Set(newSlot.Height)
        newSlot:AddChild(pingGroup)
        local pingStatus = StatusBar(pingGroup, barMin, barMax, false, false,
            UIUtil.SkinnableFile('/game/unit_bmp/bar-back_bmp.dds'),
            UIUtil.SkinnableFile('/game/unit_bmp/bar-01_bmp.dds'),
            true)
        newSlot.pingStatus = pingStatus
        LayoutHelpers.AtTopIn(pingStatus, pingGroup, 7)
        LayoutHelpers.AtLeftIn(pingStatus, pingGroup, 0)
        LayoutHelpers.AtRightIn(pingStatus, pingGroup, 0)
        Ping_AddControlTooltip(pingStatus, 0, curRow)

        -- Ready Checkbox
        local readyBox = UIUtil.CreateCheckbox(newSlot, '/CHECKBOX/')
        newSlot.ready = readyBox
        newSlot:AddChild(readyBox)
        readyBox.OnCheck = function(self, checked)
            if FindSlotForID(FindIDForName(localPlayerName)) == curRow then 
				if checked then
					DisableSlot(curRow, true)
				else
					EnableSlot(curRow)
				end 
				UIUtil.setEnabled(GUI.becomeObserver, not checked)
				SetPlayerOption(curRow, 'Ready', checked) 
			else 
				if checked then
					SetPlayerOption(curRow, 'Ready', checked) 
					local optF = {}
					optF['Ready'] = true
					lobbyComm:BroadcastData(
					{
						Type = 'PlayerOptions',
						Options = optF,
						Slot = curRow,
						SenderID = hostID,
					})
				else
					lobbyComm:SendData(gameInfo.PlayerOptions[curRow].OwnerID, {Type = 'SetPlayerNotReady', Slot = curRow})
				end
			end
        end
        -- end

        newSlot.HideControls = function()
            -- hide these to clear slot of visible data
            flag:Hide()
            ratingText:Hide()
            numGamesText:Hide()
            factionSelector:Hide()
            colorSelector:Hide()
            teamSelector:Hide()
            CPUSpeedBar:Hide()
            pingStatus:Hide()
            readyBox:Hide()
        end
        newSlot.HideControls()

        if singlePlayer then
            -- TODO: Use of groups may allow this to be simplified...
            readyBox:Hide()
            CPUSpeedBar:Hide()
            pingStatus:Hide()
        end

        if i == 1 then
            LayoutHelpers.Below(newSlot, GUI.labelGroup)
        else
            LayoutHelpers.Below(newSlot, GUI.slots[i - 1], 3)
        end

        GUI.slots[i] = newSlot
    end
end




function InitLobbyComm(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider)
	old_InitLobbyComm(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider)
	lobbyComm.DataReceived = function(self,data)
        -- Messages anyone can receive
        if data.Type == 'PlayerOptions' then
            local options = data.Options
            local isHost = lobbyComm:IsHost()

            for key, val in options do
                -- The host *is* allowed to set options on slots he doesn't own, of course.
                if data.SenderID ~= hostID then
                    if key == 'Team' and gameInfo.GameOptions['AutoTeams'] ~= 'none' then
                        WARN("Attempt to set Team while Auto Teams are on.")
                        return
                    elseif gameInfo.PlayerOptions[data.Slot].OwnerID ~= data.SenderID then
                        WARN("Attempt to set option on unowned slot.")
                        return
                    end
                end

                gameInfo.PlayerOptions[data.Slot][key] = val
                if isHost then
                    local playerInfo = gameInfo.PlayerOptions[data.Slot]
                    if playerInfo.Human then
                        GpgNetSend('PlayerOption', playerInfo.OwnerID, key, val)
                    else
                        GpgNetSend('AIOption', playerInfo.PlayerName, key, val)
                    end


                    -- TODO: This should be a global listener on PlayerData objects, but I'm in too
                    -- much pain to implement that listener system right now. EVIL HACK TIME
                    if key == "Ready" then
                        HostUtils.RefreshButtonEnabledness()
                    end
                    -- DONE.
                end
            end
            SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
        elseif data.Type == 'PublicChat' then
            AddChatText("["..data.SenderName.."] "..data.Text)
        elseif data.Type == 'PrivateChat' then
            AddChatText("<<"..LOCF("<LOC lobui_0442>From %s", data.SenderName)..">> "..data.Text)
        elseif data.Type == 'CPUBenchmark' then
            -- CPU benchmark code
            local newInfo = false
            if data.PlayerName and CPU_Benchmarks[data.PlayerName] ~= data.Result then
                newInfo = true
            end

            local benchmarks = {}
            if data.PlayerName then
                benchmarks[data.PlayerName] = data.Result
            else
                benchmarks = data.Benchmarks
            end

            for name, result in benchmarks do
                CPU_Benchmarks[name] = result
                local id = FindIDForName(name)
                local slot = FindSlotForID(id)
                if slot then
                    SetSlotCPUBar(slot, gameInfo.PlayerOptions[slot])
                else
                    refreshObserverList()
                end
            end

            -- Host broadcasts new CPU benchmark information to give the info to clients that are not directly connected to data.PlayerName yet.
            if lobbyComm:IsHost() and newInfo then
                lobbyComm:BroadcastData({Type='CPUBenchmark', Benchmarks=CPU_Benchmarks})
            end
        elseif data.Type == 'SetPlayerNotReady' then
            EnableSlot(data.Slot)
            GUI.becomeObserver:Enable()

            SetPlayerOption(data.Slot, 'Ready', false)
        elseif data.Type == 'AutoTeams' then
            gameInfo.AutoTeams[data.Slot] = data.Team
            gameInfo.PlayerOptions[data.Slot]['Team'] = data.Team
            SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
            UpdateGame()
			
			-- New ping sharing function
		elseif data.Type == 'PingData' then
			PingTable[data.sourceID] = {}
			for id, ping in data.PingData do
				PingTable[data.sourceID][id] = ping
			end
        end
        if lobbyComm:IsHost() then
            -- Host only messages
            if data.Type == 'AddPlayer' then
                -- try to reassign the same slot as in the last game if it's a rehosted game, otherwise give it an empty
                -- slot or move it to observer
                SendCompleteGameStateToPeer(data.SenderID)

                if argv.isRehost then
                    local rehostSlot = FindRehostSlotForID(data.SenderID) or 0
                    if rehostSlot ~= 0 and gameInfo.PlayerOptions[rehostSlot] then
                        -- If the slot is occupied, the occupying player will be moved away or to observer. If it's an
                        -- AI, it will be removed
                        local occupyingPlayer = gameInfo.PlayerOptions[rehostSlot]
                        if not occupyingPlayer.Human then
                            HostUtils.RemoveAI(rehostSlot)
                            HostUtils.TryAddPlayer(data.SenderID, rehostSlot, PlayerData(data.PlayerOptions))
                        else
                            HostUtils.ConvertPlayerToObserver(rehostSlot, true)
                            HostUtils.TryAddPlayer(data.SenderID, rehostSlot, PlayerData(data.PlayerOptions))
                            HostUtils.ConvertObserverToPlayer(FindObserverSlotForID(occupyingPlayer.OwnerID))
                        end
                    else
                        HostUtils.TryAddPlayer(data.SenderID, rehostSlot, PlayerData(data.PlayerOptions))
                    end
                else
                    HostUtils.TryAddPlayer(data.SenderID, 0, PlayerData(data.PlayerOptions))
                end
                PlayVoice(Sound{Bank = 'XGG',Cue = 'XGG_Computer__04716'}, true)
            elseif data.Type == 'MovePlayer' then
                -- Handle ready-races.
                if gameInfo.PlayerOptions[data.CurrentSlot].Ready then
                    return
                end

                -- Player requests to be moved to a different empty slot.
                HostUtils.MovePlayerToEmptySlot(data.CurrentSlot, data.RequestedSlot)
            elseif data.Type == 'RequestConvertToObserver' then
                HostUtils.ConvertPlayerToObserver(data.RequestedSlot)
            elseif data.Type == 'RequestConvertToPlayer' then
                HostUtils.ConvertObserverToPlayer(data.ObserverSlot, data.PlayerSlot)
            elseif data.Type == 'RequestColor' then
                if IsColorFree(data.Color) then
                    -- Color is available, let everyone else know
                    SetPlayerColor(gameInfo.PlayerOptions[data.Slot], data.Color)
                    lobbyComm:BroadcastData({ Type = 'SetColor', Color = data.Color, Slot = data.Slot })
                    SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
                else
                    -- Sorry, it's not free. Force the player back to the color we have for him.
                    lobbyComm:SendData(data.SenderID, { Type = 'SetColor', Color =
                    gameInfo.PlayerOptions[data.Slot].PlayerColor, Slot = data.Slot })
                end
            elseif data.Type == 'ClearSlot' then
                if gameInfo.PlayerOptions[data.Slot].OwnerID == data.SenderID then
                    HostUtils.RemoveAI(data.Slot)
                else
                    WARN("Attempt to clear unowned slot")
                end
            elseif data.Type == 'SetAvailableMods' then
                availableMods[data.SenderID] = data.Mods
                HostUtils.UpdateMods(data.SenderID, data.Name)
            elseif data.Type == 'MissingMap' then
                HostUtils.PlayerMissingMapAlert(data.Id)
            end
        else -- Non-host only messages
            if data.Type == 'SystemMessage' then
                PrintSystemMessage(data.Id, data.Args)
            elseif data.Type == 'SetAllPlayerNotReady' then
                if not IsPlayer(localPlayerID) then
                    return
                end
                local localSlot = FindSlotForID(localPlayerID)
                EnableSlot(localSlot)
                GUI.becomeObserver:Enable()
                SetPlayerOption(localSlot, 'Ready', false)
            elseif data.Type == 'Peer_Really_Disconnected' then
                if data.Observ == false then
                    gameInfo.PlayerOptions[data.Slot] = nil
                elseif data.Observ == true then
                    gameInfo.Observers[data.Slot] = nil
                end
                AddChatText(LOCF("<LOC Engine0003>Lost connection to %s.", data.Options.PlayerName), "Engine0003")
                ClearSlotInfo(data.Slot)
                UpdateGame()
            elseif data.Type == 'SlotAssigned' then
                gameInfo.PlayerOptions[data.Slot] = PlayerData(data.Options)
                PlayVoice(Sound{Bank = 'XGG',Cue = 'XGG_Computer__04716'}, true)
                SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
                UpdateFactionSelectorForPlayer(gameInfo.PlayerOptions[data.Slot])
                PossiblyAnnounceGameFull()
            elseif data.Type == 'SlotMove' then
                gameInfo.PlayerOptions[data.OldSlot] = nil
                gameInfo.PlayerOptions[data.NewSlot] = PlayerData(data.Options)
                ClearSlotInfo(data.OldSlot)
                SetSlotInfo(data.NewSlot, gameInfo.PlayerOptions[data.NewSlot])
                UpdateFactionSelectorForPlayer(gameInfo.PlayerOptions[data.NewSlot])
            elseif data.Type == 'SwapPlayers' then
                DoSlotSwap(data.Slot1, data.Slot2)
            elseif data.Type == 'ObserverAdded' then
                gameInfo.Observers[data.Slot] = PlayerData(data.Options)
                refreshObserverList()
            elseif data.Type == 'ConvertObserverToPlayer' then
                gameInfo.Observers[data.OldSlot] = nil
                gameInfo.PlayerOptions[data.NewSlot] = PlayerData(data.Options)
                refreshObserverList()
                SetSlotInfo(data.NewSlot, gameInfo.PlayerOptions[data.NewSlot])
                UpdateFactionSelectorForPlayer(gameInfo.PlayerOptions[data.NewSlot])
            elseif data.Type == 'ConvertPlayerToObserver' then
                gameInfo.Observers[data.NewSlot] = PlayerData(data.Options)
                gameInfo.PlayerOptions[data.OldSlot] = nil
                ClearSlotInfo(data.OldSlot)
                refreshObserverList()
                UpdateFactionSelectorForPlayer(gameInfo.Observers[data.NewSlot])
            elseif data.Type == 'SetColor' then
                SetPlayerColor(gameInfo.PlayerOptions[data.Slot], data.Color)
                SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
            elseif data.Type == 'GameInfo' then
                -- Completely update the game state. To be used exactly once: when first connecting.
                local hostFlatInfo = data.GameInfo
                gameInfo = GameInfo.CreateGameInfo(LobbyComm.maxPlayerSlots, hostFlatInfo)

                UpdateClientModStatus(gameInfo.GameMods, true)
                UpdateGame()
            elseif data.Type == 'GameOptions' then
                for key, value in data.Options do
                    gameInfo.GameOptions[key] = value
                end

                UpdateGame()
            elseif data.Type == 'Launch' then
                local info = data.GameInfo
                info.GameMods = Mods.GetGameMods(info.GameMods)
                SetWindowedLobby(false)

                -- Evil hack to correct the skin for randomfaction players before launch.
                for index, player in info.PlayerOptions do
                    -- Set the skin to the faction you'll be playing as, whatever that may be. (prevents
                    -- random-faction people from ending up with something retarded)
                    if player.OwnerID == localPlayerID then
                        UIUtil.SetCurrentSkin(FACTION_NAMES[player.Faction])
                    end
                 end

                SavePresetToName(LAST_GAME_PRESET_NAME)
                lobbyComm:LaunchGame(info)
            elseif data.Type == 'ClearSlot' then
                gameInfo.PlayerOptions[data.Slot] = nil
                ClearSlotInfo(data.Slot)
            elseif data.Type == 'ModsChanged' then
                gameInfo.GameMods = data.GameMods

                UpdateClientModStatus(data.GameMods)
                UpdateGame()
                import('/lua/ui/lobby/ModsManager.lua').UpdateClientModStatus(gameInfo.GameMods)
            elseif data.Type == 'SlotClosed' then
                gameInfo.ClosedSlots[data.Slot] = data.Closed
                gameInfo.SpawnMex[data.Slot] = false
                ClearSlotInfo(data.Slot)
            elseif data.Type == 'SlotClosedSpawnMex' then
                gameInfo.ClosedSlots[data.Slot] = data.ClosedSpawnMex
                gameInfo.SpawnMex[data.Slot] = data.ClosedSpawnMex
                ClearSlotInfo(data.Slot)
			end
        end
    end
	
	lobbyComm.GameLaunched = function(self)
        local player = lobbyComm:GetLocalPlayerID()
        for i, v in gameInfo.PlayerOptions do
            if v.Human and v.OwnerID == player then
                Prefs.SetToCurrentProfile('LoadingFaction', v.Faction)
                break
            end
        end

        GpgNetSend('GameState', 'Launching')
        if GUI.pingThread then
            KillThread(GUI.pingThread)
        end
        if GUI.keepAliveThread then
            KillThread(GUI.keepAliveThread)
        end
		if someThread then
            KillThread(someThread)
        end
        GUI:Destroy()
        GUI = false
        MenuCommon.MenuCleanup()
        lobbyComm:Destroy()
        lobbyComm = false

        -- determine if cheat keys should be mapped
        if not DebugFacilitiesEnabled() then
            IN_ClearKeyMap()
            IN_AddKeyMapTable(import('/lua/keymap/keymapper.lua').GetKeyMappings(gameInfo.GameOptions['CheatsEnabled']=='true'))
        end
    end
end

function SetSlotInfo(slotNum, playerInfo)
    -- Remove the ConnectDialog. It probably makes more sense to do this when we get the game state.
    if GUI.connectdialog then
        GUI.connectdialog:Close()
        GUI.connectdialog = nil

        -- Changelog, if necessary.
        if Need_Changelog() then
            GUI_Changelog()
        end
    end

    playerInfo.StartSpot = slotNum

    local slot = GUI.slots[slotNum]
    local isHost = lobbyComm:IsHost()
    local isLocallyOwned = IsLocallyOwned(slotNum)

    -- Set enabledness of controls according to host privelage etc.
    -- Yeah, we set it twice. No, it's not brilliant. Blurgh.
    local facColEnabled = isLocallyOwned or (isHost and not playerInfo.Human)
    UIUtil.setEnabled(slot.faction, facColEnabled)
    UIUtil.setEnabled(slot.color, facColEnabled)

    -- Possibly override it due to the ready box.
    if isLocallyOwned then
        if playerInfo.Ready and playerInfo.Human then
            DisableSlot(slotNum, true)
        else
            EnableSlot(slotNum)
        end
    else
        DisableSlot(slotNum)
    end

    --- Returns true if the team selector for this slot should be enabled.
    --
    -- The predicate was getting unpleasantly long to read.
    local function teamSelectionEnabled(autoTeams, ready, locallyOwned, isHost)
        if isHost and not playerInfo.Human then
            return true
        end

        -- If autoteams has control, no selector for you.
        if autoTeams ~= 'none' then
            return false
        end

        -- You can control your own one when you're not ready.
        if locallyOwned then
            return not ready
        end

        if isHost then
            -- The host can control the team of others, provided he's not ready himself.
            local slot = FindSlotForID(localPlayerID)
            local is_ready = slot and gameInfo.PlayerOptions[slot].Ready -- could be observer

            return not is_ready
        end
    end

    -- Disable team selection if "auto teams" is controlling it. Moderatelty ick.
    local autoTeams = gameInfo.GameOptions.AutoTeams
    UIUtil.setEnabled(slot.team, true)

    local hostKey
    if isHost then
        hostKey = 'host'
    else
        hostKey = 'client'
    end

    -- These states are used to select the appropriate strings with GetSlotMenuTables.
    local slotState
    if not playerInfo.Human then
        slot.ratingText:Hide()
        slotState = 'ai'
    elseif not isLocallyOwned then
        slotState = 'player'
    else
        slotState = nil
    end

    slot.name:ClearItems()

    if slotState then
        slot.name:Enable()
        local slotKeys, slotStrings, slotTooltips = GetSlotMenuTables(slotState, hostKey, slotNum)
        slot.name.slotKeys = slotKeys

        if table.getn(slotKeys) > 0 then
            slot.name:AddItems(slotStrings)
            slot.name:Enable()
            Tooltip.AddComboTooltip(slot.name, slotTooltips)
        else
            slot.name.slotKeys = nil
            slot.name:Disable()
            Tooltip.RemoveComboTooltip(slot.name)
        end
    else
        -- no slotState indicate this must be ourself, and you can't do anything to yourself
        slot.name.slotKeys = nil
        slot.name:Disable()
    end

    slot.ratingText:Show()
    slot.ratingText:SetText(playerInfo.PL)
    slot.ratingText:SetColor(GetRatingColour(playerInfo.DEV))

    -- dynamic tooltip to show rating and deviation for each player
    local tooltipText = {}
    tooltipText['text'] = "Rating"
    tooltipText['body'] = LOCF("<LOC lobui_0768>%s's TrueSkill Rating is %s +/- %s", playerInfo.PlayerName, math.round(playerInfo.MEAN), math.ceil(playerInfo.DEV * 3))
    slot.tooltiprating = Tooltip.AddControlTooltip(slot.ratingText, tooltipText)

    slot.numGamesText:Show()
    slot.numGamesText:SetText(playerInfo.NG)

    slot.name:Show()
    -- Change name colour according to the state of the slot.
    if slotState == 'ai' then
        slot.name:SetTitleTextColor("dbdbb9") -- Beige Color for AI
        slot.name._text:SetFont('Arial Gras', 12)
    elseif FindSlotForID(hostID) == slotNum then
        slot.name:SetTitleTextColor("ffc726") -- Orange Color for Host
        slot.name._text:SetFont('Arial Gras', 15)
    elseif slotState == 'player' then
        slot.name:SetTitleTextColor("64d264") -- Green Color for Players
        slot.name._text:SetFont('Arial Gras', 15)
    elseif isLocallyOwned then
        slot.name:SetTitleTextColor("6363d2") -- Blue Color for You
        slot.name._text:SetFont('Arial Gras', 15)
    else
        slot.name:SetTitleTextColor(UIUtil.fontColor) -- Normal Color for Other
        slot.name._text:SetFont('Arial Gras', 12)
    end

    local playerName = playerInfo.PlayerName
    if wasConnected(playerInfo.OwnerID) or isLocallyOwned or not playerInfo.Human then
        slot.name:SetTitleText(GetPlayerDisplayName(playerInfo))
        slot.name._text:SetFont('Arial Gras', 15)
        if not table.find(ConnectionEstablished, playerName) then
            if playerInfo.Human and not isLocallyOwned then
                AddChatText(LOCF("<LOC Engine0004>Connection to %s established.", playerName))

                table.insert(ConnectionEstablished, playerName)
                for k, v in CurrentConnection do
                    if v == playerName then
                        CurrentConnection[k] = nil
                        break
                    end
                end
            end
        end
    else
        slot.name:SetTitleText(LOCF('<LOC Engine0005>Connecting to %s...', playerName))
        slot.name._text:SetFont('Arial Gras', 11)
    end

    slot.faction:Show()

    -- Check if faction is possible for that slot, if not set to random
    -- For example: AIs always start with faction 5, so that needs to be adjusted to fit in slot.Faction
    if table.getn(slot.AvailableFactions) < playerInfo.Faction then
        playerInfo.Faction = table.getn(slot.AvailableFactions)
    end
    slot.faction:SetItem(playerInfo.Faction)

    slot.color:Show()
    Check_Availaible_Color(slotNum)

    slot.team:Show()
    slot.team:SetItem(playerInfo.Team)

    -- Send team data to the server
    if isHost then
        HostUtils.SendPlayerSettingsToServer(slotNum)
    end

    UIUtil.setVisible(slot.ready, playerInfo.Human and not singlePlayer)
    slot.ready:SetCheck(playerInfo.Ready, true)

    if isLocallyOwned and playerInfo.Human then
        Prefs.SetToCurrentProfile('LastColorFAF', playerInfo.PlayerColor)
        Prefs.SetToCurrentProfile('LastFaction', playerInfo.Faction)
    end

    -- Show the player's nationality
    if not playerInfo.Country then
        slot.KinderCountry:Hide()
    else
        slot.KinderCountry:Show()
        slot.KinderCountry:SetTexture(UIUtil.UIFile('/countries/'..playerInfo.Country..'.dds'))

        Tooltip.AddControlTooltip(slot.KinderCountry, {text=LOC("<LOC lobui_0413>Country"), body=LOC(CountryTooltips[playerInfo.Country])})
    end

    UpdateSlotBackground(slotNum)

    -- Set the CPU bar
    SetSlotCPUBar(slotNum, playerInfo)

    ShowGameQuality()
    RefreshMapPositionForAllControls(slotNum)

    if isHost then
        HostUtils.RefreshButtonEnabledness()
    end
end


function StressCPU(waitTime)
	local fakeBench = math.random(101,110)

    return fakeBench
end