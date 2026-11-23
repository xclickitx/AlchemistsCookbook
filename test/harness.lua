-- Mock WoW API harness for Alchemist's Cookbook (modes: modern / legacy options / classic API)
local MODE = AC_MODE or "modern"
NO_SHOPPING_TEMPLATE = (MODE == "legacy")  -- exercise the fallback header
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1] = m end }
local function clearChat() for i=#chat,1,-1 do chat[i]=nil end end
local function chatHas(p) for _,m in ipairs(chat) do if m:find(p, 1, true) then return true end end return false end
local fails, passes = 0, 0
local function ok(c, name) if c then passes = passes + 1 else fails = fails + 1 print("FAIL: "..name) end end

-- items: id -> name
local ITEMS = { [2770]="Copper Ore", [2771]="Tin Ore", [2840]="Copper Bar", [3576]="Tin Bar", [2841]="Bronze Bar",
  [2880]="Weak Flux", [2862]="Rough Sharpening Stone", [2835]="Rough Stone", [6214]="Heavy Copper Maul",
  [3491]="Heavy Bronze Mace", [3490]="Deadly Bronze Poniard", [2901]="Mining Pick", [7001]="Shiver Blade",
  [7002]="Worn Buckler", [7003]="Copper Band", [7004]="Silver Ring", [7005]="Bronze Shield", [7006]="Bronze Greatsword" }
local EQUIPLOC = { [6214]="INVTYPE_2HWEAPON", [3491]="INVTYPE_WEAPON", [3490]="INVTYPE_WEAPON", [2901]="INVTYPE_WEAPON",
  [7001]="INVTYPE_WEAPON", [7002]="INVTYPE_SHIELD", [7003]="INVTYPE_FINGER", [7004]="INVTYPE_FINGER", [7005]="INVTYPE_SHIELD", [7006]="INVTYPE_2HWEAPON" }
local uncached = { [2880] = true }
local bags = { [2770]=23, [2840]=3, [3576]=4, [2835]=5, [2880]=0 }
local bank = { [2840]=2, [2880]=1 }
local function link(id) return "|cffffffff|Hitem:"..id.."::::::::|h["..ITEMS[id].."]|h|r" end
local byName = {} for id, n in pairs(ITEMS) do byName[n] = id end
C_Item = {
  GetItemInfo = function(id)
    if type(id) == "string" then id = byName[id] end
    if not id or uncached[id] or not ITEMS[id] then return nil end
    return ITEMS[id], link(id), 1, 1, 1, "", "", 20, "", 0, 100 + id
  end,
  GetItemIconByID = function(id) return 100 + id end,
  GetItemCount = function(id, inclBank)
    if type(id) == "string" then id = byName[id] end
    local b = bags[id] or 0
    if inclBank then b = b + (bank[id] or 0) end
    return b
  end,
  RequestLoadItemDataByID = function() end,
  GetItemInfoInstant = function(item)
    local id = tonumber(item) or (type(item) == "string" and tonumber(item:match("item:(%d+)")))
    if not id then return nil end
    return id, "Misc", "", EQUIPLOC[id] or "INVTYPE_NON_EQUIP_IGNORE", 100 + id, 0, 0
  end,
}
-- what you're wearing: Shiver Blade in the main hand; Mining Pick sits in your bags
local EQUIPPED_INV = { [16] = link(7001) }
bags[2901] = 1
function GetInventoryItemLink(unit, slot) if unit == "player" then return EQUIPPED_INV[slot] end end
local shiftDown, alwaysCompare = false, false
function IsModifiedClick(k) return k == "COMPAREITEMS" and shiftDown end
function GetCVarBool(k) if k == "alwaysCompareItems" then return alwaysCompare end end
function GetScreenWidth() return 1920 end
Enum = { TradeskillRelativeDifficulty = { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 }, CraftingReagentType = { Modifying = 0, Basic = 1, Finishing = 2, Automatic = 3 } }

-- Protected / state-changing calls must never happen.
local forbidden = {}
local function forbid(name) return function() forbidden[#forbidden+1] = name end end

-- Modern C_TradeSkillUI with switchable open profession.
local PROFS = {
  Mining = { base = { professionName = "Mining", professionID = 186, skillLevel = 0, maxSkillLevel = 0 },
             child = { professionName = "Classic Mining", parentProfessionName = "Mining", professionID = 2572, parentProfessionID = 186, skillLevel = 50, maxSkillLevel = 75 },
             recipes = {
               [2657] = { info = { name = "Smelt Copper", learned = true, relativeDifficulty = 0, categoryID = 10, icon = 1 },
                          sch = { quantityMin = 1, quantityMax = 1, outputItemID = 2840, reagentSlotSchematics = {
                            { reagents = {{ itemID = 2770 }}, quantityRequired = 1, required = true, reagentType = 1 } } },
                          req = { { name = "Forge", met = true } } },
               [2659] = { info = { name = "Smelt Bronze", learned = true, relativeDifficulty = 1, categoryID = 10, icon = 2 },
                          sch = { quantityMin = 2, quantityMax = 2, outputItemID = 2841, reagentSlotSchematics = {
                            { reagents = {{ itemID = 2840 }}, quantityRequired = 1, required = true, reagentType = 1 },
                            { reagents = {{ itemID = 3576 }}, quantityRequired = 1, required = true, reagentType = 1 },
                            { reagents = {{ itemID = 9999 }}, quantityRequired = 1, required = false, reagentType = 0 } } } },
               [3304] = { info = { name = "Smelt Tin", learned = false, relativeDifficulty = 0, categoryID = 10 } },
               [9000] = { info = { name = "Dummy", learned = true, isDummyRecipe = true, categoryID = 10 } },
             } },
  Blacksmithing = { base = { professionName = "Blacksmithing", professionID = 164, skillLevel = 80, maxSkillLevel = 150 },
             child = {},
             recipes = {
               [2660] = { info = { name = "Rough Sharpening Stone", learned = true, relativeDifficulty = 3, categoryID = 20, icon = 3 },
                          sch = { quantityMin = 1, quantityMax = 1, outputItemID = 2862, reagentSlotSchematics = {
                            { reagents = {{ itemID = 2835 }}, quantityRequired = 1, required = true, reagentType = 1 } } } },
               [7408] = { info = { name = "Heavy Copper Maul", learned = true, relativeDifficulty = 2, categoryID = 21, icon = 4 },
                          sch = { quantityMin = 1, quantityMax = 1, outputItemID = 6214, reagentSlotSchematics = {
                            { reagents = {{ itemID = 2840 }}, quantityRequired = 12, required = true, reagentType = 1 },
                            { reagents = {{ itemID = 2880 }}, quantityRequired = 2, required = true, reagentType = 1 } } },
                          req = { { name = "Anvil", met = false } } },
             } },
}
local CATS = { [10] = { name = "Smelting" }, [20] = { name = "Materials" }, [21] = { name = "Weapons" } }
local open, linked, changing, remaining = nil, false, false, 0
if MODE ~= "classic" then
  C_TradeSkillUI = {
    GetBaseProfessionInfo = function() return open and PROFS[open].base or {} end,
    GetChildProfessionInfo = function() return open and PROFS[open].child or {} end,
    GetAllRecipeIDs = function()
      local t = {} if open then for id in pairs(PROFS[open].recipes) do t[#t+1] = id end end table.sort(t) return t end,
    GetRecipeInfo = function(id) local r = open and PROFS[open].recipes[id]; if r then local i = {} for k,v in pairs(r.info) do i[k]=v end i.recipeID = id return i end end,
    GetRecipeSchematic = function(id) local r = open and PROFS[open].recipes[id]; return r and r.sch end,
    GetRecipeOutputItemData = function(id) local r = open and PROFS[open].recipes[id]; if r and r.sch then return { itemID = r.sch.outputItemID, hyperlink = link(r.sch.outputItemID), icon = 5 } end end,
    GetRecipeRequirements = function(id) local r = open and PROFS[open].recipes[id]; return r and r.req or {} end,
    GetCategoryInfo = function(id) return CATS[id] end,
    IsTradeSkillLinked = function() return linked end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
    IsDataSourceChanging = function() return changing end,
    GetRemainingRecasts = function() return remaining end,
    CraftRecipe = forbid("CraftRecipe"), OpenTradeSkill = forbid("OpenTradeSkill"), CloseTradeSkill = forbid("CloseTradeSkill"),
    OpenRecipe = forbid("OpenRecipe"), SetRecipeTracked = forbid("SetRecipeTracked"), SetShowLearned = forbid("SetShowLearned"),
  }
else
  -- classic-era globals
  local list = {
    { "Smelting", "header" }, { "Smelt Copper", "optimal", 2770, 1 }, { "Smelt Bronze", "medium", 2840, 1, 3576, 1, made = 2 },
  }
  function GetTradeSkillLine() return open and "Mining" or "UNKNOWN", 50, 75 end
  function GetNumTradeSkills() return open and #list or 0 end
  function GetTradeSkillInfo(i) local e = list[i]; return e[1], e[2], 0, true end
  function GetTradeSkillIcon(i) return 10 + i end
  function GetTradeSkillNumMade(i) local m = list[i].made or 1 return m, m end
  function GetTradeSkillItemLink(i) return i == 2 and link(2840) or link(2841) end
  function GetTradeSkillNumReagents(i) return (#list[i] - 2) / 2 end
  function GetTradeSkillReagentInfo(i, j) local id = list[i][1 + j*2]; return ITEMS[id], 1, list[i][2 + j*2], bags[id] or 0 end
  function GetTradeSkillReagentItemLink(i, j) return link(list[i][1 + j*2]) end
  function GetTradeSkillTools(i) return "Forge", true end
  function DoTradeSkill() forbidden[#forbidden+1] = "DoTradeSkill" end
  function GetNumCrafts() return 1 end
  function GetCraftDisplaySkillLine() return "Enchanting", 30, 75 end
  function GetCraftInfo(i) return "Enchant Bracer - Minor Health", "", "easy", 0, true end
  function GetCraftIcon() return 9 end
  function GetCraftNumReagents() return 1 end
  function GetCraftReagentInfo() return "Copper Ore", 1, 2, 23 end
  function GetCraftReagentItemLink() return link(2770) end
  function DoCraft() forbidden[#forbidden+1] = "DoCraft" end
end
C_Spell = { GetSpellName = function(id) for _, p in pairs(PROFS) do if p.recipes[id] then return p.recipes[id].info.name end end end }
local secretIDs = {}
function issecretvalue(v) return secretIDs[v] == true end
function CastSpellByName() forbidden[#forbidden+1] = "CastSpellByName" end

local inCombat = false
function InCombatLockdown() return inCombat end
local timers = {}
C_Timer = { After = function(s, f) timers[#timers+1] = { s = s, f = f } end }
-- Runs short timers (scans, refreshes); long ones (the 8s stale check) only when all == true.
local function runTimers(all)
  local n = 0
  while n < 200 do
    local idx
    for i, t in ipairs(timers) do if all or t.s < 5 then idx = i break end end
    if not idx then break end
    local t = table.remove(timers, idx); t.f(); n = n + 1
  end
end
local function pendingLong() local c = 0 for _, t in ipairs(timers) do if t.s >= 5 then c = c + 1 end end return c end
local now = 100
function GetTime() return now end
time = os.time
date = os.date
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
local frames = {}
local textures = {}
TEMPLATES_USED = {}
local tipLink
local function mkFrame(ftype, name, parent, template)
  local f = { scripts = {}, events = {}, shown = true, ftype = ftype, name = name, template = template, enabled = true }
  if template then TEMPLATES_USED[template] = true end
  setmetatable(f, { __index = function(t, k) return function() end end })
  f.RegisterEvent = function(self, e) self.events[e] = true end
  f.RegisterUnitEvent = function(self, e, u) self.events[e] = u end
  f.UnregisterEvent = function(self, e) self.events[e] = nil end
  f.SetScript = function(self, k, fn) self.scripts[k] = fn end
  f.GetScript = function(self, k) return self.scripts[k] end
  f.Show = function(self) local was = self.shown self.shown = true if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
  f.Hide = function(self) local was = self.shown self.shown = false if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
  f.IsShown = function(self) return self.shown end
  f.SetText = function(self, t) self.text = t end
  f.GetText = function(self) return rawget(self, "text") end
  f.SetChecked = function(self, v) self.checked = v and true or false end
  f.GetChecked = function(self) return rawget(self, "checked") or false end
  f.Enable = function(self) self.enabled = true end
  f.Disable = function(self) self.enabled = false end
  f.IsEnabled = function(self) return self.enabled end
  f.SetScale = function(self, s) self.scale = s end
  f.SetPoint = function(self, ...) self.point = {...} end
  f.GetPoint = function(self) if self.point then return self.point[1], nil, self.point[3], self.point[4], self.point[5] end end
  f.ClearFocus = function(self) self.focus = false end
  f.CreateFontString = function() return mkFrame("FontString") end
  f.CreateTexture = function()
    local t = mkFrame("Texture")
    t.SetTexture = function(self, tex) self.tex = tex return true end
    t.GetTexture = function(self) return self.tex end
    textures[#textures+1] = t
    return t
  end
  if ftype == "GameTooltip" then
    if template == "ShoppingTooltipTemplate" and NO_SHOPPING_TEMPLATE then error("Couldn't find inherited node") end
    f.SetHyperlink = function(self, l) tipLink = l; self.link = l; self.invSlot = nil end
    f.SetItemByID = function(self, id) tipLink = "item:"..id; self.link = tipLink; self.invSlot = nil end
    f.SetInventoryItem = function(self, unit, slot) self.invSlot = slot; self.link = EQUIPPED_INV[slot]; return self.link ~= nil end
    f.GetName = function() return name end
    f.priceLines = {}
    f.ClearLines = function(self)
      self.priceLines = {}
      if name then
        local i = 1
        while _G[name.."TextLeft"..i] or _G[name.."TextRight"..i] do
          _G[name.."TextLeft"..i] = nil
          _G[name.."TextRight"..i] = nil
          i = i + 1
        end
      end
    end
    f.AddDoubleLine = function(self, left, right)
      self.priceLines = self.priceLines or {}
      self.priceLines[#self.priceLines+1] = left
      if name then
        local i = #self.priceLines
        _G[name.."TextLeft"..i] = { GetText = function() return left end, text = left }
        _G[name.."TextRight"..i] = { GetText = function() return right end, text = right }
      end
    end
    f.AddLine = function(self, text) self:AddDoubleLine(text, nil) end
    f.NumLines = function(self)
      local extra = self.priceLines and #self.priceLines or 0
      if extra > 0 then return extra end
      return rawget(self, "link") and 3 or 0
    end
    f.SetOwner = function(self, o, a)
      self.owner, self.anchor = o, a
      self.link = nil
      if self.ClearLines then self:ClearLines() end
    end
    f.GetWidth = function() return 200 end
    f.GetRight = function(self) return rawget(self, "right") or 600 end
    f.GetLeft = function(self) return (rawget(self, "right") or 600) - 200 end
    if template == "ShoppingTooltipTemplate" then f.CompareHeader = mkFrame("Frame"); f.CompareHeader.Label = mkFrame("FontString") end
  end
  frames[#frames+1] = f
  if name then _G[name] = f end
  return f
end
function CreateFrame(...) return mkFrame(...) end
UIParent = mkFrame("Frame", "UIParent")
local settingsCat, openedID, legacyOpens = nil, nil, 0
if MODE ~= "legacy" then
  Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) return { frame = frame, name = name, ID = 88, GetID = function(self) return self.ID end } end,
    RegisterAddOnCategory = function(c) settingsCat = c end,
    OpenToCategory = function(id) openedID = id; if settingsCat and id == settingsCat.ID then settingsCat.frame:Show() end end,
  }
else
  function InterfaceOptions_AddCategory(p) settingsCat = { frame = p } end
  function InterfaceOptionsFrame_OpenToCategory(p) legacyOpens = legacyOpens + 1; p:Show() end
end
GameTooltip = setmetatable({ SetHyperlink = function(self, l) tipLink = l end, SetItemByID = function(self, id) tipLink = "item:"..id end }, { __index = function() return function() end end })
Minimap = mkFrame(); Minimap.GetWidth = function() return 140 end; Minimap.GetHeight = function() return 140 end

local chunk = assert(loadfile("../AlchemistsCookbook/AlchemistsCookbook.lua"))
chunk("AlchemistsCookbook")
local AC = AlchemistsCookbook
local ev = AC._ev
local function fire(e, ...) ev.scripts.OnEvent(ev, e, ...) end
fire("ADDON_LOADED", "AlchemistsCookbook"); fire("PLAYER_LOGIN")
ok(AC.VERSION == "1.0.5", "version 1.0.5")

-- Auctionator prices (1.0.5): helpers work with or without it. No settings.
ok(AC.AuctionatorAPI() == nil, "Auctionator absent: API nil")
ok(AC.MoneyText(48) == "48c" and AC.MoneyText(150) == "1s 50c" and AC.MoneyText(10000) == "1g" and AC.MoneyText(10050) == "1g 50c", "money fallback")
do
  local copperR = { name = "Smelt Copper", itemID = 2840, link = link(2840), numMin = 1, reagents = { { id = 2770, count = 1 } } }
  local enchantR = { name = "Enchant Bracer", reagents = { { id = 2770, count = 2 } }, numMin = 1 }
  ok(AC.CraftPriceText(copperR) == nil and select(3, AC.CraftCost(copperR)) == false, "Auctionator absent: no price text")

  local prices, vendor = {}, {}
  Auctionator = { API = { v1 = {
    GetAuctionPriceByItemID = function(caller, id)
      if caller ~= "Alchemist's Cookbook" then error("bad caller") end
      return prices[id]
    end,
    GetAuctionPriceByItemLink = function(caller, itemLink)
      if caller ~= "Alchemist's Cookbook" then error("bad caller") end
      local id = tonumber(itemLink:match("item:(%d+)"))
      return id and prices[id]
    end,
    GetVendorPriceByItemID = function(caller, id)
      if caller ~= "Alchemist's Cookbook" then error("bad caller") end
      return vendor[id]
    end,
  } } }
  ok(AC.AuctionatorAPI() ~= nil, "Auctionator present: API found")

  vendor[2770], prices[2840] = 10, 20
  local cost, inc, ready = AC.CraftCost(copperR)
  ok(ready and cost == 10 and inc == false, "full prices: cost uses vendor")
  ok(AC.CraftProfit(copperR, cost) == 9, "full prices: profit 20*0.95-10 = 9")
  local text = AC.CraftPriceText(copperR)
  ok(text == "To Craft: 10c\nProfit: 9c", "full prices text: "..tostring(text))

  vendor[2770], prices[2770], prices[2840] = 100, 10, 20
  ok(AC.CraftCost(copperR) == 10, "vendor > 5x AH uses auction price")

  vendor[2770], prices[2770], prices[2840] = nil, nil, 20
  cost, inc = AC.CraftCost(copperR)
  ok(cost == 0 and inc == true, "missing reagent price: cost 0 incomplete")
  text = AC.CraftPriceText(copperR)
  ok(text and text:find("To Craft: 0c (incomplete)", 1, true) and text:find("Profit:", 1, true), "incomplete marker: "..tostring(text))

  vendor[2770], prices[2770], prices[2840] = nil, 50, 40
  text = AC.CraftPriceText(copperR)
  ok(text and text:find("To Craft: 50c", 1, true) and text:find("|cffff4040-12c|r", 1, true), "loss in red: "..tostring(text))

  prices[2770] = 10
  text = AC.CraftPriceText(enchantR)
  ok(text == "To Craft: 20c", "no-output recipe: cost only, no profit: "..tostring(text))

  Auctionator.API.v1.GetAuctionPriceByItemID = function() error("boom") end
  Auctionator.API.v1.GetAuctionPriceByItemLink = function() error("boom") end
  Auctionator.API.v1.GetVendorPriceByItemID = function() error("boom") end
  ok(AC.CraftPriceText(copperR):find("(incomplete)", 1, true) and AC.CraftProfit(copperR, 0) == nil, "API errors are swallowed")

  Auctionator = nil
  ok(AC.AuctionatorAPI() == nil and AC.CraftPriceText(copperR) == nil, "Auctionator cleared")
end

ok(AlchemistsCookbookDB.filters.skillup == false and AlchemistsCookbookDB.filters.have == false and AlchemistsCookbookDB.filters.haveBank == false, "filters default off")
ok(AlchemistsCookbookDB.scale == 1 and AlchemistsCookbookDB.minimap.hide == false, "account defaults")
ok(type(AlchemistsCookbookCharDB.professions) == "table", "per-character db")
ok(ev.events.TRADE_SKILL_SHOW and ev.events.CRAFT_SHOW and ev.events.UNIT_SPELLCAST_START == "player", "events registered (cast events unit-filtered)")
ok(SlashCmdList.ALCHEMISTSCOOKBOOK and SLASH_ALCHEMISTSCOOKBOOK1 == "/acook" and SLASH_ALCHEMISTSCOOKBOOK2 == "/cookbook", "slash commands")
ok(BINDING_HEADER_ALCHEMISTSCOOKBOOK == "Alchemist's Cookbook" and BINDING_NAME_ALCHEMISTSCOOKBOOK_TOGGLE, "binding strings")
local btn = _G.AlchemistsCookbookMinimapButton
ok(btn and btn.icon.tex == 136240, "minimap button with alchemy icon")

-- nothing saved before a window opens
ok(#AC.ProfessionNames() == 0, "empty at start")

if MODE == "classic" then
  open = "Mining"
  fire("TRADE_SKILL_SHOW"); runTimers()
  local m = AlchemistsCookbookCharDB.professions.Mining
  ok(m and #m.recipes == 2 and m.rank == 50 and m.maxRank == 75, "classic scan saved Mining")
  local bronze = m and m.recipes[2]
  ok(bronze and bronze.name == "Smelt Bronze" and bronze.numMin == 2 and #bronze.reagents == 2 and bronze.reagents[1].id == 2840 and bronze.header == "Smelting" and bronze.tools[1] == "Forge", "classic recipe details")
  ok(bronze and bronze.difficulty == "medium" and bronze.itemID == 2841, "classic difficulty + item id")
  fire("CRAFT_SHOW"); runTimers()
  local en = AlchemistsCookbookCharDB.professions.Enchanting
  ok(en and #en.recipes == 1 and en.recipes[1].reagents[1].count == 2 and en.rank == 30, "craft API scan saved Enchanting")
  ok(select(1, AC.Craftable(en.recipes[1])) == 11, "craftable from craft reagents")
  local mBefore = AlchemistsCookbookCharDB.professions.Mining
  open = nil; local e, why = AC.ScanClassicTrade(); ok(e == nil and why == "notready", "classic UNKNOWN line rejected")
  local realLine = GetTradeSkillLine
  GetTradeSkillLine = function() return "Mining", 0, 0 end
  e, why = AC.ScanClassicTrade(); ok(e == nil and why == "notready", "classic 0/0 rejected")
  GetTradeSkillLine = realLine
  ok(AlchemistsCookbookCharDB.professions.Mining == mBefore and AlchemistsCookbookCharDB.professions.UNKNOWN == nil, "classic guard keeps saved data")
  ok(#forbidden == 0, "no protected calls (classic)")
  print(("passes=%d fails=%d"):format(passes, fails))
  return fails
end

-- open Mining
open = "Mining"
fire("TRADE_SKILL_SHOW"); runTimers()
local m = AlchemistsCookbookCharDB.professions.Mining
ok(m ~= nil, "Mining saved")
ok(m and #m.recipes == 2, "only learned non-dummy recipes ("..(m and #m.recipes or -1)..")")
ok(m and m.rank == 50 and m.maxRank == 75, "rank from child skill line")
ok(chatHas("Saved Mining"), "saved message")
local copper, bronze
for _, r in ipairs(m.recipes) do if r.id == 2657 then copper = r elseif r.id == 2659 then bronze = r end end
ok(copper and copper.header == "Smelting" and copper.difficulty == "optimal" and copper.tools[1] == "Forge" and copper.itemID == 2840 and copper.link:find("Copper Bar", 1, true), "copper recipe details")
ok(bronze and bronze.numMin == 2 and #bronze.reagents == 2 and bronze.difficulty == "medium", "bronze makes 2, optional reagent skipped")
ok(bronze.reagents[1].name == "Copper Bar" and bronze.reagents[1].link and bronze.reagents[1].count == 1, "reagent name/link/count")

-- counts
ok(AC.Craftable(copper) == 23, "can smelt 23 copper")
local b, a = AC.Craftable(bronze); ok(b == 3 and a == 4, "bronze bags 3 / bank 4 (tin limits) ("..b.."/"..a..")")
local bb, ab = AC.CountItem(2840); ok(bb == 3 and ab == 5, "CountItem bags/bank")

-- linked window / data changing are not saved; empty scans never overwrite
linked = true; open = "Blacksmithing"; fire("TRADE_SKILL_SHOW"); runTimers()
ok(AlchemistsCookbookCharDB.professions.Blacksmithing == nil, "linked profession not saved")
linked = false
changing = true; fire("TRADE_SKILL_SHOW"); runTimers()
ok(AlchemistsCookbookCharDB.professions.Blacksmithing == nil, "busy data source not saved")
changing = false
fire("TRADE_SKILL_SHOW"); runTimers()
local bs = AlchemistsCookbookCharDB.professions.Blacksmithing
ok(bs and #bs.recipes == 2 and bs.rank == 80 and bs.maxRank == 150, "Blacksmithing saved, base rank")
local maul; for _, r in ipairs(bs.recipes) do if r.id == 7408 then maul = r end end
ok(maul and maul.reagents[2].name == nil, "uncached reagent has no name yet")
ok(#AC.ProfessionNames() == 2 and AC.ProfessionNames()[1] == "Blacksmithing", "two professions, sorted")
local saveMining = AlchemistsCookbookCharDB.professions.Mining
open = nil; fire("TRADE_SKILL_SHOW"); runTimers()
ok(AlchemistsCookbookCharDB.professions.Mining == saveMining, "closed/empty scan keeps saved data")
-- list-update throttle: within 5s ignored
open = "Mining"; now = 101; local calls = #timers; fire("TRADE_SKILL_LIST_UPDATE"); ok(#timers == calls, "LIST_UPDATE throttled"); now = 120
fire("TRADE_SKILL_LIST_UPDATE"); ok(#timers == calls + 1, "LIST_UPDATE rescans after 5s"); runTimers()
ok(AlchemistsCookbookCharDB.professions.Mining ~= saveMining, "rescan replaced data")

-- re-read after rescan
m = AlchemistsCookbookCharDB.professions.Mining
for _, r in ipairs(m.recipes) do if r.id == 2657 then copper = r elseif r.id == 2659 then bronze = r end end
-- search
ok(AC.Matches(bronze, "tin") and AC.Matches(bronze, "BRONZE") and not AC.Matches(copper, "tin"), "search by name + reagent, case-insensitive")
uncached[2880] = nil
ok(AC.Matches(maul, "flux") and maul.reagents[2].name == "Weak Flux", "search resolves late item names")
-- rows / collapse
local rows = AC.BuildRows("Blacksmithing", "")
ok(#rows == 4 and rows[1].header == "Materials" and rows[3].header == "Weapons", "rows with headers")
AC.ToggleHeader("Blacksmithing", "Weapons")
rows = AC.BuildRows("Blacksmithing", ""); ok(#rows == 3 and rows[3].collapsed, "collapsed header hides recipes")
rows = AC.BuildRows("Blacksmithing", "maul"); ok(#rows == 2 and rows[2].recipe == maul, "search shows collapsed matches, hides empty headers")
AC.ToggleHeader("Blacksmithing", "Weapons")

-- window
clearChat()
SlashCmdList.ALCHEMISTSCOOKBOOK("")
local F = _G.AlchemistsCookbookFrame
ok(F and F:IsShown(), "/acook opens window")
ok(UISpecialFrames[1] == "AlchemistsCookbookFrame", "Esc closes (UISpecialFrames)")
local U = AC._ui
ok(U.tabs[1]:IsShown() and U.tabs[2]:IsShown() and U.tabs[1].text == "Blacksmithing" and not U.tabs[1]:IsEnabled(), "profession tabs")
U.tabs[2].scripts.OnClick(U.tabs[2]); ok(U.rank.text == "Mining 50/75", "tab switch to Mining")
ok(AC._rows[1].header == "Smelting" and #AC._rows == 3, "Mining rows")
local copperRow; for _, r in ipairs(U.rows) do local d = rawget(r, "data") if d and d.recipe == copper then copperRow = r end end
ok(copperRow and copperRow.count.text == "[23]", "row shows craftable count")
copperRow.scripts.OnEnter(copperRow); ok(tipLink and tipLink:find("item:2840", 1, true), "row tooltip from stored link")
copperRow.scripts.OnClick(copperRow)
ok(U.reagents[1]:IsShown() and U.reagents[1].have.text:find("have 23|r / need 1", 1, true), "reagent have/need")
ok(U.dCraft.text == "You can make 23 now.", "craft-now line")
ok(U.dCost and not U.dCost:IsShown() and (not U.dCost.text or U.dCost.text == ""), "no Auctionator: price line hidden")
ok(U.dTools.text == "Requires: Forge", "tools line")
U.reagents[1].scripts.OnEnter(U.reagents[1]); ok(tipLink and tipLink:find("item:2770", 1, true), "reagent tooltip")
-- 1.0.3: our own item tooltip, comparing only with what you actually wear
do
  local tip = AlchemistsCookbookTooltip
  ok(tip and tip.ftype == "GameTooltip" and tip.template == "GameTooltipTemplate" and tip:IsShown(), "item tooltips use our own tooltip, not GameTooltip")
  ok(rawget(tip, "supportsItemComparison") == nil, "Blizzard auto-compare is not enabled on it")
  local gtUsed = 0
  local gtSet, gtItem = GameTooltip.SetHyperlink, GameTooltip.SetItemByID
  rawset(GameTooltip, "SetHyperlink", function(...) gtUsed = gtUsed + 1 return gtSet(...) end)
  rawset(GameTooltip, "SetItemByID", function(...) gtUsed = gtUsed + 1 return gtItem(...) end)
  local watcher; for _, f in ipairs(frames) do if f.events.MODIFIER_STATE_CHANGED then watcher = f end end
  ok(watcher and watcher.events.PLAYER_EQUIPMENT_CHANGED, "watches shift and gear changes")
  local function fireW(e) watcher.scripts.OnEvent(watcher, e) end
  local function C(i) return _G["AlchemistsCookbookCompareTooltip"..i] end
  local function shown(i) return C(i) ~= nil and C(i):IsShown() end
  local function pick() for i = 1, 2 do if C(i) and tostring(C(i).link):find("item:2901", 1, true) then return true end end return false end
  local owner = mkFrame("Button")
  shiftDown, alwaysCompare = false, false
  AC._tooltipFor(owner, link(3490), 3490)
  ok(tip:IsShown() and tipLink:find("item:3490", 1, true) and tip.owner == owner, "Deadly Bronze Poniard tooltip")
  ok(not shown(1) and not shown(2), "no compare without shift or always-compare")
  shiftDown = true; fireW("MODIFIER_STATE_CHANGED")
  ok(shown(1) and C(1).invSlot == 16 and C(1).link:find("item:7001", 1, true), "shift: compares with equipped main hand (Shiver Blade)")
  ok(not shown(2) and not pick(), "no Mining Pick, no second tooltip with an empty off hand")
  if NO_SHOPPING_TEMPLATE then
    ok(C(1).template == "GameTooltipTemplate" and C(1).acHeader and C(1).acHeader.text == "Equipped", "fallback Equipped header without ShoppingTooltipTemplate")
  else
    ok(C(1).template == "ShoppingTooltipTemplate" and C(1).CompareHeader.Label.text == "Equipped" and C(1).CompareHeader:IsShown(), "native Equipped header")
  end
  ok(C(1).point and C(1).point[1] == "TOPLEFT" and C(1).point[2] == tip and C(1).point[3] == "TOPRIGHT", "anchored beside the item tooltip")
  -- smelting / Mining window open makes no difference: we only read slots 16/17
  AC._tooltipFor(owner, link(3491), 3491)
  ok(shown(1) and C(1).invSlot == 16 and not shown(2) and not pick(), "Heavy Bronze Mace: only Shiver Blade")
  EQUIPPED_INV[17] = link(7002); fireW("PLAYER_EQUIPMENT_CHANGED")
  ok(shown(1) and shown(2) and C(2).invSlot == 17 and C(2).link:find("item:7002", 1, true) and C(2).point[2] == C(1), "one-hander: main hand and off hand")
  AC._tooltipFor(owner, link(6214), 6214)
  ok(shown(1) and shown(2) and C(1).invSlot == 16 and C(2).invSlot == 17, "two-hander: both hands")
  AC._tooltipFor(owner, nil, 7005)
  ok(shown(1) and C(1).invSlot == 17 and not shown(2), "shield: off hand only")
  EQUIPPED_INV[11] = link(7003)
  AC._tooltipFor(owner, link(7004), 7004)
  ok(shown(1) and C(1).invSlot == 11 and not shown(2), "ring: the one ring slot in use")
  EQUIPPED_INV[12] = link(7004); fireW("PLAYER_EQUIPMENT_CHANGED")
  ok(shown(1) and shown(2) and C(1).invSlot == 11 and C(2).invSlot == 12, "ring: both ring slots")
  AC._tooltipFor(owner, link(2840), 2840)
  ok(not shown(1) and not shown(2), "non-equippable item: no compare")
  AC._tooltipFor(owner, "|cff71d5ff|Hspell:2657|h[Smelt Copper]|h|r", nil)
  ok(tip:IsShown() and not shown(1), "spell link: no compare")
  EQUIPPED_INV[16] = link(7006); AC._tooltipFor(owner, link(3491), 3491)
  ok(C(1).link:find("item:7006", 1, true), "follows gear swaps")
  EQUIPPED_INV[16] = link(7001)
  shiftDown = false; fireW("MODIFIER_STATE_CHANGED")
  ok(not shown(1) and not shown(2), "releasing shift hides the compare")
  alwaysCompare = true; AC._tooltipFor(owner, link(3491), 3491)
  ok(shown(1) and shown(2), "always-compare setting shows it without shift")
  tip.right = 1850; AC.UpdateCompare()
  ok(C(1).point[1] == "TOPRIGHT" and C(1).point[3] == "TOPLEFT" and C(2).point[2] == C(1), "flips left at the screen edge")
  tip.right = nil
  secretIDs[EQUIPPED_INV[17]] = true; AC.UpdateCompare()
  ok(shown(1) and not shown(2), "secret links are skipped")
  secretIDs[EQUIPPED_INV[17]] = nil
  local fb = #forbidden
  inCombat = true; AC._tooltipFor(owner, link(3491), 3491); ok(shown(1) and #forbidden == fb, "works in combat, no protected calls"); inCombat = false
  U.reagents[1].scripts.OnLeave(U.reagents[1])
  ok(not tip:IsShown() and not shown(1) and not shown(2), "leaving hides tooltip and compares")
  ok(gtUsed == 0 and rawget(_G, "ShoppingTooltip1") == nil, "never touched GameTooltip or ShoppingTooltip1/2")
  rawset(GameTooltip, "SetHyperlink", gtSet); rawset(GameTooltip, "SetItemByID", gtItem)
  alwaysCompare = false; EQUIPPED_INV[17], EQUIPPED_INV[11], EQUIPPED_INV[12] = nil, nil, nil
  -- No Auctionator at this point: hovering must not error or add price lines
  AC._tooltipFor(owner, link(2840), 2840, 1)
  ok(not AC.TooltipHasAuctionatorPrices(tip), "no Auctionator: item tooltip has no Vendor/Auction lines")
end

-- Auctionator prices on Cookbook item tooltips (1.0.5)
do
  local tip = AlchemistsCookbookTooltip
  local owner = mkFrame("Button")
  local calls = {}
  Auctionator = {
    API = { v1 = {
      GetAuctionPriceByItemID = function(_, id) return ({[2770]=53,[2840]=40})[id] end,
      GetAuctionPriceByItemLink = function(_, itemLink)
        local id = tonumber(itemLink:match("item:(%d+)"))
        return id and ({[2770]=53,[2840]=40})[id]
      end,
      GetVendorPriceByItemID = function() return nil end,
    } },
    Tooltip = {
      ShowTipWithPricing = function(frame, itemLink, itemCount)
        calls[#calls+1] = { tip = frame, link = itemLink, count = itemCount }
        frame:AddDoubleLine("Vendor", "40c")
        local auc = "53c"
        if itemCount and itemCount > 1 then auc = "53c / 54c" end
        frame:AddDoubleLine("Auction", auc)
      end,
    },
  }
  AC._tooltipFor(owner, link(2840), 2840, 1)
  ok(#calls == 1 and calls[1].tip == tip and calls[1].count == 1 and tostring(calls[1].link):find("item:2840", 1, true), "ShowTipWithPricing called on Cookbook tooltip for output")
  ok(AC.TooltipHasAuctionatorPrices(tip) and tip.priceLines[1] == "Vendor" and tip.priceLines[2] == "Auction", "output tooltip shows Vendor and Auction")
  local n = #tip.priceLines
  AC.AddAuctionatorTip(tip, link(2840), 2840, 1)
  ok(#calls == 1 and #tip.priceLines == n, "does not duplicate Auctionator lines")

  -- recipe list / output icon pass the craft count; reagents pass need
  calls = {}
  AC._tooltipFor(owner, link(2770), 2770, 12)
  ok(#calls == 1 and calls[1].count == 12 and tostring(calls[1].link):find("item:2770", 1, true), "reagent count is passed to Auctionator")
  local right = _G[tip:GetName().."TextRight2"]
  ok(right and right.text == "53c / 54c", "stack price format on Auction line: "..tostring(right and right.text))

  -- live reagent row on the selected copper recipe (need 1)
  local copperRow
  for _, r in ipairs(U.rows) do
    local d = rawget(r, "data")
    if d and d.recipe and d.recipe.id == 2657 then copperRow = r end
  end
  ok(copperRow, "copper row for reagent tooltip test")
  if copperRow then copperRow.scripts.OnClick(copperRow) end
  calls = {}
  U.reagents[1].scripts.OnEnter(U.reagents[1])
  ok(#calls == 1 and calls[1].tip == tip and calls[1].count == 1 and tostring(calls[1].link):find("item:2770", 1, true), "reagent row tooltip uses Auctionator with need count")
  U.icon.scripts.OnEnter(U.icon)
  ok(#calls == 2 and calls[2].count == 1 and tostring(calls[2].link):find("item:2840", 1, true), "output icon tooltip uses Auctionator")

  calls = {}
  AC._tooltipFor(owner, "|cff71d5ff|Hspell:2657|h[Smelt Copper]|h|r", nil)
  ok(#calls == 0 and not AC.TooltipHasAuctionatorPrices(tip), "spell link: no Auctionator item prices")

  Auctionator.Tooltip.ShowTipWithPricing = function() error("boom") end
  AC._tooltipFor(owner, link(2840), 2840, 1)
  ok(AC.TooltipHasAuctionatorPrices(tip), "errors in ShowTipWithPricing are swallowed and fallback can still add lines")

  -- Fallback: no ShowTipWithPricing, use API.v1 + vendor sell price
  Auctionator.Tooltip = nil
  AC._tooltipFor(owner, link(2770), 2770, 2)
  local auctionAmt
  for i, line in ipairs(tip.priceLines or {}) do
    if line == "Auction" then
      local fs = _G[tip:GetName().."TextRight"..i]
      auctionAmt = fs and fs.text
    end
  end
  ok(AC.TooltipHasAuctionatorPrices(tip) and auctionAmt == "53c / 1s 6c", "fallback stack format: "..tostring(auctionAmt))

  Auctionator = nil
  U.reagents[1].scripts.OnLeave(U.reagents[1])
end
local bronzeRow; for _, r in ipairs(U.rows) do local d = rawget(r, "data") if d and d.recipe == bronze then bronzeRow = r end end
bronzeRow.scripts.OnClick(bronzeRow)
ok(U.dCraft.text == "You can make 3 now (4 counting your bank).", "bank-aware craft line")
ok(U.reagents[1].have.text:find("+2 bank", 1, true) ~= nil, "bank count shown on reagent")
ok(#U.reagents == 2 and U.reagents[2]:IsShown(), "two reagent rows")
-- selection survives a rescan while the window is open
open = "Mining"; now = now + 10; fire("TRADE_SKILL_SHOW"); runTimers(); open = nil
ok(U.dCraft.text == "You can make 3 now (4 counting your bank)." and U.reagents[2]:IsShown(), "selection kept after rescan")
-- live update on bag change
bags[2840] = 10
F.scripts.OnEvent(F, "BAG_UPDATE_DELAYED"); runTimers()
ok(U.dCraft.text == "You can make 4 now.", "refresh on bag update ("..tostring(U.dCraft.text)..")")
ok(F.events.BAG_UPDATE_DELAYED, "bag events while shown")
-- search box
U.search:SetText("tin"); U.search.scripts.OnTextChanged(U.search)
do local s = {} for _, r in ipairs(AC._rows) do s[#s+1] = r.header or r.recipe.name end ok(#AC._rows == 2 and AC._rows[2].recipe.id == 2659, "search box filters: "..table.concat(s, ",")) end
U.search:SetText(""); U.search.scripts.OnTextChanged(U.search)
-- header click collapses
U.rows[1].scripts.OnClick(U.rows[1]); ok(#AC._rows == 1 and AC._rows[1].collapsed, "header click collapses")
U.rows[1].scripts.OnClick(U.rows[1]); ok(#AC._rows == 3, "header click expands")
-- toggle / esc / keybind
SlashCmdList.ALCHEMISTSCOOKBOOK(""); ok(not F:IsShown() and not F.events.BAG_UPDATE_DELAYED, "/acook toggles closed, events off")
AlchemistsCookbook_Binding("toggle"); ok(F:IsShown(), "keybind opens")
btn.scripts.OnClick(btn, "LeftButton"); ok(not F:IsShown(), "minimap left-click toggles")
SlashCmdList.ALCHEMISTSCOOKBOOK("black"); ok(F:IsShown() and U.rank.text == "Blacksmithing 80/150", "/acook black opens that profession")
-- drag saves position
F.point = { "TOPLEFT", nil, "TOPLEFT", 50, -60 }; F.scripts.OnDragStop(F)
ok(AlchemistsCookbookDB.pos and AlchemistsCookbookDB.pos[3] == 50, "position saved")
SlashCmdList.ALCHEMISTSCOOKBOOK("scale 120"); ok(AlchemistsCookbookDB.scale == 1.2 and F.scale == 1.2, "scale 120%")
SlashCmdList.ALCHEMISTSCOOKBOOK("scale 999"); ok(AlchemistsCookbookDB.scale == 1.5, "scale clamped")
SlashCmdList.ALCHEMISTSCOOKBOOK("reset"); ok(AlchemistsCookbookDB.pos == nil and AlchemistsCookbookDB.scale == 1 and F.point[1] == "CENTER", "reset position")
clearChat(); SlashCmdList.ALCHEMISTSCOOKBOOK("list"); ok(chatHas("Mining: 2 recipes, skill 50/75"), "list")
clearChat(); SlashCmdList.ALCHEMISTSCOOKBOOK("help"); ok(chatHas("/acook forget"), "help")
SlashCmdList.ALCHEMISTSCOOKBOOK("minimap"); ok(AlchemistsCookbookDB.minimap.hide and not btn:IsShown(), "minimap hide")
SlashCmdList.ALCHEMISTSCOOKBOOK("minimap"); ok(not AlchemistsCookbookDB.minimap.hide and btn:IsShown(), "minimap show")

-- settings page
local P = AC.panel
ok(P and settingsCat and settingsCat.frame == P, "settings category registered")
P:Hide(); SlashCmdList.ALCHEMISTSCOOKBOOK("options"); ok(P:IsShown(), "/acook options opens page")
local PU = AC._pui
ok(PU.minimap:GetChecked() == true and PU.scale.text == "100%", "panel reflects settings")
PU.minimap:SetChecked(false); PU.minimap.scripts.OnClick(PU.minimap); ok(AlchemistsCookbookDB.minimap.hide, "panel minimap toggle")
PU.minimap:SetChecked(true); PU.minimap.scripts.OnClick(PU.minimap)
PU.plus.scripts.OnClick(PU.plus); ok(AlchemistsCookbookDB.scale == 1.05 and PU.scale.text == "105%", "panel + scale")
PU.minus.scripts.OnClick(PU.minus); PU.minus.scripts.OnClick(PU.minus); ok(AlchemistsCookbookDB.scale == 0.95, "panel - scale")
AlchemistsCookbookDB.pos = { "TOP", "TOP", 1, 1 }
PU.reset.scripts.OnClick(PU.reset); ok(AlchemistsCookbookDB.pos == nil and AlchemistsCookbookDB.scale == 1, "panel reset position")
ok(PU.saved.text:find("Mining (2 recipes, 50/75)", 1, true), "panel lists saved professions")
P:Hide(); btn.scripts.OnClick(btn, "RightButton"); ok(P:IsShown(), "minimap right-click opens settings")
P:Hide(); inCombat = true; SlashCmdList.ALCHEMISTSCOOKBOOK("options"); ok(not P:IsShown(), "no settings in combat"); inCombat = false
-- browsing works in combat (plain frames only)
inCombat = true; F:Hide(); SlashCmdList.ALCHEMISTSCOOKBOOK("show"); ok(F:IsShown(), "window opens in combat"); inCombat = false

-- repeat-craft status line (1.0.1: done counter, batch-size math)
F:Show()
local function castOnce(spell, guid, rem, opts)
  opts = opts or {}
  now = now + 3
  remaining = rem
  fire("UNIT_SPELLCAST_START", "player", guid, spell)
  if opts.rescan then open = "Mining"; now = now + 10; fire("TRADE_SKILL_LIST_UPDATE"); runTimers(); open = nil end
  if not opts.noSucceeded then fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spell) end
  if opts.chat then fire("CHAT_MSG_LOOT", "You create: "..link(opts.chat)..".", "Click It") end
  if opts.lagRemaining then remaining = rem else remaining = math.max(rem - 1, 0) end
end
-- the user's case: Smelt Copper x5 with the Mining window open (rescans every craft)
castOnce(2657, "g1", 4, { rescan = true, chat = 2840 })
ok(AC.cast.active and AC.cast.made == 1 and AC.cast.total == 5, "after 1st: 1 of 5 (made "..AC.cast.made..")")
ok(U.castLine.text:find("1 of 5 done, 4 left", 1, true) and U.castLine.text:find("Copper Bar", 1, true), "line: "..tostring(U.castLine.text))
now = now + 3; remaining = 3; fire("UNIT_SPELLCAST_START", "player", "g2", 2657)
ok(U.castLine.text:find("1 of 5 done, 4 left", 1, true), "during 2nd cast: still 1 done, 4 left incl. current")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g2", 2657); fire("CHAT_MSG_LOOT", "You create: "..link(2840)..".", "Click It")
ok(AC.cast.made == 2, "cast + chat for one craft counts once ("..AC.cast.made..")")
-- chat arriving before SUCCEEDED also counts once
now = now + 3; remaining = 2; fire("UNIT_SPELLCAST_START", "player", "g2b", 2657); fire("CHAT_MSG_LOOT", "You create: "..link(2840)..".", "Click It"); fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g2b", 2657)
ok(AC.cast.made == 3, "chat-then-succeeded counts once ("..AC.cast.made..")")
AC.cast.made = 2; AC.cast.counted["g2b"] = nil -- undo so the rest of the batch below stays 5 long
castOnce(2657, "g3", 2, { rescan = true, lagRemaining = true, chat = 2840 }) -- client value lags
ok(AC.cast.made == 3 and AC.cast.total == 5 and U.castLine.text:find("3 of 5 done, 2 left", 1, true), "lagging remaining ignored: "..tostring(U.castLine.text))
castOnce(2657, "g4", 2, { chat = 2840 }) -- lag: client still says 2 at start of 4th
ok(AC.cast.total == 5 and AC.cast.made == 4, "lag at start does not start a new batch")
castOnce(2657, "g5", 0, { chat = 2840 })
ok(not AC.cast.active and U.castLine.text == "", "batch done after 5 of 5 -> line clears")
-- new batch of 4 right after, counted from 0 again
castOnce(2657, "h1", 3, {})
ok(AC.cast.active and AC.cast.total == 4 and AC.cast.made == 1, "new batch of 4 starts fresh")
-- fallback: SUCCEEDED never arrives, chat lines count
castOnce(2657, "h2", 2, { noSucceeded = true, chat = 2840 })
ok(AC.cast.made == 2, "chat fallback counts when no SUCCEEDED ("..AC.cast.made..")")
-- chat for a different item / other wording is ignored
fire("CHAT_MSG_LOOT", "You create: "..link(2841)..".", "Click It"); ok(AC.cast.made == 2, "other item ignored")
fire("CHAT_MSG_LOOT", "You receive loot: "..link(2840)..".", "Click It"); ok(AC.cast.made == 2, "loot lines ignored")
-- interrupt (jump) ends it; FAILED from an unrelated cast GUID doesn't
remaining = 1; fire("UNIT_SPELLCAST_START", "player", "h3", 2657)
fire("UNIT_SPELLCAST_FAILED", "player", "other", 2657); ok(AC.cast.active, "failed for another cast GUID ignored")
fire("UNIT_SPELLCAST_INTERRUPTED", "player", "h3", 2657); ok(not AC.cast.active and U.castLine.text == "", "jump/interrupt clears line")
-- stale: batch stops without an event (e.g. ran out of ore) -> clears after 8s
castOnce(2657, "k1", 4, {})
ok(AC.cast.active and pendingLong() > 0, "stale check scheduled after a completion")
runTimers(true); ok(not AC.cast.active and U.castLine.text == "", "stale batch clears")
-- stale check does not end a batch that is still casting
castOnce(2657, "k2", 4, {}); remaining = 3; fire("UNIT_SPELLCAST_START", "player", "k3", 2657)
runTimers(true); ok(AC.cast.active, "stale check keeps a batch that is mid-cast")
fire("UNIT_SPELLCAST_INTERRUPTED", "player", "k3", 2657)
-- multi-output recipe (Bronze x2): one chat line per craft, shows x2
castOnce(2659, "b1", 1, { noSucceeded = true })
fire("CHAT_MSG_LOOT", "You create: "..link(2841).."x2.", "Click It")
ok(AC.cast.made == 1 and U.castLine.text:find("x2", 1, true) and U.castLine.text:find("1 of 2 done, 1 left", 1, true), "bronze x2: "..tostring(U.castLine.text))
fire("UNIT_SPELLCAST_INTERRUPTED", "player", "b1", 2659)
-- no remaining-recasts API at all: shows a plain done count
local saveRR = C_TradeSkillUI.GetRemainingRecasts; C_TradeSkillUI.GetRemainingRecasts = nil
fire("UNIT_SPELLCAST_START", "player", "n1", 2657); fire("UNIT_SPELLCAST_SUCCEEDED", "player", "n1", 2657)
ok(AC.cast.total == nil and U.castLine.text:find(": 1 done", 1, true), "no recast API: "..tostring(U.castLine.text))
fire("UNIT_SPELLCAST_START", "player", "n2", 2657); fire("UNIT_SPELLCAST_INTERRUPTED", "player", "n2", 2657)
C_TradeSkillUI.GetRemainingRecasts = saveRR
-- other units / non-recipe / secret
fire("UNIT_SPELLCAST_START", "target", "x", 2657); ok(not AC.cast.active, "other units ignored")
fire("UNIT_SPELLCAST_START", "player", "x", 133); ok(not AC.cast.active, "non-recipe spells ignored")
secretIDs[2657] = true; fire("UNIT_SPELLCAST_START", "player", "x", 2657); ok(not AC.cast.active, "secret values ignored"); secretIDs[2657] = nil
ok(ev.events.CHAT_MSG_LOOT and ev.events.CHAT_MSG_TRADESKILLS, "chat events registered")
ok(AC.ParseCreated("You create: "..link(2840)..".") == 2840 and AC.ParseCreated("Bob creates: "..link(2840)) == nil, "ParseCreated")
LOOT_ITEM_CREATED_SELF = "Vous créez : %s."; ok(AC.ParseCreated("Vous créez : "..link(2840)..".") == 2840, "localized create line"); LOOT_ITEM_CREATED_SELF = nil
runTimers(true)


-- Auctionator price line on the detail pane (1.0.5)
do
  local prices, vendor = { [2770] = 50, [2840] = 40 }, {}
  Auctionator = { API = { v1 = {
    GetAuctionPriceByItemID = function(_, id) return prices[id] end,
    GetAuctionPriceByItemLink = function(_, itemLink)
      local id = tonumber(itemLink:match("item:(%d+)"))
      return id and prices[id]
    end,
    GetVendorPriceByItemID = function(_, id) return vendor[id] end,
  } } }
  F:Show()
  if U.search then U.search:SetText("") end
  -- Switch to Mining only if needed (clicking the current tab would clear the selection)
  for _, tab in ipairs(U.tabs) do
    if tab.prof == "Mining" and tab:IsEnabled() and tab.scripts.OnClick then
      tab.scripts.OnClick(tab)
      break
    end
  end
  local copperRow
  for _, r in ipairs(U.rows) do
    local d = rawget(r, "data")
    if d and d.recipe and d.recipe.id == 2657 then copperRow = r end
  end
  ok(copperRow, "Mining copper row available for price-line test")
  if copperRow then copperRow.scripts.OnClick(copperRow) end
  local text = U.dCost and U.dCost.text
  ok(U.dCost:IsShown() and text and text:find("To Craft: 50c", 1, true) and text:find("|cffff4040-12c|r", 1, true), "detail shows To Craft / red Profit: "..tostring(text))
  -- missing reagent price marks incomplete; profit still uses the product price
  prices[2770] = nil
  AC.Refresh()
  text = U.dCost.text
  ok(U.dCost:IsShown() and text:find("To Craft: 0c (incomplete)", 1, true) and text:find("Profit:", 1, true), "detail incomplete: "..tostring(text))
  Auctionator = nil
  AC.Refresh()
  ok(not U.dCost:IsShown() and (not U.dCost.text or U.dCost.text == ""), "price line hides again when Auctionator is gone")
end

-- filters (1.0.2)
do
  F:Show()
  local saveBags = {} for k, v in pairs(bags) do saveBags[k] = v end
  local saveBank = {} for k, v in pairs(bank) do saveBank[k] = v end
  bags[2770], bags[2840], bags[3576], bags[2835], bags[2880] = 23, 3, 0, 5, 0
  bank[3576] = 1
  local function names(prof, q)
    local t = {}
    for _, r in ipairs(AC.BuildRows(prof, q or "")) do t[#t+1] = r.header and ("#"..r.header) or r.recipe.name end
    return table.concat(t, ",")
  end
  ok(names("Blacksmithing") == "#Materials,Rough Sharpening Stone,#Weapons,Heavy Copper Maul", "no filters: "..names("Blacksmithing"))
  -- skill-ups only: grey (trivial) sharpening stone hidden, empty Materials header hidden
  SlashCmdList.ALCHEMISTSCOOKBOOK("skillup")
  ok(AlchemistsCookbookDB.filters.skillup == true, "/acook skillup toggles on")
  ok(names("Blacksmithing") == "#Weapons,Heavy Copper Maul", "skill-ups only: "..names("Blacksmithing"))
  ok(names("Mining") == "#Smelting,Smelt Copper,Smelt Bronze", "orange + yellow kept: "..names("Mining"))
  ok(AC.CanSkillUp({ difficulty = "easy" }) and not AC.CanSkillUp({ difficulty = "trivial" }) and not AC.CanSkillUp({}), "CanSkillUp")
  SlashCmdList.ALCHEMISTSCOOKBOOK("skillup off"); ok(AlchemistsCookbookDB.filters.skillup == false, "/acook skillup off")
  -- have materials
  SlashCmdList.ALCHEMISTSCOOKBOOK("have on")
  ok(names("Blacksmithing") == "#Materials,Rough Sharpening Stone", "have materials (bags): "..names("Blacksmithing"))
  ok(names("Mining") == "#Smelting,Smelt Copper", "bronze hidden without tin in bags: "..names("Mining"))
  SlashCmdList.ALCHEMISTSCOOKBOOK("bank on")
  ok(AlchemistsCookbookDB.filters.haveBank and names("Mining") == "#Smelting,Smelt Copper,Smelt Bronze", "bank counts tin: "..names("Mining"))
  SlashCmdList.ALCHEMISTSCOOKBOOK("bank off")
  ok(AC.HaveMaterials({ reagents = {} }), "no-reagent recipe counts as makeable")
  -- live: bags change -> filtered list changes on refresh
  bags[3576] = 2; F.scripts.OnEvent(F, "BAG_UPDATE_DELAYED"); runTimers()
  U.tabs[2].scripts.OnClick(U.tabs[2])
  local has = false for _, r in ipairs(AC._rows) do if r.recipe and r.recipe.id == 2659 then has = true end end
  ok(has, "have filter follows bag changes")
  bags[3576] = 0
  -- both + search combine
  SlashCmdList.ALCHEMISTSCOOKBOOK("skillup on")
  ok(names("Blacksmithing") == "", "skill-up + have: nothing in Blacksmithing")
  ok(names("Mining", "copper") == "#Smelting,Smelt Copper" and names("Mining", "bronze") == "", "filters combine with search")
  -- empty message in the window
  U.tabs[1].scripts.OnClick(U.tabs[1])
  ok(#AC._rows == 0 and U.empty.text:find("Nothing in Blacksmithing matches Skill-ups only + Have materials", 1, true) and U.empty.text:find("Untick a filter", 1, true), "friendly empty message: "..tostring(U.empty.text))
  U.search:SetText("zzz"); U.search.scripts.OnTextChanged(U.search)
  ok(U.empty.text:find("your search and", 1, true) and U.empty.text:find("clear the search", 1, true), "empty message mentions search")
  U.search:SetText(""); U.search.scripts.OnTextChanged(U.search)
  -- window checkboxes reflect and drive the filters
  ok(U.fSkill:GetChecked() and U.fHave:GetChecked() and not U.fBank:GetChecked() and U.fBank:IsShown(), "window checkboxes reflect settings; + bank shown with have")
  U.fSkill:SetChecked(false); U.fSkill.scripts.OnClick(U.fSkill); ok(AlchemistsCookbookDB.filters.skillup == false, "window skill-up box")
  U.fHave:SetChecked(false); U.fHave.scripts.OnClick(U.fHave); ok(AlchemistsCookbookDB.filters.have == false and not U.fBank:IsShown() and U.fBank:IsEnabled(), "window have box; + bank hidden (not greyed) when have is off")
  ok(#AC._rows == 4 and U.empty.text == "", "filters off: full list back")
  ok(U.fSkill.template == "UICheckButtonTemplate", "filter boxes use plain checkbuttons")
ok(U.fSkill.point[1] == "TOPLEFT" and U.fSkill.point[3] == "TOPRIGHT" and U.fSkill.point[4] < U.fHave.point[4] and U.fHave.point[4] < U.fBank.point[4] and U.fBank.point[4] < 0, "filters sit on the right-hand side, in order")
  -- collapsed header still respected with a filter on, and empty header hidden
  AC.ToggleHeader("Blacksmithing", "Materials"); AC.SetFilter("have", true)
  ok(names("Blacksmithing") == "#Materials", "collapsed header kept when it has matches")
  AC.SetFilter("have", false); AC.ToggleHeader("Blacksmithing", "Materials")
  -- settings page boxes
  SlashCmdList.ALCHEMISTSCOOKBOOK("options")
  local PU = AC._pui
  ok(PU.fSkill and PU.fHave and PU.fBank and not PU.fSkill:GetChecked(), "settings page has filter boxes")
  PU.fSkill:SetChecked(true); PU.fSkill.scripts.OnClick(PU.fSkill); ok(AlchemistsCookbookDB.filters.skillup and U.fSkill:GetChecked(), "settings box drives filter + window box")
  ok(not PU.fBank:IsShown() and PU.sizeLabel.point[2] == PU.fHave, "settings bank box hidden while have is off; rows move up")
  PU.fHave:SetChecked(true); PU.fHave.scripts.OnClick(PU.fHave); ok(PU.fBank:IsShown() and PU.sizeLabel.point[2] == PU.fBank and U.fBank:IsShown(), "settings + window bank boxes appear with have")
  PU.fBank:SetChecked(true); PU.fBank.scripts.OnClick(PU.fBank); ok(AlchemistsCookbookDB.filters.haveBank, "settings bank box")
  SlashCmdList.ALCHEMISTSCOOKBOOK("have off"); ok(not PU.fBank:IsShown() and not U.fBank:IsShown() and AlchemistsCookbookDB.filters.haveBank == true, "unticking have hides + bank but keeps its value")
  SlashCmdList.ALCHEMISTSCOOKBOOK("have on"); ok(PU.fBank:IsShown() and PU.fBank:GetChecked() and U.fBank:IsShown() and U.fBank:GetChecked(), "re-ticking have shows + bank still ticked")
  SlashCmdList.ALCHEMISTSCOOKBOOK("skillup off"); ok(not PU.fSkill:GetChecked(), "slash change shows on settings page")
  -- reset to defaults clears filters
  AC.panel.OnDefault(); ok(not AlchemistsCookbookDB.filters.skillup and not AlchemistsCookbookDB.filters.have and not AlchemistsCookbookDB.filters.haveBank, "defaults clear filters")
  -- old saved variables get filter defaults; saved values survive reload
  local a = AC.InitDB({ minimap = { hide = false, angle = 10 }, scale = 1 }, AlchemistsCookbookCharDB)
  ok(type(a.filters) == "table" and a.filters.have == false, "1.0.1 saved vars upgraded")
  a.filters.skillup = true
  local a2 = AC.InitDB(a, AlchemistsCookbookCharDB); ok(a2.filters.skillup == true, "filter setting persists")
  a2.filters.skillup = false
  clearChat(); SlashCmdList.ALCHEMISTSCOOKBOOK("help"); ok(chatHas("/acook skillup") and chatHas("/acook have"), "help lists filters")
  for k, v in pairs(saveBags) do bags[k] = v end
  for k, v in pairs(saveBank) do bank[k] = v end
  bank[3576] = nil
end

-- "Unknown 0/0" guard (1.0.2)
do
  PROFS.Glitch = { base = { professionName = "Unknown", professionID = 0, skillLevel = 0, maxSkillLevel = 0 }, child = {}, recipes = PROFS.Blacksmithing.recipes }
  local before = {} for k in pairs(AlchemistsCookbookCharDB.professions) do before[#before+1] = k end table.sort(before)
  local function keys() local t = {} for k in pairs(AlchemistsCookbookCharDB.professions) do t[#t+1] = k end table.sort(t) return table.concat(t, ",") end
  local savedBS = AlchemistsCookbookCharDB.professions.Blacksmithing
  AlchemistsCookbookCharDB.professions.Blacksmithing = nil
  ok(AC.IsBadProfessionName("Unknown") and AC.IsBadProfessionName("UNKNOWN") and AC.IsBadProfessionName("") and AC.IsBadProfessionName(nil) and AC.IsBadProfessionName("  unknown ") and not AC.IsBadProfessionName("Blacksmithing"), "bad names")
  UNKNOWN = "Inconnu"; UNKNOWNOBJECT = "Inconnue"
  ok(AC.IsBadProfessionName("Inconnu") and AC.IsBadProfessionName("Inconnue"), "localized UNKNOWN / UNKNOWNOBJECT")
  -- client says Unknown 0/0 and has no other way to tell: nothing saved, retried
  open = "Glitch"; clearChat()
  local e, why = AC.ScanModern(); ok(e == nil and why == "notready", "Unknown 0/0 scan -> notready ("..tostring(why)..")")
  fire("TRADE_SKILL_SHOW"); local queued = #timers; runTimers()
  ok(AlchemistsCookbookCharDB.professions.Unknown == nil and not keys():find("Unknown", 1, true), "never saved as Unknown")
  -- localized placeholder name
  PROFS.Glitch.base.professionName = "Inconnu"; PROFS.Glitch.base.maxSkillLevel = 150
  e, why = AC.ScanModern(); ok(e == nil and why == "notready", "localized Unknown rejected")
  -- good name but skill 0/0 -> not saved
  PROFS.Glitch.base.professionName = "Blacksmithing"; PROFS.Glitch.base.maxSkillLevel = 0
  e, why = AC.ScanModern(); ok(e == nil and why == "notready", "max rank 0 rejected")
  -- data arrives during the retries: first two scans Unknown, then real
  local calls = 0
  local realBase = C_TradeSkillUI.GetBaseProfessionInfo
  C_TradeSkillUI.GetBaseProfessionInfo = function()
    calls = calls + 1
    if calls <= 2 then return { professionName = "Unknown", skillLevel = 0, maxSkillLevel = 0 } end
    return { professionName = "Blacksmithing", professionID = 164, skillLevel = 81, maxSkillLevel = 150 }
  end
  fire("TRADE_SKILL_SHOW"); runTimers()
  local bs = AlchemistsCookbookCharDB.professions.Blacksmithing
  ok(bs and bs.rank == 81 and calls >= 3 and AlchemistsCookbookCharDB.professions.Unknown == nil, "retry saves under the real name once ready")
  C_TradeSkillUI.GetBaseProfessionInfo = realBase
  -- derive from the recipes' profession when the window says Unknown
  AlchemistsCookbookCharDB.professions.Blacksmithing = nil
  PROFS.Glitch.base = { professionName = "Unknown", skillLevel = 0, maxSkillLevel = 0 }
  C_TradeSkillUI.GetProfessionInfoByRecipeID = function(id)
    return { professionName = "Classic Blacksmithing", parentProfessionName = "Blacksmithing", skillLevel = 82, maxSkillLevel = 150 }
  end
  e = AC.ScanModern(); ok(e and e.name == "Blacksmithing" and e.rank == 82 and e.maxRank == 150, "name + rank derived from recipe's profession")
  C_TradeSkillUI.GetProfessionInfoByRecipeID = function() return { professionName = "Unknown", skillLevel = 0, maxSkillLevel = 0 } end
  e, why = AC.ScanModern(); ok(e == nil and why == "notready", "derived Unknown still rejected")
  C_TradeSkillUI.GetProfessionInfoByRecipeID = nil
  -- skill line lookup fills in a missing max rank
  PROFS.Glitch.base = { professionName = "Blacksmithing", professionID = 164, skillLevel = 0, maxSkillLevel = 0 }
  C_TradeSkillUI.GetProfessionInfoBySkillLineID = function(id) if id == 164 then return { professionName = "Blacksmithing", skillLevel = 83, maxSkillLevel = 150 } end end
  e = AC.ScanModern(); ok(e and e.name == "Blacksmithing" and e.rank == 83, "rank from skill line lookup")
  C_TradeSkillUI.GetProfessionInfoBySkillLineID = nil
  -- Store refuses bad entries outright
  ok(not AC.Store({ name = "Unknown", rank = 0, maxRank = 0, recipes = { { name = "x", reagents = {} } } }), "Store rejects Unknown")
  ok(not AC.Store({ name = "Mining", rank = 0, maxRank = 0, recipes = { { name = "x", reagents = {} } } }), "Store rejects 0/0")
  UNKNOWN, UNKNOWNOBJECT = nil, nil
  open = nil
  AlchemistsCookbookCharDB.professions.Blacksmithing = savedBS
  ok(keys() == table.concat(before, ","), "saved professions unchanged by the guard tests: "..keys())
  -- purge on load
  local char = { professions = {
      Unknown = { name = "Unknown", rank = 0, maxRank = 0, recipes = { { name = "Heavy Copper Maul" } } },
      Tailoring = { name = "Tailoring", rank = 0, maxRank = 0, recipes = {} },
      Blacksmithing = { name = "Blacksmithing", rank = 80, maxRank = 150, recipes = {} } },
    collapsed = { Unknown = { Weapons = true } } }
  local acct = AlchemistsCookbookDB
  AC.InitDB(acct, char)
  ok(char.professions.Unknown == nil and char.professions.Tailoring == nil and char.professions.Blacksmithing and char.collapsed.Unknown == nil and AC.purgedOnLoad == 2, "purge Unknown and 0/0 entries on load")
  clearChat(); fire("PLAYER_LOGIN"); ok(chatHas("Removed 2 saved lists") and AC.purgedOnLoad == 0, "purge notice once at login")
  AC.InitDB(acct, AlchemistsCookbookCharDB)
  ok(AC.purgedOnLoad == 0 and AlchemistsCookbookCharDB.professions.Blacksmithing, "real data untouched by purge")
  PROFS.Glitch = nil
end

-- forget
clearChat(); SlashCmdList.ALCHEMISTSCOOKBOOK("forget mining"); ok(AlchemistsCookbookCharDB.professions.Mining == nil and chatHas("Forgot Mining"), "forget")
SlashCmdList.ALCHEMISTSCOOKBOOK("forget nothing"); ok(#AC.ProfessionNames() == 1, "forget unknown is safe")

-- reload: saved vars survive InitDB
local saved, savedC = AlchemistsCookbookDB, AlchemistsCookbookCharDB
local a2, c2 = AC.InitDB(saved, savedC); ok(c2.professions.Blacksmithing and a2.minimap, "reload keeps data")
local a3 = AC.InitDB({ scale = 9 }, nil); ok(a3.scale == 1, "bad scale fixed")
AC.InitDB(saved, savedC)

-- never a protected or state-changing call
ok(#forbidden == 0, "no protected calls: "..table.concat(forbidden, ","))
for t in pairs(TEMPLATES_USED) do
  local allowed = { BackdropTemplate=1, UIPanelCloseButton=1, UIPanelScrollFrameTemplate=1, InputBoxTemplate=1, UIPanelButtonTemplate=1, UICheckButtonTemplate=1,
    -- both defined in the Forever 1.60.1 client's Blizzard_GameTooltip/Mainline/GameTooltip.xml (read via CASC)
    GameTooltipTemplate=1, ShoppingTooltipTemplate=1 }
  ok(allowed[t], "template used by other Forever add-ons: "..t)
  ok(not t:find("Secure"), "no secure templates")
end
if MODE == "legacy" then ok(legacyOpens == 4 or legacyOpens > 0, "legacy options path") end
print(("passes=%d fails=%d"):format(passes, fails))
return fails
