-- LargeHealthText 2.0 - single function: target frame health/mana only.
-- Shows the target's real health and mana as clean "cur/max" on the
-- target frame bars, with no overlapping Blizzard default text.
-- No large text, no player/pet bars, no toggle, no TextString swapping.
-- How it works: hooks TextStatusBar_UpdateTextString LATE (on
-- PLAYER_ENTERING_WORLD, after other addons have hooked), so this
-- addon's text is set last and wins. Values: MobInfo2's learned real
-- health (MobHealth_GetTargetCurHP/MaxHP) first, then Nampower direct
-- memory reads (GetUnitField), then the bar's own values.
-- Turtle WoW 1.18.1 / WoW 1.12.

local function LHT_GetTargetHealth()
	-- MobInfo2 learned real values (same numbers as its "126/126 (100%)" line)
	if type(MobHealth_GetTargetCurHP) == "function" and type(MobHealth_GetTargetMaxHP) == "function" then
		local cur = MobHealth_GetTargetCurHP()
		local max = MobHealth_GetTargetMaxHP()
		if cur and max and max > 0 then return cur, max end
	end
	-- Nampower direct memory read
	if type(GetUnitField) == "function" then
		local ok, cur = pcall(GetUnitField, "target", "health")
		local ok2, max = pcall(GetUnitField, "target", "maxHealth")
		if ok and ok2 and cur and max and max > 0 then return cur, max end
	end
	-- bar values (percent-only for most mobs, but the only fallback)
	if TargetFrameHealthBar then
		local cur = TargetFrameHealthBar:GetValue()
		local _, max = TargetFrameHealthBar:GetMinMaxValues()
		return cur, max or 0
	end
	return 0, 0
end

local function LHT_GetTargetMana()
	if type(GetUnitField) == "function" then
		local ok, cur = pcall(GetUnitField, "target", "power1")
		local ok2, max = pcall(GetUnitField, "target", "maxPower1")
		if ok and ok2 and cur and max and max > 0 then return cur, max end
	end
	if TargetFrameManaBar then
		local cur = TargetFrameManaBar:GetValue()
		local _, max = TargetFrameManaBar:GetMinMaxValues()
		return cur, max or 0
	end
	return 0, 0
end

local LHT_Hooked = false
local function LHT_InstallHook()
	if LHT_Hooked then return end
	LHT_Hooked = true
	local OrigUpdate = TextStatusBar_UpdateTextString
	TextStatusBar_UpdateTextString = function(sb)
		if not sb then sb = this end
		OrigUpdate(sb)
		-- only the target frame bars; player/pet untouched
		if sb == TargetFrameHealthBar then
			local string = sb.TextString
			if string then
				local cur, max = LHT_GetTargetHealth()
				if max and max > 0 then
					string:SetText(cur .. "/" .. max)
					string:Show()
				else
					string:SetText("")
					string:Hide()
				end
			end
		elseif sb == TargetFrameManaBar then
			local string = sb.TextString
			if string then
				local cur, max = LHT_GetTargetMana()
				if max and max > 0 then
					string:SetText(cur .. "/" .. max)
					string:Show()
				else
					string:SetText("")
					string:Hide()
				end
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	LHT_InstallHook()
end)
-- also install immediately in case the world is already entered
LHT_InstallHook()
