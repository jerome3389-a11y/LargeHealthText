-- LargeHealthText 2.7 - single function: target frame health/mana only.
-- 2.6 failed ("system still there, addon does not show"): setup ran at
-- load time with a LHT_SetupDone flag that blocked re-run, so if
-- TargetFrameHealthBar was not ready yet the strings were never created,
-- and the hook never re-assigned them. 2.7 does LAZY setup inside the
-- hook: on the first bar update (when the bar definitely exists) create
-- the ShaguTweaks-style globally-named FontString on a holder frame and
-- assign it to bar.TextString; re-assign on every update so it sticks
-- even if the game resets TextString. Also sets lockShow = 42.
-- VALUE: max from MobInfo2 PPP memory, percent live from the bar.
-- No large text, no player/pet, no toggle.

local function LHT_GetTargetHealth(sb)
	local max = nil
	if type(MobHealth_GetTargetMaxHP) == "function" then
		max = MobHealth_GetTargetMaxHP()
	end
	if max and max > 0 then
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

-- owned strings (ShaguTweaks-style: global name, holder frame)
local LHT_HealthText = nil
local LHT_ManaText = nil
local function LHT_EnsureStrings()
	if not TargetFrame then return end
	if not TargetFrame.LHT_StatusTexts then
		TargetFrame.LHT_StatusTexts = CreateFrame("Frame", nil, TargetFrame)
		TargetFrame.LHT_StatusTexts:SetAllPoints(TargetFrame)
	end
	if not LHT_HealthText and TargetFrameHealthBar then
		LHT_HealthText = TargetFrame.LHT_StatusTexts:CreateFontString("TargetFrameHealthBarText", "OVERLAY")
		LHT_HealthText:SetPoint("TOP", TargetFrameHealthBar, "BOTTOM", -2, 23)
		LHT_HealthText:SetFontObject("GameFontWhite")
		LHT_HealthText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		LHT_HealthText:SetHeight(32)
	end
	if not LHT_ManaText and TargetFrameManaBar then
		LHT_ManaText = TargetFrame.LHT_StatusTexts:CreateFontString("TargetFrameManaBarText", "OVERLAY")
		LHT_ManaText:SetPoint("TOP", TargetFrameManaBar, "BOTTOM", -2, 22)
		LHT_ManaText:SetFontObject("GameFontWhite")
		LHT_ManaText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		LHT_ManaText:SetHeight(32)
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
		if sb == TargetFrameHealthBar or sb == TargetFrameManaBar then
			-- lazy setup: bar definitely exists here
			LHT_EnsureStrings()
			local owned = (sb == TargetFrameHealthBar) and LHT_HealthText or LHT_ManaText
			if owned then
				-- re-assign every time so it sticks
				if sb.TextString ~= owned then
					sb.TextString = owned
				end
				sb.lockShow = 42
				sb:Show()
				local cur, max
				if sb == TargetFrameHealthBar then
					cur, max = LHT_GetTargetHealth(sb)
				else
					cur, max = LHT_GetTargetMana(sb)
				end
				if max and max > 0 then
					owned:SetText(cur .. "/" .. max)
					owned:Show()
				else
					owned:SetText("")
					owned:Hide()
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
LHT_InstallHook()
