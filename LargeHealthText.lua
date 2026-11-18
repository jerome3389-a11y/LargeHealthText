-- LargeHealthText 2.8 - single function: target frame health/mana only.
-- Faithful copy of ShaguTweaks Real Health Numbers (user: learn from
-- SHAGU, stop inventing). Only two changes from ShaguTweaks:
-- (1) target bars only (no player/pet); (2) target health values from
-- MobInfo2 memory (max from PPP database, cur = live percent * max)
-- instead of libhealth, and format is "cur/max" instead of "cur - pct%".
-- Everything else (StatusTexts holder, global names, font loop,
-- lockShow = 42, hook structure, show/hide rules) is ShaguTweaks verbatim.
-- Setup runs on PLAYER_ENTERING_WORLD (after UI loads, like
-- ShaguTweaks module.enable), idempotent so a second run is harmless.

local function LHT_Setup()
	if not TargetFrame or not TargetFrameHealthBar or not TargetFrameManaBar then return end
	if not TargetFrame.StatusTexts then
		TargetFrame.StatusTexts = CreateFrame("Frame", nil, TargetFrame)
		TargetFrame.StatusTexts:SetAllPoints(TargetFrame)
	end
	if not TargetFrameHealthBar.TextString then
		TargetFrameHealthBar.TextString = TargetFrame.StatusTexts:CreateFontString("TargetFrameHealthBarText", "OVERLAY")
		TargetFrameHealthBar.TextString:SetPoint("TOP", TargetFrameHealthBar, "BOTTOM", -2, 23)
	end
	if not TargetFrameManaBar.TextString then
		TargetFrameManaBar.TextString = TargetFrame.StatusTexts:CreateFontString("TargetFrameManaBarText", "OVERLAY")
		TargetFrameManaBar.TextString:SetPoint("TOP", TargetFrameManaBar, "BOTTOM", -2, 22)
	end
	for _, frame in pairs({ TargetFrameHealthBar, TargetFrameManaBar }) do
		frame.TextString:SetFontObject("GameFontWhite")
		frame.TextString:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		frame.TextString:SetHeight(32)
	end
end

local LHT_Hooked = false
local function LHT_InstallHook()
	if LHT_Hooked then return end
	LHT_Hooked = true
	local HookTextStatusBar_UpdateTextString = TextStatusBar_UpdateTextString
	function TextStatusBar_UpdateTextString(sb)
		if not sb then sb = this end
		HookTextStatusBar_UpdateTextString(sb)
		local string = sb.TextString
		if string and sb.unit then
			sb.lockShow = 42
			sb:Show()
			local min, max = sb:GetMinMaxValues()
			local cur = sb:GetValue()
			local percent = max > 0 and floor(cur / max * 100) or 0
			if sb:GetName() == "TargetFrameHealthBar" then
				-- MobInfo2 memory (replaces libhealth): max from database
				local mmax = nil
				if type(MobHealth_GetTargetMaxHP) == "function" then
					mmax = MobHealth_GetTargetMaxHP()
				end
				if mmax and mmax > 0 then
					max = mmax
					cur = math.floor(percent * max / 100 + 0.5)
				end
			end
			-- format: always "cur/max" (user wants 141/172, not "141 - 82%")
			string:SetText(cur .. "/" .. max)
			if max == 0 then
				string:Hide()
				string:SetText("")
			elseif sb.unit == "target" and UnitIsDead("target") then
				string:Hide()
				string:SetText("")
			elseif sb.unit == "target" and UnitIsGhost("target") then
				string:Hide()
				string:SetText("")
			else
				string:Show()
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
-- also try immediately in case the world is already entered
LHT_Setup()
LHT_InstallHook()
