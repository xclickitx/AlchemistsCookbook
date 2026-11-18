-- Alchemist's Cookbook 1.0.1 by ClickIT, for WoW Forever (Interface 16001).
--
-- Opening a second profession window closes the first one, and that cancels a
-- repeat craft (smelting x20, potions xN). Alchemist's Cookbook saves each
-- profession's recipe list the moment you open that profession, then lets you
-- browse it in its own window that never touches the real profession window.
-- Your craft keeps running until you jump, move or cancel it.
--
-- It only READS. It never casts, crafts, opens or closes a profession window,
-- and uses no secure templates, so nothing it does can be a protected action.
--
-- Client API, checked against the Forever 1.60.1 client's own files
-- (Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua and the
-- Blizzard_Professions UI, read straight from the game data) and against
-- ForeverFishing's MasterChef code: the modern C_TradeSkillUI
-- (GetBaseProfessionInfo, GetChildProfessionInfo, GetRecipeInfo,
-- GetRecipeSchematic, GetRecipeOutputItemData, GetRecipeRequirements,
-- GetRemainingRecasts), C_Item.GetItemCount / GetItemInfo. The classic-era
-- GetTradeSkillInfo / GetCraftInfo globals are kept only as guarded fallbacks
-- (the Forever client ships the modern Professions UI, not the classic one).

local ADDON = ...
ADDON = ADDON or "AlchemistsCookbook"

local AC = {}
_G.AlchemistsCookbook = AC
AC.VERSION = "1.0.1"
AC.NAME = "Alchemist's Cookbook"

local floor, format, tonumber, tostring, type, select = math.floor, string.format, tonumber, tostring, type, select
local pairs, ipairs, pcall = pairs, ipairs, pcall
local unpack = unpack or table.unpack
local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

local DEFAULTS = {
	minimap = { hide = false, angle = 200 },
	scale = 1,
	pos = nil, -- { point, relPoint, x, y }
}
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.6, 1.5, 0.05

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------

local PREFIX = "|cffffd100Alchemist's|r |cff40c040Cookbook|r: "
local function out(msg, ...)
	if select("#", ...) > 0 then msg = format(msg, ...) end
	local frame = DEFAULT_CHAT_FRAME
	if frame and frame.AddMessage then frame:AddMessage(PREFIX .. msg) elseif print then print(PREFIX .. msg) end
end
AC.Print = out

---------------------------------------------------------------------------
-- Small safe helpers
---------------------------------------------------------------------------

local function secret(v)
	return v ~= nil and issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- pcall that returns only the first value, or nil on error / secret value.
local function try(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if not ok or secret(a) then return nil end
	return a
end

-- pcall returning every value (nil, nil... on error).
local function tryAll(fn, ...)
	if type(fn) ~= "function" then return end
	local r = { pcall(fn, ...) }
	if not r[1] then return end
	return select(2, unpack(r))
end

local function str(v) if type(v) == "string" and v ~= "" and not secret(v) then return v end end
local function num(v) if type(v) == "number" and not secret(v) then return v end end

local function inCombat() return InCombatLockdown and InCombatLockdown() or false end

local function after(sec, fn)
	if C_Timer and C_Timer.After then return C_Timer.After(sec, fn) end
	fn()
end

local function itemIDFromLink(link)
	return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end
AC.ItemIDFromLink = itemIDFromLink

-- name, link, icon (nil while the item isn't cached; asks the game to load it).
local function itemInfo(id)
	if not id then return nil end
	local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local name, link, icon
	if getInfo then
		local r = { pcall(getInfo, id) }
		if r[1] then name, link, icon = str(r[2]), str(r[3]), r[11] end
	end
	if not icon then
		local instant = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
		icon = try(instant, id)
	end
	if not name then
		local req = C_Item and C_Item.RequestLoadItemDataByID
		if req then pcall(req, id) end
	end
	return name, link, icon
end
AC.ItemInfo = itemInfo

-- Bags only, and bags + bank (the client remembers the bank after a visit).
function AC.CountItem(id, name)
	local get = (C_Item and C_Item.GetItemCount) or GetItemCount
	local key = id or name
	if not (get and key) then return 0, 0 end
	local bags = num(try(get, key, false)) or 0
	local all = num(try(get, key, true)) or bags
	if all < bags then all = bags end
	return bags, all
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------

local db, cdb
local function copyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			copyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function AC.InitDB(saved, savedChar)
	saved = type(saved) == "table" and saved or {}
	copyDefaults(saved, DEFAULTS)
	if type(saved.scale) ~= "number" or saved.scale < SCALE_MIN or saved.scale > SCALE_MAX then saved.scale = 1 end
	savedChar = type(savedChar) == "table" and savedChar or {}
	if type(savedChar.professions) ~= "table" then savedChar.professions = {} end
	if type(savedChar.collapsed) ~= "table" then savedChar.collapsed = {} end
	savedChar.dataVersion = 1
	db, cdb = saved, savedChar
	AC.db, AC.cdb = db, cdb
	return saved, savedChar
end

-- Professions saved on this character, sorted by name.
function AC.ProfessionNames()
	local t = {}
	if cdb then for name in pairs(cdb.professions) do t[#t + 1] = name end end
	table.sort(t)
	return t
end

---------------------------------------------------------------------------
-- Scanning (read-only)
---------------------------------------------------------------------------

-- Modern relative difficulty (Enum.TradeskillRelativeDifficulty) -> classic words.
local DIFF_BY_NUM = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }
local DIFF_COLOR = {
	optimal = { 1, 0.50, 0.25 }, medium = { 1, 1, 0 }, easy = { 0.25, 0.75, 0.25 },
	trivial = { 0.55, 0.55, 0.55 }, difficult = { 1, 0.1, 0.1 },
}
AC.DIFF_COLOR = DIFF_COLOR

local function diffFromNum(n)
	if type(n) ~= "number" then return "trivial" end
	local E = Enum and Enum.TradeskillRelativeDifficulty
	if E then
		if n == E.Optimal then return "optimal" elseif n == E.Medium then return "medium"
		elseif n == E.Easy then return "easy" elseif n == E.Trivial then return "trivial" end
	end
	return DIFF_BY_NUM[n] or "trivial"
end
AC.DiffFromNum = diffFromNum

local BASIC_REAGENT = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

-- Profession name / rank for the open window.
local function modernProfession(api)
	local base = try(api.GetBaseProfessionInfo)
	local child = try(api.GetChildProfessionInfo)
	base = type(base) == "table" and base or {}
	child = type(child) == "table" and child or {}
	local name = str(base.professionName) or str(child.parentProfessionName) or str(child.professionName)
	if not name and api.GetTradeSkillDisplayName and num(child.professionID) then
		name = str(try(api.GetTradeSkillDisplayName, child.professionID))
	end
	local rank, maxRank = num(child.skillLevel), num(child.maxSkillLevel)
	if not rank or (rank == 0 and (num(base.skillLevel) or 0) > 0) then
		rank, maxRank = num(base.skillLevel), num(base.maxSkillLevel)
	end
	return name, rank or 0, maxRank or 0, num(base.professionID) or num(child.parentProfessionID), num(child.professionID)
end

local function blockedSource(api)
	for _, m in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting", "IsRuneforging" }) do
		if api[m] and try(api[m]) then return m end
	end
end

-- Scan the open modern profession window. Returns entry or nil, reason.
function AC.ScanModern()
	local api = C_TradeSkillUI
	if type(api) ~= "table" or not api.GetRecipeInfo then return nil, "noapi" end
	if blockedSource(api) then return nil, "linked" end
	if api.IsDataSourceChanging and try(api.IsDataSourceChanging) then return nil, "busy" end
	local name, rank, maxRank, profID, childID = modernProfession(api)
	if not name then return nil, "noprofession" end

	local ids = try(api.GetAllRecipeIDs)
	if type(ids) ~= "table" or #ids == 0 then ids = try(api.GetFilteredRecipeIDs) end
	if (type(ids) ~= "table" or #ids == 0) and api.GetProfessionSpells and profID then
		ids = try(api.GetProfessionSpells, profID, childID)
	end
	if type(ids) ~= "table" or #ids == 0 then return nil, "empty" end

	local catName = {}
	local function category(id)
		if not id then return nil end
		if catName[id] == nil then
			local c = try(api.GetCategoryInfo, id)
			catName[id] = (type(c) == "table" and str(c.name)) or false
		end
		return catName[id] or nil
	end

	local recipes, seen = {}, {}
	for _, id in ipairs(ids) do
		if type(id) == "number" and not seen[id] then
			seen[id] = true
			local info = try(api.GetRecipeInfo, id)
			if type(info) == "table" and info.learned == true and not info.isDummyRecipe
				and not info.isGatheringRecipe and not info.isRecraft and not info.isSalvageRecipe and str(info.name) then
				local r = {
					id = id, name = info.name, icon = info.icon,
					difficulty = diffFromNum(info.relativeDifficulty),
					header = category(info.categoryID) or "Recipes",
					spellLink = str(info.hyperlink) or str(try(api.GetRecipeLink, id)),
					numMin = 1, numMax = 1, reagents = {}, tools = {},
				}
				local sch = try(api.GetRecipeSchematic, id, false)
				if type(sch) == "table" then
					r.numMin = num(sch.quantityMin) or 1
					r.numMax = num(sch.quantityMax) or r.numMin
					r.itemID = num(sch.outputItemID)
					local byID = {}
					for _, slot in ipairs(type(sch.reagentSlotSchematics) == "table" and sch.reagentSlotSchematics or {}) do
						local reagent = type(slot.reagents) == "table" and slot.reagents[1]
						local rid = reagent and num(reagent.itemID)
						local q = num(slot.quantityRequired)
						if slot.required ~= false and (slot.reagentType == nil or slot.reagentType == BASIC_REAGENT)
							and rid and q and q > 0 then
							if byID[rid] then byID[rid].count = byID[rid].count + q
							else
								local rn, rl, ri = itemInfo(rid)
								local e = { id = rid, count = q, name = rn, link = rl, icon = ri }
								r.reagents[#r.reagents + 1] = e
								byID[rid] = e
							end
						end
					end
				end
				local outp = try(api.GetRecipeOutputItemData, id)
				if type(outp) == "table" then
					r.itemID = r.itemID or num(outp.itemID)
					r.link = str(outp.hyperlink)
					r.icon = r.icon or outp.icon
				end
				if r.itemID and not r.link then local _, l = itemInfo(r.itemID) r.link = l end
				local reqs = try(api.GetRecipeRequirements, id)
				if type(reqs) == "table" then
					for _, q in ipairs(reqs) do
						if type(q) == "table" and str(q.name) then r.tools[#r.tools + 1] = q.name end
					end
				end
				recipes[#recipes + 1] = r
			end
		end
	end
	if #recipes == 0 then return nil, "empty" end
	return { name = name, rank = rank, maxRank = maxRank, professionID = profID, recipes = recipes, api = "modern" }
end

-- Classic-era trade skill window (GetTradeSkillInfo...). Fallback only.
function AC.ScanClassicTrade()
	if not (GetNumTradeSkills and GetTradeSkillInfo) then return nil, "noapi" end
	local name, rank, maxRank = tryAll(GetTradeSkillLine)
	name = str(name)
	if not name or name == "UNKNOWN" then return nil, "noprofession" end
	local n = num(try(GetNumTradeSkills)) or 0
	local recipes, header, collapsed = {}, "Recipes", false
	for i = 1, n do
		local rname, kind = tryAll(GetTradeSkillInfo, i)
		rname = str(rname)
		if rname then
			if kind == "header" or kind == "subheader" then
				header = rname
				local _, _, _, expanded = tryAll(GetTradeSkillInfo, i)
				if expanded == false then collapsed = true end
			else
				local r = { id = nil, name = rname, difficulty = DIFF_COLOR[kind] and kind or "trivial", header = header,
					icon = try(GetTradeSkillIcon, i), link = str(try(GetTradeSkillItemLink, i)),
					spellLink = str(try(GetTradeSkillRecipeLink, i)), reagents = {}, tools = {} }
				r.itemID = itemIDFromLink(r.link)
				local lo, hi = tryAll(GetTradeSkillNumMade, i)
				r.numMin, r.numMax = num(lo) or 1, num(hi) or num(lo) or 1
				for j = 1, num(try(GetTradeSkillNumReagents, i)) or 0 do
					local rn, ri, need = tryAll(GetTradeSkillReagentInfo, i, j)
					local rl = str(try(GetTradeSkillReagentItemLink, i, j))
					if str(rn) or rl then
						r.reagents[#r.reagents + 1] = { id = itemIDFromLink(rl), name = str(rn), link = rl, icon = ri, count = num(need) or 1 }
					end
				end
				local tools = { tryAll(GetTradeSkillTools, i) }
				for k = 1, #tools, 2 do if str(tools[k]) then r.tools[#r.tools + 1] = tools[k] end end
				recipes[#recipes + 1] = r
			end
		end
	end
	if #recipes == 0 then return nil, "empty" end
	return { name = name, rank = num(rank) or 0, maxRank = num(maxRank) or 0, recipes = recipes, api = "classic", partial = collapsed }
end

-- Classic Craft window (Enchanting / Beast Training). Fallback only.
function AC.ScanClassicCraft()
	if not (GetNumCrafts and GetCraftInfo) then return nil, "noapi" end
	local name, rank, maxRank = tryAll(GetCraftDisplaySkillLine)
	name = str(name) or str(try(GetCraftName))
	if not name then return nil, "noprofession" end
	local recipes, header = {}, "Recipes"
	for i = 1, num(try(GetNumCrafts)) or 0 do
		local rname, _, kind = tryAll(GetCraftInfo, i)
		rname = str(rname)
		if rname then
			if kind == "header" then header = rname
			else
				local r = { name = rname, difficulty = DIFF_COLOR[kind] and kind or "trivial", header = header,
					icon = try(GetCraftIcon, i), link = str(try(GetCraftItemLink, i)), reagents = {}, tools = {},
					numMin = 1, numMax = 1 }
				r.itemID = itemIDFromLink(r.link)
				if GetCraftNumMade then local lo, hi = tryAll(GetCraftNumMade, i) r.numMin, r.numMax = num(lo) or 1, num(hi) or num(lo) or 1 end
				for j = 1, num(try(GetCraftNumReagents, i)) or 0 do
					local rn, ri, need = tryAll(GetCraftReagentInfo, i, j)
					local rl = str(try(GetCraftReagentItemLink, i, j))
					if str(rn) or rl then
						r.reagents[#r.reagents + 1] = { id = itemIDFromLink(rl), name = str(rn), link = rl, icon = ri, count = num(need) or 1 }
					end
				end
				local focus = str(try(GetCraftSpellFocus, i))
				if focus then r.tools[1] = focus end
				recipes[#recipes + 1] = r
			end
		end
	end
	if #recipes == 0 then return nil, "empty" end
	return { name = name, rank = num(rank) or 0, maxRank = num(maxRank) or 0, recipes = recipes, api = "craft" }
end

-- Store a scan. An empty or failed scan never replaces good saved data.
function AC.Store(entry)
	if not (cdb and type(entry) == "table" and entry.name and type(entry.recipes) == "table" and #entry.recipes > 0) then return false end
	entry.api = nil
	entry.scannedAt = (time and time()) or 0
	local old = cdb.professions[entry.name]
	cdb.professions[entry.name] = entry
	if AC.OnStored then AC.OnStored(entry.name, not old) end
	return true
end

-- kind: "trade" (modern first, classic fallback) or "craft".
function AC.ScanAndStore(kind)
	local entry, why
	if kind == "craft" then
		entry, why = AC.ScanClassicCraft()
	else
		entry, why = AC.ScanModern()
		if not entry and why == "noapi" then entry, why = AC.ScanClassicTrade() end
	end
	if entry and AC.Store(entry) then return entry end
	return nil, why
end

-- Debounced scans after profession events.
local pending, lastScan = {}, {}
local RETRIES = 4
function AC.RequestScan(kind, force)
	kind = kind or "trade"
	local now = GetTime and GetTime() or 0
	if not force and lastScan[kind] and now - lastScan[kind] < 5 then return end
	if pending[kind] then return end
	pending[kind] = true
	local tries = 0
	local function run()
		local entry, why = AC.ScanAndStore(kind)
		tries = tries + 1
		if not entry and (why == "busy" or why == "empty") and tries < RETRIES then
			after(1, run)
			return
		end
		pending[kind] = nil
		lastScan[kind] = GetTime and GetTime() or 0
	end
	after(0.5, run)
end

---------------------------------------------------------------------------
-- Core logic used by the window (testable)
---------------------------------------------------------------------------

-- How many times the recipe can be made from your bags (and bags + bank).
function AC.Craftable(recipe)
	if type(recipe) ~= "table" or type(recipe.reagents) ~= "table" or #recipe.reagents == 0 then return 0, 0, false end
	local bagsMin, allMin
	for _, rg in ipairs(recipe.reagents) do
		local need = rg.count or 1
		if need < 1 then need = 1 end
		local bags, all = AC.CountItem(rg.id, rg.name)
		local b, a = floor(bags / need), floor(all / need)
		bagsMin = bagsMin and math.min(bagsMin, b) or b
		allMin = allMin and math.min(allMin, a) or a
	end
	return bagsMin or 0, allMin or 0, true
end

local function lower(s) return type(s) == "string" and s:lower() or "" end

function AC.Matches(recipe, query)
	query = lower(query):gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then return true end
	if lower(recipe.name):find(query, 1, true) then return true end
	for _, rg in ipairs(recipe.reagents or {}) do
		local n = rg.name or (rg.id and itemInfo(rg.id))
		if n then rg.name = n end
		if lower(n):find(query, 1, true) then return true end
	end
	return false
end

-- Visible rows for a profession: headers (in first-seen order) and recipes.
-- Collapsed headers hide their recipes unless a search is active.
function AC.BuildRows(profName, query)
	local rows = {}
	local p = cdb and cdb.professions[profName]
	if not p then return rows end
	local collapsed = cdb.collapsed[profName] or {}
	local order, groups = {}, {}
	for _, r in ipairs(p.recipes) do
		local h = r.header or "Recipes"
		if not groups[h] then groups[h] = {} order[#order + 1] = h end
		if AC.Matches(r, query) then groups[h][#groups[h] + 1] = r end
	end
	local searching = lower(query):match("%S") ~= nil
	for _, h in ipairs(order) do
		local list = groups[h]
		if #list > 0 or not searching then
			local isCollapsed = collapsed[h] and not searching
			rows[#rows + 1] = { header = h, collapsed = isCollapsed and true or false, count = #list }
			if not isCollapsed then
				for _, r in ipairs(list) do rows[#rows + 1] = { recipe = r } end
			end
		end
	end
	return rows
end

function AC.ToggleHeader(profName, header)
	if not cdb then return end
	cdb.collapsed[profName] = cdb.collapsed[profName] or {}
	local t = cdb.collapsed[profName]
	if t[header] then t[header] = nil else t[header] = true end
	if AC.Refresh then AC.Refresh() end
end

-- Find a saved recipe by its spell ID (modern recipeID == cast spell) or name.
function AC.FindRecipe(spellID, spellName)
	if not cdb then return nil end
	for pname, p in pairs(cdb.professions) do
		for _, r in ipairs(p.recipes) do
			if (spellID and r.id == spellID) or (spellName and r.name == spellName) then return r, pname end
		end
	end
end

---------------------------------------------------------------------------
-- Repeat-craft status line (read-only: just listens to cast and chat events)
--
-- One "session" = one Create / Create All batch. The batch size is read once,
-- at the first cast, as GetRemainingRecasts() + 1 (the same formula the
-- client's own Professions UI uses). After that, "done" is counted here and
-- "left" is worked out as size - done, so a lagging remaining-recasts value
-- can't make the line jump around. Completions are counted from
-- UNIT_SPELLCAST_SUCCEEDED for the batch's spell, with the chat line
-- "You create: [item]" as a fallback. Each cast (by its cast GUID) is counted
-- once, and a chat line right after a counted SUCCEEDED is treated as its echo.
-- Recipes are matched by spell ID / name, never by table, so a rescan of the
-- open profession window during the batch doesn't reset anything.
---------------------------------------------------------------------------

local cast = { active = false, made = 0, total = nil, counted = {} }
AC.cast = cast
local STALE_AFTER = 8 -- seconds with no next cast after a completion = batch over
local ECHO_WINDOW = 1 -- seconds: a "You create" line this soon after a counted cast is that cast

local function remainingRecasts()
	local api = C_TradeSkillUI
	local n = api and num(try(api.GetRemainingRecasts))
	if not n and GetTradeskillRepeatCount then
		local c = num(try(GetTradeskillRepeatCount))
		if c then n = math.max(c - 1, 0) end
	end
	if n and n < 0 then n = 0 end
	return n
end

-- The batch's recipe, looked up fresh (rescans replace the saved tables).
local function castRecipe()
	if not cast.spellID and not cast.spellName then return nil end
	return AC.FindRecipe(cast.spellID, cast.spellName)
end

local function endSession()
	cast.active, cast.casting, cast.castGUID = false, false, nil
end

local function startSession(spellID, spellName, live)
	cast.active = true
	cast.spellID, cast.spellName = spellID, spellName
	cast.made = 0
	cast.counted = {}
	cast.lastCountAt, cast.lastCountBy = nil, nil
	cast.total = live and (live + 1) or nil
	cast.session = (cast.session or 0) + 1
end


-- Left in the batch, counting the one being cast now.
function AC.CastLeft()
	if not (cast.active and cast.total) then return nil end
	return math.max(cast.total - cast.made, 0)
end

local function scheduleStaleCheck()
	local session, made = cast.session, cast.made
	cast.lastDone = GetTime and GetTime() or 0
	after(STALE_AFTER, function()
		if cast.active and cast.session == session and cast.made == made and not cast.casting then
			endSession()
			if AC.UpdateCastLine then AC.UpdateCastLine() end
		end
	end)
end

function AC.CastText()
	if not cast.active then return nil end
	local r = castRecipe()
	if not r then return nil end
	local made = r.numMin == r.numMax and tostring(r.numMin or 1) or ((r.numMin or 1) .. "-" .. (r.numMax or 1))
	local what = (r.link or r.name) .. ((r.numMax or 1) > 1 and (" x" .. made) or "")
	local left = AC.CastLeft()
	if left then
		return format("Crafting %s: %d of %d done, %d left", what, cast.made, cast.total, left)
	end
	return format("Crafting %s: %d done", what, cast.made)
end

-- Count one finished craft. guid: the cast it belongs to (nil if unknown).
local function countSuccess(source, guid)
	local t = GetTime and GetTime() or 0
	if guid and cast.counted[guid] then return false end
	if source == "chat" and cast.lastCountBy == "cast" and cast.lastCountAt and t - cast.lastCountAt <= ECHO_WINDOW then
		return false -- the chat echo of a SUCCEEDED we already counted
	end
	if guid then cast.counted[guid] = true end
	cast.made = cast.made + 1
	cast.lastCountAt, cast.lastCountBy = t, source
	if cast.total and cast.made >= cast.total then endSession() return true end
	scheduleStaleCheck()
	return true
end

function AC.OnCastEvent(event, unit, castGUID, spellID)
	if unit ~= "player" or secret(spellID) or secret(castGUID) then return end
	if event == "UNIT_SPELLCAST_START" then
		local name = C_Spell and C_Spell.GetSpellName and str(try(C_Spell.GetSpellName, spellID))
		local r = AC.FindRecipe(spellID, name)
		if r then
			local live = remainingRecasts()
			local same = cast.active and ((cast.spellID and cast.spellID == spellID) or (name and cast.spellName == name))
			-- A new batch: different recipe, no batch running, or the client now
			-- reports more queued than this batch has left (a fresh Create All).
			if not same or (live and cast.total and live > cast.total - cast.made) then
				startSession(spellID, name, live)
			elseif not cast.total and live then
				cast.total = cast.made + live + 1
			end
			cast.casting, cast.castGUID = true, castGUID
		end
	elseif cast.active and ((cast.spellID and spellID == cast.spellID)) then
		if castGUID and cast.castGUID and castGUID ~= cast.castGUID then return end
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			cast.casting = false
			countSuccess("cast", castGUID or cast.castGUID)
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
			endSession()
		end
	end
	if AC.UpdateCastLine then AC.UpdateCastLine() end
end

-- "You create: [Tin Bar]." / "You create: [Bronze Bar]x2." -> item ID, or nil.
local function createdPrefixes()
	local t = {}
	for _, g in ipairs({ LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE }) do
		local pre = type(g) == "string" and g:match("^(.-)%%s")
		if pre and pre ~= "" then t[#t + 1] = pre end
	end
	if #t == 0 then t[1] = "You create: " end
	return t
end

function AC.ParseCreated(msg)
	if type(msg) ~= "string" or secret(msg) then return nil end
	for _, pre in ipairs(createdPrefixes()) do
		if msg:sub(1, #pre) == pre then return itemIDFromLink(msg) end
	end
	return nil
end

function AC.OnChatCreate(msg)
	if not cast.active then return end
	local id = AC.ParseCreated(msg)
	if not id then return end
	local r = castRecipe()
	if not (r and r.itemID == id) then return end
	-- Each completed craft prints one line, even when it makes more than one.
	countSuccess("chat", cast.castGUID)
	if AC.UpdateCastLine then AC.UpdateCastLine() end
end

---------------------------------------------------------------------------
-- The Cookbook window
---------------------------------------------------------------------------

local frame, ui
local selectedProf, selectedRecipe
local ROW_H = 16
local LIST_W = 250

local function tooltipFor(owner, link, itemID)
	if not GameTooltip then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if link and link:find("|H", 1, true) then
		pcall(GameTooltip.SetHyperlink, GameTooltip, link:match("|H(.-)|h") or link)
	elseif itemID then
		if GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, itemID)
		else pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. itemID) end
	else
		return GameTooltip:Hide()
	end
	GameTooltip:Show()
end

local function hideTooltip() if GameTooltip then GameTooltip:Hide() end end

local function label(parent, font, text, width)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	if text then fs:SetText(text) end
	return fs
end

local function pushButton(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 110, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function savePosition()
	if not frame then return end
	local point, _, relPoint, x, y = frame:GetPoint()
	if point then db.pos = { point, relPoint, x, y } end
end

function AC.ApplyLayout()
	if not frame then return end
	frame:SetScale(db.scale or 1)
	frame:ClearAllPoints()
	if type(db.pos) == "table" and db.pos[1] then
		frame:SetPoint(db.pos[1], UIParent, db.pos[2] or db.pos[1], db.pos[3] or 0, db.pos[4] or 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
end

local function colorText(text, rgb)
	return format("|cff%02x%02x%02x%s|r", rgb[1] * 255, rgb[2] * 255, rgb[3] * 255, text)
end

local function buildFrame()
	frame = CreateFrame("Frame", "AlchemistsCookbookFrame", UIParent, "BackdropTemplate")
	frame:Hide()
	frame:SetSize(660, 450)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() end)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end
	-- Esc closes it.
	if type(UISpecialFrames) == "table" then
		local found
		for _, n in ipairs(UISpecialFrames) do if n == "AlchemistsCookbookFrame" then found = true end end
		if not found then table.insert(UISpecialFrames, "AlchemistsCookbookFrame") end
	end
	ui = {}
	AC._ui = ui -- tests

	local title = label(frame, "GameFontNormalLarge", AC.NAME)
	title:SetPoint("TOPLEFT", 20, -18)
	ui.title = title
	ui.rank = label(frame, "GameFontHighlightSmall", "")
	ui.rank:SetPoint("LEFT", title, "RIGHT", 10, 0)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)
	close:SetScript("OnClick", function() frame:Hide() end)
	ui.close = close

	-- Profession tabs (one button per saved profession).
	ui.tabs = {}
	ui.tabBar = CreateFrame("Frame", nil, frame)
	ui.tabBar:SetPoint("TOPLEFT", 18, -40)
	ui.tabBar:SetSize(620, 24)

	-- Search.
	local search = CreateFrame("EditBox", "AlchemistsCookbookSearch", frame, "InputBoxTemplate")
	search:SetSize(LIST_W - 60, 20)
	search:SetAutoFocus(false)
	search:SetPoint("TOPLEFT", 64, -72)
	local sl = label(frame, "GameFontNormalSmall", "Search:")
	sl:SetPoint("RIGHT", search, "LEFT", -8, 0)
	search:SetScript("OnTextChanged", function() AC.Refresh() end)
	search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	ui.search = search

	-- Recipe list.
	local scroll = CreateFrame("ScrollFrame", "AlchemistsCookbookList", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, -98)
	scroll:SetSize(LIST_W, 300)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(LIST_W, 10)
	scroll:SetScrollChild(child)
	ui.scroll, ui.list, ui.rows = scroll, child, {}

	ui.empty = label(frame, "GameFontDisable", "", LIST_W)
	ui.empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -4)

	-- Details.
	local d = CreateFrame("Frame", nil, frame)
	d:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 34, 0)
	d:SetSize(330, 300)
	ui.detail = d
	local icon = CreateFrame("Button", nil, d)
	icon:SetSize(36, 36)
	icon:SetPoint("TOPLEFT", 0, 0)
	icon.tex = icon:CreateTexture(nil, "ARTWORK")
	icon.tex:SetAllPoints()
	icon:SetScript("OnEnter", function(self) local r = selectedRecipe if r then tooltipFor(self, r.link or r.spellLink, r.itemID) end end)
	icon:SetScript("OnLeave", hideTooltip)
	ui.icon = icon
	ui.dName = label(d, "GameFontNormal", "", 280)
	ui.dName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
	ui.dMakes = label(d, "GameFontHighlightSmall", "", 280)
	ui.dMakes:SetPoint("TOPLEFT", ui.dName, "BOTTOMLEFT", 0, -4)
	ui.dTools = label(d, "GameFontHighlightSmall", "", 330)
	ui.dTools:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
	ui.dCraft = label(d, "GameFontNormal", "", 330)
	ui.dCraft:SetPoint("TOPLEFT", ui.dTools, "BOTTOMLEFT", 0, -6)
	ui.rhead = label(d, "GameFontNormalSmall", "Reagents", 330)
	ui.rhead:SetPoint("TOPLEFT", ui.dCraft, "BOTTOMLEFT", 0, -10)
	ui.reagents = {}

	-- Footer: saved time + repeat-craft status.
	ui.saved = label(frame, "GameFontDisableSmall", "", 620)
	ui.saved:SetPoint("BOTTOMLEFT", 20, 36)
	ui.castLine = label(frame, "GameFontHighlightSmall", "", 620)
	ui.castLine:SetPoint("BOTTOMLEFT", 20, 20)

	frame:SetScript("OnShow", function(self)
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		AC.Refresh()
	end)
	frame:SetScript("OnHide", function(self)
		self:UnregisterEvent("BAG_UPDATE_DELAYED")
		self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		hideTooltip()
		if ui.search then ui.search:ClearFocus() end
	end)
	local refreshQueued
	frame:SetScript("OnEvent", function()
		if refreshQueued then return end
		refreshQueued = true
		after(0.2, function() refreshQueued = false if frame:IsShown() then AC.Refresh() end end)
	end)
	AC.ApplyLayout()
	return frame
end

local function getRow(i)
	local row = ui.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, ui.list)
	row:SetSize(LIST_W - 4, ROW_H)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.text = label(row, "GameFontHighlightSmall", "", LIST_W - 44)
	row.text:SetPoint("LEFT", 4, 0)
	row.count = label(row, "GameFontHighlightSmall", "", 40)
	row.count:SetPoint("RIGHT", -2, 0)
	row.count:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		if self.data and self.data.header then AC.ToggleHeader(selectedProf, self.data.header)
		elseif self.data then selectedRecipe = self.data.recipe AC.Refresh() end
	end)
	row:SetScript("OnEnter", function(self)
		local r = self.data and self.data.recipe
		if r then tooltipFor(self, r.link or r.spellLink, r.itemID) end
	end)
	row:SetScript("OnLeave", hideTooltip)
	ui.rows[i] = row
	return row
end

local function getReagentRow(i)
	local row = ui.reagents[i]
	if row then return row end
	row = CreateFrame("Button", nil, ui.detail)
	row:SetSize(330, 20)
	row:SetPoint("TOPLEFT", ui.rhead, "BOTTOMLEFT", 0, -4 - (i - 1) * 22)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(18, 18)
	row.icon:SetPoint("LEFT", 0, 0)
	row.text = label(row, "GameFontHighlightSmall", "", 190)
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.have = label(row, "GameFontHighlightSmall", "", 130)
	row.have:SetPoint("RIGHT", 0, 0)
	row.have:SetJustifyH("RIGHT")
	row:SetScript("OnEnter", function(self) local g = self.data if g then tooltipFor(self, g.link, g.id) end end)
	row:SetScript("OnLeave", hideTooltip)
	ui.reagents[i] = row
	return row
end

local function refreshTabs(names)
	for i, name in ipairs(names) do
		local b = ui.tabs[i]
		if not b then
			b = pushButton(ui.tabBar, name, 100, function(self) selectedProf = self.prof selectedRecipe = nil AC.Refresh() end)
			b:SetSize(100, 22)
			b:SetPoint("TOPLEFT", (i - 1) * 102, 0)
			ui.tabs[i] = b
		end
		b.prof = name
		b:SetText(name)
		b:Show()
		if name == selectedProf then b:Disable() else b:Enable() end
	end
	for i = #names + 1, #ui.tabs do ui.tabs[i]:Hide() end
end

local function refreshDetail()
	local r = selectedRecipe
	if not r then
		ui.icon:Hide()
		ui.dName:SetText(selectedProf and "Pick a recipe on the left." or "")
		ui.dMakes:SetText("")
		ui.dTools:SetText("")
		ui.dCraft:SetText("")
		ui.rhead:Hide()
		for _, row in ipairs(ui.reagents) do row:Hide() end
		return
	end
	ui.icon:Show()
	ui.icon.tex:SetTexture(r.icon or 134400)
	ui.dName:SetText(colorText(r.name, DIFF_COLOR[r.difficulty] or DIFF_COLOR.trivial))
	local made = r.numMin == r.numMax and tostring(r.numMin or 1) or ((r.numMin or 1) .. "-" .. (r.numMax or 1))
	ui.dMakes:SetText("Makes " .. made .. ((r.link and (" " .. r.link)) or "") .. "  |cff888888(" .. (r.difficulty or "") .. ")|r")
	ui.dTools:SetText(#(r.tools or {}) > 0 and ("Requires: " .. table.concat(r.tools, ", ")) or "")
	local bags, all, has = AC.Craftable(r)
	if not has then ui.dCraft:SetText("No reagents needed.")
	elseif all > bags then ui.dCraft:SetText(format("You can make %d now (%d counting your bank).", bags, all))
	else ui.dCraft:SetText(format("You can make %d now.", bags)) end
	ui.rhead:SetShown(#r.reagents > 0)
	for i, g in ipairs(r.reagents) do
		local row = getReagentRow(i)
		row.data = g
		if g.id and (not g.name or not g.link or not g.icon) then
			local n, l, ic = itemInfo(g.id)
			g.name, g.link, g.icon = g.name or n, g.link or l, g.icon or ic
		end
		row.icon:SetTexture(g.icon or 134400)
		row.text:SetText(g.link or g.name or ("item " .. tostring(g.id)))
		local b, a = AC.CountItem(g.id, g.name)
		local need = g.count or 1
		local col = b >= need and "|cff20ff20" or (a >= need and "|cffffd100" or "|cffff4040")
		local bank = a > b and format(" |cff888888(+%d bank)|r", a - b) or ""
		row.have:SetText(format("%shave %d|r / need %d%s", col, b, need, bank))
		row:Show()
	end
	for i = #r.reagents + 1, #ui.reagents do ui.reagents[i]:Hide() end
end

function AC.UpdateCastLine()
	if not ui then return end
	ui.castLine:SetText(AC.CastText() or "")
end

function AC.Refresh()
	if not (frame and ui and frame:IsShown()) then return end
	local names = AC.ProfessionNames()
	if selectedProf and not cdb.professions[selectedProf] then selectedProf, selectedRecipe = nil, nil end
	selectedProf = selectedProf or names[1]
	refreshTabs(names)
	local p = selectedProf and cdb.professions[selectedProf]
	-- A rescan replaces the recipe tables; keep the same recipe selected.
	if selectedRecipe and p then
		local found
		for _, r in ipairs(p.recipes) do
			if r == selectedRecipe then found = r break end
			if not found and ((selectedRecipe.id and r.id == selectedRecipe.id) or (not selectedRecipe.id and r.name == selectedRecipe.name)) then found = r end
		end
		selectedRecipe = found
	elseif not p then
		selectedRecipe = nil
	end
	if p then
		ui.rank:SetText(format("%s %d/%d", selectedProf, p.rank or 0, p.maxRank or 0))
		ui.saved:SetText(format("%d recipes, saved %s. Open %s once in a while to keep this list current.",
			#p.recipes, (date and p.scannedAt and p.scannedAt > 0) and date("%b %d %H:%M", p.scannedAt) or "earlier", selectedProf))
	else
		ui.rank:SetText("")
		ui.saved:SetText("")
	end
	local rows = AC.BuildRows(selectedProf, ui.search:GetText())
	AC._rows = rows -- tests
	if #names == 0 then
		ui.empty:SetText("Nothing saved yet. Open each of your professions once (the normal way) and the Cookbook will remember it.")
	elseif #rows == 0 then
		ui.empty:SetText("No recipes match.")
	else
		ui.empty:SetText("")
	end
	for i, data in ipairs(rows) do
		local row = getRow(i)
		row.data = data
		if data.header then
			row.text:SetText((data.collapsed and "|cffffd100[+]|r " or "|cffffd100[-]|r ") .. "|cffffd100" .. data.header .. "|r")
			row.count:SetText("")
		else
			local r = data.recipe
			local sel = r == selectedRecipe and "> " or "   "
			row.text:SetText(sel .. colorText(r.name, DIFF_COLOR[r.difficulty] or DIFF_COLOR.trivial))
			local n = AC.Craftable(r)
			row.count:SetText(n > 0 and ("[" .. n .. "]") or "")
		end
		row:Show()
	end
	for i = #rows + 1, #ui.rows do ui.rows[i]:Hide() ui.rows[i].data = nil end
	ui.list:SetHeight(math.max(10, #rows * ROW_H))
	refreshDetail()
	AC.UpdateCastLine()
end

function AC.Show(prof)
	if not db then return end
	if not frame then buildFrame() end
	if prof then
		for _, n in ipairs(AC.ProfessionNames()) do
			if n:lower() == prof:lower() or n:lower():find(prof:lower(), 1, true) == 1 then selectedProf, selectedRecipe = n, nil end
		end
	end
	frame:Show()
	AC.Refresh()
end
function AC.Hide() if frame then frame:Hide() end end
function AC.Toggle()
	if frame and frame:IsShown() then frame:Hide() else AC.Show() end
end
function AC.IsShown() return frame and frame:IsShown() or false end

AC.OnStored = function(name, isNew)
	if isNew then out("Saved %s. Open the Cookbook with /acook to browse it anytime.", name) end
	if frame and frame:IsShown() then AC.Refresh() end
end

function AlchemistsCookbook_Binding()
	AC.Toggle()
end
BINDING_HEADER_ALCHEMISTSCOOKBOOK = "Alchemist's Cookbook"
BINDING_NAME_ALCHEMISTSCOOKBOOK_TOGGLE = "Open / close the Cookbook"

---------------------------------------------------------------------------
-- Minimap button (self-contained, no libraries)
---------------------------------------------------------------------------

local button
local SQUARE = { SQUARE = true, CORNER_TOPLEFT = true, CORNER_TOPRIGHT = true, CORNER_BOTTOMLEFT = true, CORNER_BOTTOMRIGHT = true }

local function placeButton()
	if not (button and Minimap) then return end
	local a = math.rad(db.minimap.angle or 200)
	local x, y = math.cos(a), math.sin(a)
	local w = (Minimap:GetWidth() or 140) / 2 + 5
	local h = (Minimap:GetHeight() or 140) / 2 + 5
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	if SQUARE[shape] then
		local diag = math.sqrt(2 * w * w) - 10
		x = math.max(-w, math.min(x * diag, w))
		y = math.max(-h, math.min(y * diag, h))
	else
		x, y = x * w, y * h
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function dragUpdate()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	db.minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
	placeButton()
end

local function showButtonTooltip(self)
	if not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(AC.NAME)
	local names = AC.ProfessionNames()
	GameTooltip:AddDoubleLine("Saved:", #names > 0 and table.concat(names, ", ") or "none yet", 1, 0.82, 0, 1, 1, 1)
	local c = AC.CastText()
	if c then GameTooltip:AddLine(c, 0.6, 1, 0.6, true) end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: open / close the Cookbook", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Right-click or shift-click: settings", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Drag: move button   /acook: commands", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

-- Trade_Alchemy (FileDataID 136240) and INV_Misc_Book_09 (133741) were both
-- checked present in the Forever 1.60.1 client data.
AC.ICON = 136240
AC.ICON_FALLBACK = 133741
function AC.SetButtonIcon(icon)
	local set = icon:SetTexture(AC.ICON)
	if set ~= false and icon:GetTexture() then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		return "alchemy"
	end
	icon:SetTexture(AC.ICON_FALLBACK)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return "fallback"
end

local function createButton()
	if button or not Minimap then return end
	button = CreateFrame("Button", "AlchemistsCookbookMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	AC.SetButtonIcon(icon)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	button:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" or mouse == "MiddleButton" or (IsShiftKeyDown and IsShiftKeyDown()) then
			AC.OpenOptions()
		else
			AC.Toggle()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", dragUpdate)
		hideTooltip()
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		placeButton()
	end)
	button:SetScript("OnEnter", showButtonTooltip)
	button:SetScript("OnLeave", hideTooltip)
	placeButton()
	if db.minimap.hide then button:Hide() else button:Show() end
end
AC.CreateButton = createButton

function AC.SetMinimapShown(show)
	db.minimap.hide = not show
	if button then if db.minimap.hide then button:Hide() else button:Show() end end
end

---------------------------------------------------------------------------
-- Settings: scale and position
---------------------------------------------------------------------------

function AC.SetScale(v)
	v = tonumber(v)
	if not v then return nil end
	if v > 3 then v = v / 100 end -- "/acook scale 90" means 90%
	v = math.max(SCALE_MIN, math.min(SCALE_MAX, floor(v * 100 + 0.5) / 100))
	db.scale = v
	if frame then frame:SetScale(v) end
	return v
end

function AC.ResetPosition()
	db.pos = nil
	db.scale = 1
	AC.ApplyLayout()
	out("Window moved back to the middle of the screen at 100%% size.")
end

---------------------------------------------------------------------------
-- Settings page: Esc > Options > AddOns > Alchemist's Cookbook  (/acook options)
-- Same approach as Grey Dump 1.0.2: a canvas-layout category through the
-- Settings API, InterfaceOptions_AddCategory only as a fallback.
---------------------------------------------------------------------------

local panel, category, pui

local function buildPanel()
	local p = CreateFrame("Frame", "AlchemistsCookbookOptionsPanel")
	p:Hide()
	pui = {}
	AC._pui = pui -- tests
	local L = 16
	local title = label(p, "GameFontNormalLarge", AC.NAME)
	title:SetPoint("TOPLEFT", p, "TOPLEFT", L, -16)
	local ver = label(p, "GameFontHighlightSmall", "v" .. AC.VERSION)
	ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
	local sub = label(p, "GameFontHighlightSmall",
		"Browse your professions' recipes without opening the profession window, so a repeat craft keeps going. "
		.. "Open each profession once the normal way so the Cookbook can save it.", 560)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

	local open = pushButton(p, "Open Cookbook", 140, function() AC.Show() end)
	open:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
	pui.open = open

	local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
	cb:SetSize(26, 26)
	cb:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -2, -14)
	local cbl = label(cb, "GameFontHighlight", "Show minimap button")
	cbl:SetPoint("LEFT", cb, "RIGHT", 2, 1)
	cb:SetScript("OnClick", function(self) AC.SetMinimapShown(self:GetChecked() and true or false) AC.RefreshPanel() end)
	pui.minimap = cb

	local sl = label(p, "GameFontHighlight", "Window size:")
	sl:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 4, -16)
	local minus = pushButton(p, "-", 26, function() AC.SetScale((db.scale or 1) - SCALE_STEP) AC.RefreshPanel() end)
	minus:SetPoint("LEFT", sl, "RIGHT", 10, 0)
	local val = label(p, "GameFontHighlight", "", 50)
	val:SetPoint("LEFT", minus, "RIGHT", 8, 0)
	val:SetJustifyH("CENTER")
	local plus = pushButton(p, "+", 26, function() AC.SetScale((db.scale or 1) + SCALE_STEP) AC.RefreshPanel() end)
	plus:SetPoint("LEFT", val, "RIGHT", 8, 0)
	pui.minus, pui.plus, pui.scale = minus, plus, val

	local reset = pushButton(p, "Reset window position", 180, function() AC.ResetPosition() AC.RefreshPanel() end)
	reset:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", -4, -16)
	pui.reset = reset

	local saved = label(p, "GameFontHighlightSmall", "", 560)
	saved:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 4, -18)
	pui.saved = saved

	local note = label(p, "GameFontDisableSmall",
		"Keybind: Esc > Options > Keybindings > AddOns > Alchemist's Cookbook. Commands: /acook help", 560)
	note:SetPoint("TOPLEFT", saved, "BOTTOMLEFT", 0, -14)

	p:SetScript("OnShow", function() AC.RefreshPanel() end)
	return p
end

function AC.RefreshPanel()
	if not (pui and db) then return end
	pui.minimap:SetChecked(not db.minimap.hide)
	pui.scale:SetText(format("%d%%", floor((db.scale or 1) * 100 + 0.5)))
	if (db.scale or 1) <= SCALE_MIN + 0.001 then pui.minus:Disable() else pui.minus:Enable() end
	if (db.scale or 1) >= SCALE_MAX - 0.001 then pui.plus:Disable() else pui.plus:Enable() end
	local lines = {}
	for _, n in ipairs(AC.ProfessionNames()) do
		local pr = cdb.professions[n]
		lines[#lines + 1] = format("%s (%d recipes, %d/%d)", n, #pr.recipes, pr.rank or 0, pr.maxRank or 0)
	end
	pui.saved:SetText("Saved on this character: " .. (#lines > 0 and table.concat(lines, ", ") or "nothing yet"))
end

function AC.RegisterPanel()
	if panel or not CreateFrame then return category end
	panel = buildPanel()
	panel.name = AC.NAME
	panel.OnCommit = function() end
	panel.OnDefault = function() AC.SetMinimapShown(true) AC.ResetPosition() end
	panel.OnRefresh = function() AC.RefreshPanel() end
	panel.okay, panel.default, panel.refresh = panel.OnCommit, panel.OnDefault, panel.OnRefresh
	AC.panel = panel
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
		if ok and cat then
			pcall(Settings.RegisterAddOnCategory, cat)
			category = cat
			AC.panelAPI = "Settings"
		end
	end
	if not category and InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
		AC.panelAPI = "InterfaceOptions"
	end
	AC.category = category
	return category
end

function AC.OpenOptions()
	if not db then return false end
	if not panel then AC.RegisterPanel() end
	if inCombat() then
		out("The settings page can't open in combat. Try again after the fight (or Esc > Options > AddOns > Alchemist's Cookbook).")
		return false
	end
	if category and Settings and Settings.OpenToCategory then
		local id = (category.GetID and category:GetID()) or category.ID
		if pcall(Settings.OpenToCategory, id) then return true end
	end
	if InterfaceOptionsFrame_OpenToCategory and panel then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
		return true
	end
	out("Couldn't open the settings page. Find it under Esc > Options > AddOns > Alchemist's Cookbook.")
	return false
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function help()
	out("v%s. Commands (/acook or /cookbook):", AC.VERSION)
	out("  /acook  - open or close the Cookbook")
	out("  /acook <profession>  - open it on that profession, e.g. /acook black")
	out("  /acook list  - professions saved on this character")
	out("  /acook options  - settings page (minimap button, size, position)")
	out("  /acook minimap  - show or hide the minimap button")
	out("  /acook scale <60-150>  - window size in percent")
	out("  /acook reset  - move the window back to the middle")
	out("  /acook forget <profession>  - delete that saved list")
	out("Open each profession once the normal way so it gets saved. Keybind: Game > Keybindings > AddOns > Alchemist's Cookbook.")
end

local function findProf(text)
	text = (text or ""):lower()
	if text == "" then return nil end
	for _, n in ipairs(AC.ProfessionNames()) do if n:lower() == text then return n end end
	for _, n in ipairs(AC.ProfessionNames()) do if n:lower():find(text, 1, true) == 1 then return n end end
end

function AC.Slash(msg)
	msg = msg or ""
	local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "toggle" then
		AC.Toggle()
	elseif cmd == "help" or cmd == "?" then
		help()
	elseif cmd == "show" or cmd == "open" then
		AC.Show(rest ~= "" and rest or nil)
	elseif cmd == "hide" or cmd == "close" then
		AC.Hide()
	elseif cmd == "options" or cmd == "config" or cmd == "settings" then
		AC.OpenOptions()
	elseif cmd == "minimap" then
		AC.SetMinimapShown(db.minimap.hide)
		out("Minimap button %s.", db.minimap.hide and "hidden" or "shown")
	elseif cmd == "scale" or cmd == "size" then
		local v = AC.SetScale(rest)
		if v then out("Window size set to %d%%.", floor(v * 100 + 0.5)) else out("Use /acook scale 60 to 150 (percent).") end
	elseif cmd == "reset" then
		AC.ResetPosition()
	elseif cmd == "list" then
		local names = AC.ProfessionNames()
		if #names == 0 then out("Nothing saved yet. Open each profession once and it will be saved.") end
		for _, n in ipairs(names) do
			local p = cdb.professions[n]
			out("  %s: %d recipes, skill %d/%d", n, #p.recipes, p.rank or 0, p.maxRank or 0)
		end
	elseif cmd == "forget" then
		local n = findProf(rest)
		if not n then out("No saved profession called %q. /acook list shows them.", rest) return end
		cdb.professions[n] = nil
		cdb.collapsed[n] = nil
		if selectedProf == n then selectedProf, selectedRecipe = nil, nil end
		out("Forgot %s. Open it again to re-save it.", n)
		AC.Refresh()
	elseif findProf(cmd .. (rest ~= "" and (" " .. rest) or "")) then
		AC.Show(findProf(cmd .. (rest ~= "" and (" " .. rest) or "")))
	else
		out("Unknown command %q.", cmd)
		help()
	end
	if AC.RefreshPanel then AC.RefreshPanel() end
end

SLASH_ALCHEMISTSCOOKBOOK1 = "/acook"
SLASH_ALCHEMISTSCOOKBOOK2 = "/cookbook"
if SlashCmdList then SlashCmdList.ALCHEMISTSCOOKBOOK = function(msg) AC.Slash(msg) end end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local TRADE_EVENTS = {
	TRADE_SKILL_SHOW = true, TRADE_SKILL_DATA_SOURCE_CHANGED = true,
	TRADE_SKILL_LIST_UPDATE = false, TRADE_SKILL_UPDATE = false, NEW_RECIPE_LEARNED = false,
}
local CRAFT_EVENTS = { CRAFT_SHOW = true, CRAFT_UPDATE = false }
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }
local CHAT_EVENTS = { "CHAT_MSG_LOOT", "CHAT_MSG_TRADESKILLS" }

if CreateFrame then
	local ev = CreateFrame("Frame")
	AC._ev = ev
	ev:RegisterEvent("ADDON_LOADED")
	ev:RegisterEvent("PLAYER_LOGIN")
	-- Some of these only exist on some clients; registering an unknown event errors, so pcall.
	for e in pairs(TRADE_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
	for e in pairs(CRAFT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
	for _, e in ipairs(CAST_EVENTS) do
		if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, e, "player") else pcall(ev.RegisterEvent, ev, e) end
	end
	for _, e in ipairs(CHAT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
	ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
		if event == "ADDON_LOADED" and a1 == ADDON then
			AlchemistsCookbookDB, AlchemistsCookbookCharDB = AC.InitDB(AlchemistsCookbookDB, AlchemistsCookbookCharDB)
			AC.RegisterPanel()
		elseif event == "PLAYER_LOGIN" then
			if not db then AlchemistsCookbookDB, AlchemistsCookbookCharDB = AC.InitDB(AlchemistsCookbookDB, AlchemistsCookbookCharDB) end
			createButton()
			AC.RegisterPanel()
		elseif not db then
			return
		elseif TRADE_EVENTS[event] ~= nil then
			AC.RequestScan("trade", TRADE_EVENTS[event])
		elseif CRAFT_EVENTS[event] ~= nil then
			AC.RequestScan("craft", CRAFT_EVENTS[event])
		elseif event:find("^UNIT_SPELLCAST_") then
			AC.OnCastEvent(event, a1, a2, a3)
		elseif event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_TRADESKILLS" then
			AC.OnChatCreate(a1)
		end
	end)
end
