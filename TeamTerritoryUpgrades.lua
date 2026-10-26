-- Multiplayer-safe team-territory upgrade.
-- The UI sends a PlayerOperations.EXECUTE_SCRIPT request; this handler runs in gameplay.
local PREFIX = "[TeamTerritoryUpgrades] ";

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

local function CopyUnitState(oldUnit, newUnit)
	newUnit:SetDamage(oldUnit:GetDamage());
	newUnit:SetName(oldUnit:GetName());
	newUnit:SetFortifyTurns(oldUnit:GetFortifyTurns());

	local oldExperience = oldUnit:GetExperience();
	local newExperience = newUnit:GetExperience();
	newExperience:ChangeExperience(oldExperience:GetExperiencePoints());
	for promotion in GameInfo.UnitPromotions() do
		if oldExperience:HasPromotion(promotion.Index) then
			newExperience:SetPromotion(promotion.Index);
		end
	end

	local movesUsed = oldUnit:GetMaxMoves() - oldUnit:GetMovesRemaining();
	if movesUsed > 0 then
		UnitManager.ChangeMovesRemaining(newUnit, -movesUsed);
	end
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

	local upgradeType = GetUpgradeType(unit);
	if upgradeType == nil then
		Log("Rejected request: no upgrade defined for unit " .. tostring(unit:GetType()));
		return;
	end

	local goldCost = unit:GetUpgradeCost();
	local resourceCost = 0;
	local resourceType = nil;
	-- This accessor is available in the UI VM on some builds, but not in
	-- the gameplay VM. Keep the custom operation usable in both contexts.
	if type(unit.GetUpgradeResourceCost) == "function" then
		local resourceCallOK, cost, resource = pcall(function()
			return unit:GetUpgradeResourceCost();
		end);
		if resourceCallOK then
			resourceCost = cost or 0;
			resourceType = resource;
		end
	end
	local treasury = player:GetTreasury();
	local resources = player:GetResources();
	if goldCost == nil then goldCost = 0; end
	if resourceCost == nil then resourceCost = 0; end
	Log("Upgrade cost player=" .. tostring(playerID)
		.. " gold=" .. tostring(goldCost)
		.. " resource=" .. tostring(resourceCost));
	if treasury:GetGoldBalance() < goldCost then
		Log("Rejected request: insufficient gold");
		return;
	end
	if resourceCost > 0 and (resources == nil or resources:GetResourceAmount(resourceType) < resourceCost) then
		Log("Rejected request: insufficient strategic resource");
		return;
	end

	local x = unit:GetX();
	local y = unit:GetY();
	local oldUnitID = unit:GetID();
	local newUnit = UnitManager.InitUnit(playerID, upgradeType, x, y);
	if newUnit == nil then
		Log("Rejected request: InitUnit failed");
		return;
	end

	CopyUnitState(unit, newUnit);
	-- Destroy through the player's unit collection. UnitManager.Kill does not
	-- remove the old instance reliably when called from this custom operation.
	player:GetUnits():Destroy(unit);
	treasury:ChangeGoldBalance(-goldCost);
	if resourceCost > 0 then
		resources:ChangeResourceAmount(resourceType, -resourceCost);
	end
	Log("Upgrade completed player=" .. tostring(playerID)
		.. " oldUnit=" .. tostring(oldUnitID)
		.. " newUnit=" .. tostring(newUnit:GetID())
		.. " type=" .. tostring(upgradeType));
end

GameEvents.TTU_TeamTerritoryUpgrade.Add(TeamTerritoryUpgrade);
Log("Gameplay handler loaded.");
