local old_CreateUI = CreateUI
local old_DoSlotBehavior = DoSlotBehavior
local PingTable = {}

local ConnectionStatusInfo = {
    'Player is not connected to someone',
    'Connected',
    'Not Connected',
    'No connection info available',
}

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
            Country = argv.PrefLanguage,
        }
    )
end

function CreateUI(maxPlayers)
	old_CreateUI(maxPlayers)
    GUI.pingThread = ForkThread(
    function()
        while lobbyComm do
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
						
                        if ping < 400 then GUI.slots[slot].pingStatus._bar:SetSolidColor('ff009900') 
						elseif ping < 450 then GUI.slots[slot].pingStatus._bar:SetSolidColor('ffe6d600') 
						else GUI.slots[slot].pingStatus._bar:SetSolidColor('ff9e0000') end
						if GUI.slots[slot].pingStatus.ConnectionStatus ~= 2 then GUI.slots[slot].pingStatus._bar:SetSolidColor('ff9e0000') end
						
						for k, r in PingTable do
							for j, p in r do
								if p > 450 and player.OwnerID == k then GUI.slots[slot].pingStatus._bar:SetSolidColor('ff9e0000') end 
							end
						end
						
						GUI.slots[slot].pingStatus._bar.Height:Set(4)
					else 
						GUI.slots[slot].pingStatus._bar.Height:Set(4)
						GUI.slots[slot].pingStatus:SetValue(500)
						GUI.slots[slot].pingStatus._bar:SetSolidColor('ff9e0000')
                    end
                end
            end
            WaitSeconds(0.0001)
        end
    end)
end

function SetSlotCPUBar(slot, playerInfo)
    if GUI.slots[slot].CPUSpeedBar then
        GUI.slots[slot].CPUSpeedBar:Hide()
        if playerInfo.Human then
            local bench_val = CPU_Benchmarks[playerInfo.PlayerName]
            if bench_val then
                if bench_val > GUI.slots[slot].CPUSpeedBar.barMax then
                    bench_val = GUI.slots[slot].CPUSpeedBar.barMax
                end
                GUI.slots[slot].CPUSpeedBar:SetValue(bench_val)
                GUI.slots[slot].CPUSpeedBar.CPUActualValue = bench_val
				
				if bench_val < 250 then GUI.slots[slot].CPUSpeedBar._bar:SetSolidColor('ff009900') 
				elseif bench_val < 350 then GUI.slots[slot].CPUSpeedBar._bar:SetSolidColor('ffe6d600') 
				else GUI.slots[slot].CPUSpeedBar._bar:SetSolidColor('ff9e0000') end
				
				GUI.slots[slot].CPUSpeedBar.Height:Set(4)
                GUI.slots[slot].CPUSpeedBar:Show()
            end
        end
    end
end

function Ping_AddControlTooltip(control, delay, slotNumber)
    local pingText = function()
        local pingInfo
        if GUI.slots[slotNumber].pingStatus.PingActualValue then
            pingInfo = GUI.slots[slotNumber].pingStatus.PingActualValue
        else
            pingInfo = LOC('<LOC lobui_0458>Unknown')
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
       
        body = ConnectionStatusInfo[conInfo] .. connectionText
        return (body)
    end
    Tooltip.AddAutoUpdatedControlTooltip(control, pingText, pingBody, delay)
end

function StressCPU(waitTime)
	local fakeBench = math.random(95,105)
    return fakeBench
end
