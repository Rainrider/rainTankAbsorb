local addon, ns = ...

local borderTex = [=[Interface\AddOns\rainTankAbsorb\media\textures\buttonnormal]=]
ns.borderTex = borderTex

local AbsorbSpell = {
	DEATHKNIGHT =  77535,	-- Blood Shield
	       MONK = 115295,	-- Guard
	    PALADIN =  65148,	-- Sacred Shield
	    WARRIOR = 112048,	-- Shield Barrier
}

local _, class = UnitClass("player")

local trackedSpellID = AbsorbSpell[class]
if not trackedSpellID then return end

local trackedSpellName
local topAP = 0

local SiValue = function(value)
	if value >= 1e6 then
		return string.format("%.1fm", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fk", value / 1e3)
	else
		return value
	end
end
ns.SiValue = SiValue

local Debug = function() end
if (AdiDebug) then
	Debug = AdiDebug:Embed({}, addon)
end
ns.Debug = Debug

local tracker = CreateFrame("Frame", nil, UIParent)
tracker:SetSize(40, 40)
tracker:SetPoint("CENTER", UIParent, "CENTER", -400, -100)
tracker:Hide()

local tex = tracker:CreateTexture(nil, "BACKGROUND")
tex:SetAllPoints()
tex:SetTexture(nil)

local shieldText = tracker:CreateFontString(nil, "ARTWORK", "NumberFont_Outline_Large")
shieldText:SetPoint("TOP", tracker, "BOTTOM", 0, -10)

local apText = UIParent:CreateFontString(nil, "ARTWORK", "NumberFont_Outline_Large")
apText:SetPoint("BOTTOM", tracker, "TOP", 0, 10)

local cd = CreateFrame("Cooldown", nil, tracker)
cd:SetAllPoints()
cd:SetReverse(true)

local border = cd:CreateTexture(nil, "OVERLAY")
border:SetPoint("TOPLEFT", tracker, "TOPLEFT", -4, 4)
border:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 4, -4)
border:SetTexture(borderTex)

tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
tracker:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
tracker:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

function tracker:PLAYER_ENTERING_WORLD()
	self:PLAYER_SPECIALIZATION_CHANGED("player")
end

function tracker:PLAYER_SPECIALIZATION_CHANGED(unit)
	if not unit or unit == "player" then
		local _, _, _, _, _, role = GetSpecializationInfo(GetSpecialization() or 0)
		if role == "TANK" then
			local name, _, icon = GetSpellInfo(trackedSpellID)
			trackedSpellName = name
			tex:SetTexture(icon)
			tex:SetTexCoord(.1, .9, .1, .9)
			self:RegisterEvent("PLAYER_REGEN_DISABLED")
		else
			trackedSpellName = nil
			tracker:Hide()
			self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		end
	end
end

function tracker:PLAYER_REGEN_DISABLED()
	topAP = 0

	self:RegisterUnitEvent("UNIT_AURA", "player")
	self:RegisterUnitEvent("UNIT_ATTACK_POWER", "player")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")

	self:UNIT_AURA()
	self:UNIT_ATTACK_POWER()
end

function tracker:PLAYER_REGEN_ENABLED()
	self:UnregisterEvent("UNIT_AURA")
	self:UnregisterEvent("UNIT_ATTACK_POWER")
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")

	tracker:Hide()
	apText:Hide()
end

function tracker:UNIT_AURA()
	local _, _, _, count, _, duration, expirationTime, caster, _, _, id, _, _, _, value1, value2, value3 = UnitBuff("player", trackedSpellName)

	if value1 and id == trackedSpellID and caster == "player" then
		shieldText:SetText(SiValue(value1))
		cd:SetCooldown(expirationTime - duration, duration)
		tracker:Show()
	else
		tracker:Hide()
	end
end

function tracker:UNIT_ATTACK_POWER()
	local base, pos, neg = UnitAttackPower("player")
	local currentAP = base + pos + neg

	if currentAP >= topAP then
		topAP = currentAP
		apText:SetTextColor(0, 1, 0)
	elseif currentAP > topAP - topAP / 10 then
		apText:SetTextColor(1, 1, 0)
	else
		apText:SetTextColor(1, 1, 1)
	end

	apText:SetText(SiValue(currentAP))
	apText:Show()
end
