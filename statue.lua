local addon, ns = ...

local _, class = UnitClass("player")
if (class ~= "MONK") then return end

local SiValue = ns.SiValue
local Debug = ns.Debug
local db

local statueHealth
local scalingFactor = 0.5 -- the statue's max health is 50% of the player's max health
local statueID = 61146

local strfind = string.find
local strmatch = string.match
local bitband = bit.band
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE

local tracker = CreateFrame("Frame", nil, UIParent)
tracker:SetSize(40, 40)
tracker:SetPoint("CENTER", UIParent, "CENTER", -450, -100)
tracker:Hide()

local tex = tracker:CreateTexture(nil, "BACKGROUND")
tex:SetAllPoints()
tex:SetTexture(nil)

local durationText = tracker:CreateFontString(nil, "ARTWORK", "NumberFont_Outline_Large")
durationText:SetPoint("TOP", tracker, "BOTTOM", 0, -10)

local healthText = tracker:CreateFontString(nil, "ARTWORK", "NumberFont_Outline_Large")
healthText:SetPoint("BOTTOM", tracker, "TOP", 0, 10)

local cd = CreateFrame("Cooldown", nil, tracker)
cd:SetAllPoints()
cd:SetReverse(true)

local border = cd:CreateTexture(nil, "OVERLAY")
border:SetPoint("TOPLEFT", tracker, "TOPLEFT", -4, 4)
border:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 4, -4)
border:SetTexture(ns.borderTex)

local ShowStatueTracker = function(icon, start, duration)
	tex:SetTexture(icon)
	tex:SetTexCoord(.1, .9, .1, .9)
	cd:SetCooldown(start, duration)
	tracker:Show()
end

tracker:RegisterEvent("ADDON_LOADED")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
tracker:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

function tracker:ADDON_LOADED(event, name)
	if (addon ~= name) then return end

	rainTankAbsorbDB = rainTankAbsorbDB or {}
	db = rainTankAbsorbDB

	self:UnregisterEvent(event)
end

-- TODO: this will lead to wrong values if a damaged statue is present
function tracker:PLAYER_ENTERING_WORLD(event)
	self:RegisterEvent("PLAYER_TOTEM_UPDATE")
	self:PLAYER_TOTEM_UPDATE(event, 1)
end

function tracker:PLAYER_TOTEM_UPDATE(event, slot)
	local hasTotem, name, start, duration, icon = GetTotemInfo(slot)
	if (hasTotem) then
		ShowStatueTracker(icon, start, duration)
		statueHealth = UnitHealthMax("player") * scalingFactor
		healthText:SetText(SiValue(statueHealth))

		if (event == "PLAYER_ENTERING_WORLD") then
			print(format("%s: You might be getting wrong values. Please target your statue for correct results.", GetAddOnMetadata(addon, "Title")))
			self:RegisterEvent("PLAYER_TARGET_CHANGED")
		end

		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	else
		db.statueGUID = nil
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("UNIT_MAXHEALTH")
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self:Hide()
	end
end

function tracker:PLAYER_TARGET_CHANGED(event)
	if (UnitExists("target") and UnitGUID("target") == db.statueGUID) then
		statueHealth = UnitHealth("target")
		healthText:SetText(SiValue(statueHealth))
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	end
end

function tracker:UNIT_MAXHEALTH(event, unit)
	local statueMaxHealth = UnitHealthMax(unit) * scalingFactor
	if statueHealth > statueMaxHealth then
		healthText:SetText(SiValue(statueMaxHealth))
	end
end

function tracker:COMBAT_LOG_EVENT_UNFILTERED(event, _, subEvent, _, _, _, _, _, destGUID, _, destFlags, destRaidFlags, ...)
	-- we only want the damage events as the statue cannot be healed
	local prefix, suffix = strmatch(subEvent, "^([A-Z_]+)_([A-Z]+)$")
	-- TODO: check DAMAGE_SPLIT, exclude SPELL_DURABILITY_DAMAGE
	if (suffix == "DAMAGE" and strfind(destGUID, statueID) and bitband(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE) then
		db.statueGUID = destGUID
		local amountIndex = 1
		if (prefix == "ENVIRONMENTAL") then
			amountIndex = 2
		elseif (prefix == "RANGE" or prefix == "SPELL") then
			amountIndex = 4
		end

		local amount = select(amountIndex, ...)
		statueHealth = statueHealth - amount
		healthText:SetText(SiValue(statueHealth))
	end
end
