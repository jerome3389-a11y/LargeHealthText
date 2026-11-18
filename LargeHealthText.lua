-- LargeHealthText 2.6 - single function: target frame health/mana only.
-- KEY POINT from ShaguTweaks (user: find it in SHAGU, it is written
-- there directly): the system's own display disappears NOT by hiding
-- it, but by REPLACING bar.TextString with a new FontString that has
-- the GLOBAL name "TargetFrameHealthBarText" / "TargetFrameManaBarText",
-- parented to a holder Frame on TargetFrame (not to the bar itself).
-- In Turtle WoW bar.TextString is NIL, so Blizzard's text is shown via
-- that global-named string (or a separate element); creating our own
-- string with the same global name captures it. ShaguTweaks also sets
-- sb.lockShow = 42 and sb:Show() in the hook so the bar stays shown.
-- VALUE (user: needs memory): max from MobInfo2 PPP database
-- (MobHealth_GetTargetMaxHP), percent live from the bar, cur = pct*max/100.
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

-- ShaguTweaks-style setup: holder frame + globally-named strings
local LHT_SetupDone = false
local function LHT_Setup()
	if LHT_SetupDone then return end
	LHT_SetupDone = true
	if not TargetFrame then return end
	-- holder frame on TargetFrame (like ShaguTweaks StatusTexts)
	if not TargetFrame.LHT_StatusTexts then
		TargetFrame.LHT_StatusTexts = CreateFrame("Frame", nil, TargetFrame)
		TargetFrame.LHT_StatusTexts:SetAllPoints(TargetFrame)
	end
	-- health: global name "TargetFrameHealthBarText", parented to holder
	if TargetFrameHealthBar and not TargetFrameHealthBar.TextString then
		TargetFrameHealthBar.TextString = TargetFrame.LHT_StatusTexts:CreateFontString("TargetFrameHealthBarText", "OVERLAY")
		TargetFrameHealthBar.TextString:SetPoint("TOP", TargetFrameHealthBar, "BOTTOM", -2, 23)
	end
	-- mana: global name "TargetFrameManaBarText"
	if TargetFrameManaBar and not TargetFrameManaBar.TextString then
		TargetFrameManaBar.TextString = TargetFrame.LHT_StatusTexts:CreateFontString("TargetFrameManaBarText", "OVERLAY")
		TargetFrameManaBar.TextString:SetPoint("TOP", TargetFrameManaBar, "BOTTOM", -2, 22)
	end
	-- font (ShaguTweaks: GameFontWhite + STANDARD_TEXT_FONT 10 OUTLINE, height 32)
	for _, bar in ipairs({ TargetFrameHealthBar, TargetFrameManaBar }) do
		if bar and bar.TextString then
			bar.TextString:SetFontObject("GameFontWhite")
			bar.TextString:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
			bar.TextString:SetHeight(32)
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
		local string = sb.TextString
		if string and sb.unit then
			-- ShaguTweaks: force the bar (and its text) to stay shown
			sb.lockShow = 42
			sb:Show()
			if sb == TargetFrameHealthBar then
				local cur, max = LHT_GetTargetHealth(sb)
				if max and max > 0 then
					string:SetText(cur .. "/" .. max)
					string:Show()
				else
					string:SetText("")
					string:Hide()
				end
			elseif sb == TargetFrameManaBar then
				local cur, max = LHT_GetTargetMana(sb)
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
	LHT_Setup()
	LHT_InstallHook()
end)
LHT_Setup()
LHT_InstallHook()
