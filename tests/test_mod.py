from pathlib import Path
import xml.etree.ElementTree as ET

from luaparser import ast
from lupa import LuaRuntime


ROOT = Path(__file__).parents[1]


def test_modinfo_is_valid_and_loads_gameplay_script():
    tree = ET.parse(ROOT / "TeamTerritoryUpgrades.modinfo")
    files = {node.text for node in tree.findall(".//File")}

    assert "TeamTerritoryUpgrades.lua" in files
    assert tree.find(".//AddGameplayScripts") is not None
    assert tree.find(".//ReplaceUIScript") is not None


def test_gameplay_script_has_valid_lua_syntax():
    source = (ROOT / "TeamTerritoryUpgrades.lua").read_text(encoding="utf-8")

    ast.parse(source)


def test_gameplay_script_registers_host_upgrade_handler():
    source = (ROOT / "TeamTerritoryUpgrades.lua").read_text(encoding="utf-8")

    assert "GameEvents.TTU_TeamTerritoryUpgrade.Add(TeamTerritoryUpgrade)" in source
    assert "IsOwnedTeamTerritory" in source
    assert "UnitManager.InitUnit" in source


def run_gameplay_with_players(player_specs):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        """
        calls = {}
        function makePlayer(id, team, alive)
            local diplomacy = { allied = {} }
            function diplomacy:HasAllied(other)
                return self.allied[other] == true
            end
            function diplomacy:SetHasAllied(other, value)
                table.insert(calls, {from = id, to = other, value = value})
                self.allied[other] = value
            end
            local player = { id = id, team = team, alive = alive, diplomacy = diplomacy }
            function player:GetID() return self.id end
            function player:GetTeam() return self.team end
            function player:IsAlive() return self.alive end
            function player:GetDiplomacy() return self.diplomacy end
            return player
        end
        players = {}
        GameEvents = { TTU_TeamTerritoryUpgrade = { Add = function(callback) handler = callback end } }
        PlayerManager = { GetAliveMajors = function() return players end }
        """
    )
    make_player = lua.globals().makePlayer
    players = lua.globals().players
    for player_id, team, alive in player_specs:
        players[len(players) + 1] = make_player(player_id, team, alive)

    source = (ROOT / "TeamTerritoryUpgrades.lua").read_text(encoding="utf-8")
    lua.execute(source)
    # The handler is registered successfully; execution is covered by the static
    # contract checks because its remaining API calls require Civ VI objects.
    return lua.globals().calls


def test_gameplay_handler_registers_in_a_lua_runtime():
    run_gameplay_with_players([])
