-- LargeHealthText 2.5 - single function: target frame health/mana only.
-- Turtle WoW: TargetFrameHealthBar.TextString is NIL even with a target
-- (confirmed by /run diagnostic 2026-11-18 22:09). Creates its own
-- FontString and assigns it when nil; hides Blizzard's other strings.
-- VALUE (user correction 2026-11-18 22:21, two problems):
-- (1) it NEEDS memory: the real max comes from MobInfo2's PPP database
--     (MobHealth_GetTargetMaxHP). At full health the percent is 100, so
--     without the learned max you cannot know the real value. 2.1 used
--     MobHealth_GetTargetCurHP which used a STALE percent (100) and gave
--     172/172 instead of 141/172. 2.5 takes max from the database but
--     takes the percent LIVE from the bar itself (sb:GetValue, current
--     after OrigUpdate), so cur = percent * max / 100 is correct.
-- (2) Blizzard's own "82%" / "82" still shows: hide other FontStrings
--     on the bar AND percent-like strings on TargetFrame.
-- No large text, no player/pet, no toggle.

local function LHT_GetTargetHealth(sb)
	-- max from MobInfo2 memory (learned PPP database)
	local max = nil
	if type(MobHealth_GetTargetMaxHP) == "function" then
		max = MobHealth_GetTargetMaxHP()
	end
	if max and max > 0 then
		-- live percent from the bar (current, not stale)
		local percent = nil
		if sb and sb.GetValue then
			percent = sb:GetValue()
		elseif TargetFrameHealthBar then
			percent = TargetFrameHealthBar:GetValue()
		end
		if not percent then
			percent = UnitHealth("target")
		end
		if percent then
			local cur = math.floor(percent * max / 100 + 0.5)
			return cur, max
		end
	end
	-- fallback: Nampower live fields
	if type(GetUnitField) == "function" then
		local ok, cur = pcall(GetUnitField, "target", "health")
		local ok2, m = pcall(GetUnitField, "target", "maxHealth")
		if ok and ok2 and cur and m and m > 0 then return cur, m end
	end
	return 0, 0
end

local function LHT_GetTargetMana(sb)
	if type(GetUnitField) == "function" then
		local ok, cur = pcall(GetUnitField, "target", "power1")
		local ok2, max = pcall(GetUnitField, "target", "maxPower1")
		if ok and ok2 and cur and max and max > 0 then return cur, max end
	end
	if sb and sb.GetValue then
		local cur = sb:GetValue()
		local _, max = sb:GetMinMaxValues()
		return cur, max or 0
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
	-- also hide percent-like strings on TargetFrame itself (e.g. "82%")
	if TargetFrame and TargetFrame.GetRegions then
		local fr = { TargetFrame:GetRegions() }
		for _, r in ipairs(fr) do
			if r and r ~= keep and r.GetObjectType and r:GetObjectType() == "FontString" and r.GetText then
				local t = r:GetText()
				if t and string.find(t, "%%") then
					r:SetText("")
					r:Hide()
				end
			end
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
			local cur, max = LHT_GetTargetHealth(sb)
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
			local cur, max = LHT_GetTargetMana(sb)
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
