-- LargeHealthText 2.3 - single function: target frame health/mana only.
-- Turtle WoW: TargetFrameHealthBar.TextString is NIL even with a target
-- (confirmed by /run diagnostic 2026-11-18 22:09). 2.1 creates its own
-- FontString and assigns it when nil. 2.2 hid Blizzard's other strings.
-- 2.3 fixes the VALUE source (user correction 2026-11-18 22:18):
-- the value must NOT come from memory/database (not MobInfo2's PPP
-- memory, not Nampower's memory read). In Turtle WoW the server sends
-- real values, so UnitHealth/UnitHealthMax return the real cur/max
-- directly (e.g. 141/172, not percent). Use those. The bar's own
-- GetValue is percent-only (100 at full health) and is NOT used.
-- No large text, no player/pet, no toggle.

local function LHT_GetTargetHealth()
	-- Turtle WoW real values from the game API (not memory, not PPP)
	local cur = UnitHealth("target")
	local max = UnitHealthMax("target")
	if cur and max and max > 0 then
		return cur, max
	end
	return 0, 0
end

local function LHT_GetTargetMana()
	local cur = UnitPower("target")
	local max = UnitPowerMax("target")
	if cur and max and max > 0 then
		return cur, max
	end
	return 0, 0
end

-- owned strings, created once
local LHT_HealthText = nil
local LHT_ManaText = nil
local function LHT_EnsureStrings()
	if not LHT_HealthText and TargetFrameHealthBar then
		LHT_HealthText = TargetFrameHealthBar:CreateFontString(nil, "OVERLAY")
		LHT_HealthText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		LHT_HealthText:SetPoint("CENTER", TargetFrameHealthBar, "CENTER", 0, 0)
	end
	if not LHT_ManaText and TargetFrameManaBar then
		LHT_ManaText = TargetFrameManaBar:CreateFontString(nil, "OVERLAY")
		LHT_ManaText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		LHT_ManaText:SetPoint("CENTER", TargetFrameManaBar, "CENTER", 0, 0)
	end
end

-- hide every other FontString parented to a bar (Blizzard's own text)
local function LHT_HideOtherStrings(bar, keep)
	if not bar or not bar.GetRegions then return end
	local regions = { bar:GetRegions() }
	for _, r in ipairs(regions) do
		if r and r ~= keep and r.GetObjectType and r:GetObjectType() == "FontString" then
			r:SetText("")
			r:Hide()
		end
	end
end

local LHT_Hooked = false
local function LHT_InstallHook()
	if LHT_Hooked then return end
	LHT_Hooked = true
	local OrigUpdate = TextStatusBar_UpdateTextString
	TextStatusBar_UpdateTextString = function(sb)
		if not sb then sb = this end
		OrigUpdate(sb)
		LHT_EnsureStrings()
		if sb == TargetFrameHealthBar and LHT_HealthText then
			if sb.TextString ~= LHT_HealthText then
				sb.TextString = LHT_HealthText
			end
			LHT_HideOtherStrings(sb, LHT_HealthText)
			local cur, max = LHT_GetTargetHealth()
			if max and max > 0 then
				LHT_HealthText:SetText(cur .. "/" .. max)
				LHT_HealthText:Show()
			else
				LHT_HealthText:SetText("")
				LHT_HealthText:Hide()
			end
		elseif sb == TargetFrameManaBar and LHT_ManaText then
			if sb.TextString ~= LHT_ManaText then
				sb.TextString = LHT_ManaText
			end
			LHT_HideOtherStrings(sb, LHT_ManaText)
			local cur, max = LHT_GetTargetMana()
			if max and max > 0 then
				LHT_ManaText:SetText(cur .. "/" .. max)
				LHT_ManaText:Show()
			else
				LHT_ManaText:SetText("")
				LHT_ManaText:Hide()
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	LHT_EnsureStrings()
	LHT_InstallHook()
end)
LHT_EnsureStrings()
LHT_InstallHook()
