dofile("../wow_api.lua")
dofile("../../Libs/LibStub/LibStub.lua")
dofile("../../Libs/AceSerializer-3.0/AceSerializer-3.0.lua")
local AceSer = LibStub("AceSerializer-3.0")
function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function checkSV()
   local function options()
      print "Checking options"
      print ""
      -- Filters
      print "Module  \tOption  \t\tProfile"
      for profile, v in pairs(RCLootCouncilDB.profiles) do
         if not v.modules then
            print(string.format("%s - \t%s",profile,"No module settings"))
         else
            for k,v in pairs(v.modules) do
               if v.moreInfo ~= nil then  print(string.format("%s: \t%s = %s \t| %s",k,"moreInfo", tostring(v.moreInfo), profile)) end
            end
         end
      end
      print "----------"
   end
   local function numComms()
      local num =0
      for k,v in pairs(RCLootCouncilDB.global.log) do
         if v:find("Comm received:") then num = num + 1 end
      end
      print(string.format("Comms: %d of %d = %.2f%%",num, #RCLootCouncilDB.global.log,num/#RCLootCouncilDB.global.log*100))
   end
   local function log()
      print "Checking log"
      print("version:", RCLootCouncilDB.global.version)
      print("old version:",RCLootCouncilDB.global.oldVersion)
      print("locale:\t", RCLootCouncilDB.global.locale)
      print ""
      numComms()
      for k,v in ipairs(RCLootCouncilDB.global.log) do
         if v:lower():find("%f[%a]error") then print("Error", k,v) end
         if v:find("Data wasn't ready") then print("Data wasn't ready",k,v) end
      end
      print "----------"
   end
   local function encounters()
      print("Checking Encounters")
      print ""
      local encounters = {}
      for k,v in ipairs(RCLootCouncilDB.global.log) do
         if v:find("(ENCOUNTER_END)") then
            local enc = {}
            for s in v:gmatch("%(([%w%d%s',-]+)%)") do table.insert(enc, s) end
            if not encounters[enc[2]] then
               encounters[enc[2]] = {}
            end
            if not encounters[enc[2]][enc[3]] then
               encounters[enc[2]][enc[3]] = {trys = 0, kills = 0}
            end
            if enc[5] == "0" then
               encounters[enc[2]][enc[3]].trys = encounters[enc[2]][enc[3]].trys + 1
            else
               encounters[enc[2]][enc[3]].kills = encounters[enc[2]][enc[3]].kills + 1
            end
         end
      end
      local names = {
         ["8"] =  "Mythic+",
         ["14"] = "Normal",
         ["15"] = "Heroic",
         ["16"] = "Mythic",
         ["17"] = "LFR",
      }
      for n, v in pairs(encounters) do
         for id, v in pairs(v) do
            print(string.format("wipes: %d,\t kills: %d\t%s - %s", v.trys, v.kills, n, names[id] or id))
         end
      end
      print "----------"
   end
   local function lootdb()
      print("Checking LootDB")
      print ""
      -- Check loot db
      local pcount, icount = 0, 0
      for _, data in pairs(RCLootCouncilLootDB.factionrealm or {}) do
         for player, items in pairs(data) do
            pcount = pcount + 1
            for i, id in ipairs(items) do
               icount = icount + 1
            --   if type(id.itemReplaced1) ~= "string" then print("error", player, i) end
               if not type(id.date) == "string" then print("error", player, i) end
               if not type(id.boss) == "string" then print(player, i) end
               if not type(id.response) == "string" then print(player, i) end
               if not type(id.votes) == "number" then print(player, i) end
               if not type(id.difficultyID) == "string" then print(player, i) end
               if not type(id.lootWon) == "string" then print(player, i) end
               if not type(id.time) == "string" then print(player, i) end
               if not type(id.instance) == "string" then print(player, i) end
               if not type(id.responseID) == "number" then print(player, i) end
               if type(id.color) ~= "table" then print(player, i) end
               if not type(id.class) == "string" then print(player, i) end
            end
         end
      end
      print(pcount, "players checked")
      print(icount, "items checked")
      print "----------"
   end
   local function otherVersions()
      print "Checking other players' version\n"
      local players = {}
      -- First extract the ones we have in verTestCandidates:
      if RCLootCouncilDB.global.verTestCandidates then
         for player, version in pairs(RCLootCouncilDB.global.verTestCandidates) do
            players[player:gsub("-.+", "")] = version:gsub("-.+", "")
         end
      else
         print "No 'verTestCandidates'" -- v2.7.8 somehow had a SV without it..
      end
      -- Then check the log:
      for i, entry in ipairs(RCLootCouncilDB.global.log) do
         if entry:find("Comm received:^1^SverTest^T^N1^S") then
            --"22:16:57 - Comm received:^1^SverTest^T^N1^S2.5.5^t
            --(from:) (Angramalnyu) (distri:)
            players[entry:match("%(from:%) %((.-)%)")] = entry:sub(44,48)
         end
      end
      table.sort(players)
      for player, v in spairs(players) do
         print(string.format("%s: %s",v,player))
      end
      print "----------"
   end

   local function tradables()
      print "Checking tradables\n"
      for i, entry in ipairs(RCLootCouncilDB.global.log) do
         if entry:find("tradable") then
            print("Line:",i,entry:match("(item:.-):*|h(.*)|h"))
         end
      end
      print "----------"
   end

   local function sessions()
      print "Gathering sessions:"
      local num = 1
      for i, entry in ipairs(RCLootCouncilDB.global.log) do
         if entry:find("lootTable") then
            --			"23:21:58 - Comm received:^1^SlootTable^T^N1^T^N1^T^SequipLoc^S^Silvl^N945^Slink^S|cffa335ee|Hitem:152525::::::::110:577::5:1:570:::|h[Helm~`of~`the~`Antoran~`Conqueror]|h|r^Stexture^N133126^SlootSlot^N5^SsubType^SJunk^Srelic^b^Sclasses^N2322^Sname^SHelm~`of~`the~`Antoran~`Conqueror^Stoken^SHeadSlot^Sboe^b^Sawarded^b^Squality^N4^t^N2^T^SequipLoc^S^Silvl^N945^Slink^S|cffa335ee|Hitem:152525::::::::110:577::5:1:570:::|h[Helm~`of~`the~`Antoran~`Conqueror]|h|r^Stexture^N133126^SlootSlot^N4^SsubType^SJunk^Srelic^b^Sclasses^N2322^Sname^SHelm~`of~`the~`Antoran~`Conqueror^Stoken^SHeadSlot^Sboe^b^Sawarded^b^Squality^N4^t^N3^T^SequipLoc^SINVTYPE_CLOAK^Sawarded^b^Slink^S|cffa335ee|Hitem:152062::::::::110:577::5:3:3611:1487:3528:::|h[Greatcloak~`of~`the~`Dark~`Pantheon]|h|r^Srelic^b^Stexture^N1627522^SsubType^SCloth^SlootSlot^N1^Sclasses^N4294967295^Sname^SGreatcloak~`of~`the~`Dark~`Pantheon^Sboe^b^Silvl^N945^Squality^N4^t^N4^T^SequipLoc^SINVTYPE_FEET^Sawarded^b^Slink^S|cffa335ee|Hitem:151940::::::::110:577::5:3:3611:1492:3336:::|h[Sandals~`of~`the~`Reborn~`Colossus]|h|r^Srelic^b^Stexture^N1627657^SsubType^SCloth^SlootSlot^N2^Sclasses^N4294967295^Sname^SSandals~`of~`the~`Reborn~`Colossus^Sboe^b^Silvl^N950^Squality^N4^t^N5^T^SequipLoc^SINVTYPE_FEET^Sawarded^b^Slink^S|cffa335ee|Hitem:151940::::::::110:577::5:3:3611:1487:3528:::|h[Sandals~`of~`the~`Reborn~`Colossus]|h|r^Srelic^b^Stexture^N1627657^SsubType^SCloth^SlootSlot^N3^Sclasses^N4294967295^Sname^SSandals~`of~`the~`Reborn~`Colossus^Sboe^b^Silvl^N945^Squality^N4^t^t^t^^ (from:) (Supadhunter) (distri:) (RAID)", -- [81]
            print("\nSession ", num, "ML:", entry:match(":%) %((%w+)%)",-35))
            -- Extract time
            print("Time:",entry:sub(1,9), "Index:", i)
            -- And message
            local msg = entry:match("(%^1.+\^\^)")
            local l1,l2,lt = AceSer:Deserialize(msg)
            for k,v in ipairs(unpack(lt)) do
               print("|  "..k,v.ilvl, v.link)
               print("|  "..v.equipLoc, v.subType)
               --print("Classes:", v.classes)
            end
            num = num + 1
         end
      end

      print "----------"
   end

   log()
   otherVersions()
   options()
   tradables()
   encounters()
   lootdb()
   sessions()
end

do
   dofile("sv_to_process.lua")
   checkSV()
   local ent = {}
   local var
   for k,v in ipairs(RCLootCouncilDB.global.log) do
      var = v:match(" - (%w+)")
      var = tostring(var)
      if not ent[var] then ent[var] = 1 else ent[var] = ent[var] + 1 end
      --print(var)
   end
   table.sort(ent)
   --for k,v in spairs(ent) do print(k,v) end

end