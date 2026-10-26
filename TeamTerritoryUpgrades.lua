-- Multiplayer-safe team-territory upgrade.
-- The UI sends a PlayerOperations.EXECUTE_SCRIPT request; this handler runs in gameplay.
local PREFIX = "[TeamTerritoryUpgrades] ";
ExposedMembers = ExposedMembers or {};
ExposedMembers.GameEvents = GameEvents;

local function Log(message)
	print(PREFIX .. message);
end

local function GetUpgradeType(unit)
	local currentType = GameInfo.Units[unit:GetType()].UnitType;
	for row in GameInfo.UnitUpgrades() do
		if row.Unit == currentType then
			return row.UpgradeUnit;
		end
	end
	return nil;
end

local function IsOwnedTeamTerritory(playerID, unit)
	local plot = Map.GetPlot(unit:GetX(), unit:GetY());
	if plot == nil then return false; end
	local territoryOwner = plot:GetOwner();
	return territoryOwner ~= nil
		and territoryOwner >= 0
		and territoryOwner ~= playerID
		and Players[territoryOwner] ~= nil
		and Players[territoryOwner]:GetTeam() == Players[playerID]:GetTeam();
end

local function TeamTerritoryUpgrade(playerID, parameters)
	if parameters == nil or parameters.UnitID == nil then
		Log("Rejected request: missing UnitID");
		return;
	end

	local player = Players[playerID];
	local unit = player and player:GetUnits():FindID(parameters.UnitID);
	if unit == nil then
		Log("Rejected request: unit not found for player " .. tostring(playerID));
		return;
	end
	if not IsOwnedTeamTerritory(playerID, unit) then
		Log("Rejected request: territory is not owned by a teammate");
		return;
	end

	if GetUpgradeType(unit) == nil then
		Log("Rejected request: no upgrade defined for unit " .. tostring(unit:GetType()));
		return;
	end

	local territoryOwner = Map.GetPlot(unit:GetX(), unit:GetY()):GetOwner();
	local playerDiplomacy = player:GetDiplomacy();
	local ownerDiplomacy = Players[territoryOwner]:GetDiplomacy();
	playerDiplomacy:SetHasAllied(territoryOwner, true);
	ownerDiplomacy:SetHasAllied(playerID, true);
	Log("Native upgrade permission granted player=" .. tostring(playerID)
		.. " unit=" .. tostring(unit:GetID()));
	GameEvents.TTU_TeamUpgradePermissionGranted.Call(playerID, unit:GetID());
end

GameEvents.TTU_TeamTerritoryUpgrade.Add(TeamTerritoryUpgrade);
Log("Gameplay handler loaded.");
