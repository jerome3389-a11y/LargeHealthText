-- LargeHealthText 2.12 - single function: target frame health/mana only.
-- User tested 2.11: "系统还在" - Blizzard's "82%"/"82" still shows.
-- Root cause (from the diagnostic): in Turtle WoW, bar.TextString is NIL.
-- So the game's own TextStatusBar_UpdateTextString does NOTHING for the
-- target bar (it uses sb.TextString). The "82%" text is NOT set via
-- bar.TextString - it is rendered by a FontString the game (or another
-- addon) holds directly, parented to the bar or the frame. Replacing
-- bar.TextString (ShaguTweaks' mechanism) cannot orphan it, because it
-- was never assigned to bar.TextString in the first place.
-- FIX: find and hide the actual rendering FontString(s). After creating
-- our owned strings, enumerate the bar's and the frame's regions and
-- hide every FontString that is not ours. Re-assert in the hook (the
-- game may re-show it or create it on target change). Our owned strings
-- are the only FontStrings left visible on the bar. MobInfo2's own
-- strings are parented to its own holder frame, not to the bar, so they
-- are not touched.
-- Setup/hook timing stays late (PLAYER_ENTERING_WORLD, outermost).
-- Values still MobInfo2 memory, format still "cur/max", target only.

local vanilla = true

local LHT_Owned = {}

local function LHT_HideOthers()
	for _, bar in pairs({ TargetFrameHealthBar, TargetFrameManaBar }) do
		if bar then
			local regions = { bar:GetRegions() }
			for _, r in ipairs(regions) do
				if r and r.IsObjectType and r:IsObjectType("FontString") and not LHT_Owned[r] then
					r:Hide()
					r:SetText("")
				end
			end
		end
	end
	if TargetFrame then
		local children = { TargetFrame:GetChildren() }
		for _, child in ipairs(children) do
			if child and child.IsObjectType and child:IsObjectType("FontString") and not LHT_Owned[child] then
				-- only hide FontStrings that sit on/near the bars (not the name text)
				local name = child:GetName()
				if name and (string.find(name, "HealthBar") or string.find(name, "ManaBar")) then
					child:Hide()
					child:SetText("")
				end
			end
		end
		local regions = { TargetFrame:GetRegions() }
		for _, r in ipairs(regions) do
			if r and r.IsObjectType and r:IsObjectType("FontString") and not LHT_Owned[r] then
				local name = r:GetName()
				if name and (string.find(name, "HealthBar") or string.find(name, "ManaBar")) then
					r:Hide()
					r:SetText("")
				end
			end
		end
	end
end

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
		LHT_Owned[frame.TextString] = true
	end
	LHT_HideOthers()
end

local LHT_Hooked = false
local function LHT_InstallHook()
	if LHT_Hooked then return end
	LHT_Hooked = true
	local HookTextStatusBar_UpdateTextString = TextStatusBar_UpdateTextString
	function TextStatusBar_UpdateTextString(sb)
		if not sb then sb = this end
		HookTextStatusBar_UpdateTextString(sb)
		if sb ~= TargetFrameHealthBar and sb ~= TargetFrameManaBar then return end
		local string = sb.TextString
		if string and sb.unit then
			if not vanilla then
				TargetFrameHealthBarText:Hide()
			end
			sb.lockShow = 42
			sb:Show()
			local min, max = sb:GetMinMaxValues()
			local cur = sb:GetValue()
			local percent = max > 0 and floor(cur / max * 100) or 0
			if sb:GetName() == "TargetFrameHealthBar" then
				local mmax = nil
				if type(MobHealth_GetTargetMaxHP) == "function" then
					mmax = MobHealth_GetTargetMaxHP()
				end
				if mmax and mmax > 0 then
					max = mmax
					cur = math.floor(percent * max / 100 + 0.5)
				end
			end
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
			-- re-hide any other FontString the game re-showed (target change)
			LHT_HideOthers()
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	LHT_Setup()
	LHT_InstallHook()
end)
