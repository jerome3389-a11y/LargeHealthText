-- LargeHealthText 2.11 - single function: target frame health/mana only.
-- Self-analysis of 2.10 found two bugs (user: analyze, do not test):
-- (1) Hook processes ALL bars, not just target. ShaguTweaks intends that
--     (it shows numbers on player/pet/target), but user wants target
--     ONLY. 2.10 overwrote the player bar text with "cur/max" too.
--     FIX: return early unless sb is TargetFrameHealthBar/ManaBar.
-- (2) Hook + setup installed IMMEDIATELY at file load (early), so the
--     hook is INNER, not outermost. MobInfo2 loads after us (M > L) and
--     installs its hook later, so its post-processing runs AFTER ours
--     and can overwrite our text. ShaguTweaks installs in module.enable
--     (after UI loads, late). FIX: install ONLY on PLAYER_ENTERING_WORLD
--     (late), remove immediate calls. A /reload is needed if the addon
--     is enabled mid-session.
-- Otherwise identical to ShaguTweaks except target-only, MobInfo2
-- memory values, format "cur/max".

local vanilla = true

local function LHT_Setup()
	if not TargetFrame or not TargetFrameHealthBar or not TargetFrameManaBar then return end
	if TargetFrame.StatusTexts then return end
	TargetFrame.StatusTexts = CreateFrame("Frame", nil, TargetFrame)
	TargetFrame.StatusTexts:SetAllPoints(TargetFrame)
	TargetFrameHealthBar.TextString = TargetFrame.StatusTexts:CreateFontString("TargetFrameHealthBarText", "OVERLAY")
	TargetFrameHealthBar.TextString:SetPoint("TOP", TargetFrameHealthBar, "BOTTOM", -2, 23)
	TargetFrameManaBar.TextString = TargetFrame.StatusTexts:CreateFontString("TargetFrameManaBarText", "OVERLAY")
	TargetFrameManaBar.TextString:SetPoint("TOP", TargetFrameManaBar, "BOTTOM", -2, 22)
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
		-- target bars ONLY (bug 1 fix: do not touch player/pet bars)
		if sb ~= TargetFrameHealthBar and sb ~= TargetFrameManaBar then return end
		local string = sb.TextString
		if string and sb.unit then
			-- hide tbc text string element (ShaguTweaks verbatim; skipped in vanilla)
			if not vanilla then
				TargetFrameHealthBarText:Hide()
			end
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

-- install ONLY on PLAYER_ENTERING_WORLD (late, outermost - bug 2 fix).
-- No immediate calls: installing at file load makes the hook inner.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	LHT_Setup()
	LHT_InstallHook()
end)
