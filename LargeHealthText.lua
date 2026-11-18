-- LargeHealthText 1.0
-- Large health numbers on player, pet and target unit frames.
-- Extracted from ShaguTweaks "Real Health Numbers" (shagu/ShaguTweaks),
-- standalone, no dependencies. Turtle WoW 1.18.1 / WoW 1.12.
-- Toggle: /lht  (on/off, saved per character account in LargeHealthTextDB)

if not LargeHealthTextDB then LargeHealthTextDB = { enabled = true } end

-- abbreviate a large number, ShaguTweaks style:
-- 1160 stays "1160", 12500 becomes "12.5k", 1500000 becomes "1.5m"
local function LHT_Abbreviate(value)
	value = math.floor(value + 0.5)
	if value >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	elseif value >= 10000 then
		return string.format("%.1fk", value / 1000)
	else
		return tostring(value)
	end
end

-- saved originals, so /lht off restores Blizzard's text
local LHT_Orig = {}  -- [bar] = original TextString
local LHT_Hooked = false
local LHT_OrigUpdate = nil

local function LHT_IsOurs(textString)
	return textString == LHT_TargetHealthText or textString == LHT_TargetManaText
		or textString == LHT_PlayerHealthText or textString == LHT_PlayerManaText
end

local function LHT_Replace(bar, owned)
	if not bar then return end
	if not LHT_Orig[bar] then
		local current = bar.TextString
		if not current or current == owned then return end
		LHT_Orig[bar] = current
	end
	if bar.TextString == LHT_Orig[bar] then
		bar.TextString = owned
		LHT_Orig[bar]:Hide()
		LHT_Orig[bar]:SetText("")
	end
end

local function LHT_Restore(bar)
	local orig = LHT_Orig[bar]
	if orig and bar.TextString ~= orig and not LHT_IsOurs(bar.TextString) then
		-- someone else owns it now, leave it alone
		return
	end
	if orig and bar.TextString ~= orig then
		bar.TextString = orig
		TextStatusBar_UpdateTextString(bar)
	end
end

local function LHT_Setup()
	if not LHT_TargetHealthText then
		local targetTexts = CreateFrame("Frame", nil, TargetFrame)
		targetTexts:SetAllPoints(TargetFrame)
		LHT_TargetHealthText = targetTexts:CreateFontString("LHT_TargetHealthBarText", "OVERLAY")
		LHT_TargetHealthText:SetPoint("TOP", TargetFrameHealthBar, "BOTTOM", -2, 23)
		LHT_TargetManaText = targetTexts:CreateFontString("LHT_TargetManaBarText", "OVERLAY")
		LHT_TargetManaText:SetPoint("TOP", TargetFrameManaBar, "BOTTOM", -2, 22)
		local playerTexts = CreateFrame("Frame", nil, PlayerFrame)
		playerTexts:SetAllPoints(PlayerFrame)
		LHT_PlayerHealthText = playerTexts:CreateFontString("LHT_PlayerHealthBarText", "OVERLAY")
		LHT_PlayerHealthText:SetPoint("CENTER", PlayerFrameHealthBar, "CENTER", 0, 0)
		LHT_PlayerManaText = playerTexts:CreateFontString("LHT_PlayerManaBarText", "OVERLAY")
		LHT_PlayerManaText:SetPoint("CENTER", PlayerFrameManaBar, "CENTER", 0, 0)
		for _, frame in pairs({ TargetFrameHealthBar, TargetFrameManaBar, PlayerFrameHealthBar, PlayerFrameManaBar }) do
			frame.TextString:SetFontObject("GameFontWhite")
			frame.TextString:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
			frame.TextString:SetHeight(32)
		end
		for _, frame in pairs({ PetFrameHealthBar, PetFrameManaBar }) do
			frame.TextString:SetFontObject("GameFontWhite")
			frame.TextString:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
			frame.TextString:SetHeight(32)
			frame.TextString:SetJustifyH("LEFT")
		end
		PetFrameHealthBar.TextString:SetPoint("CENTER", PetFrameHealthBar, "CENTER", -2, 0)
		PetFrameManaBar.TextString:SetPoint("CENTER", PetFrameManaBar, "CENTER", -2, -2)
	end
	if not LHT_Hooked then
		LHT_Hooked = true
		LHT_OrigUpdate = TextStatusBar_UpdateTextString
		TextStatusBar_UpdateTextString = function(sb)
			if not sb then sb = this end
			LHT_OrigUpdate(sb)
			if not LargeHealthTextDB.enabled then return end
			local string = sb.TextString
			if string and sb.unit then
				sb.lockShow = 42
				sb:Show()
				local min, max = sb:GetMinMaxValues()
				local cur = sb:GetValue()
				local percent = max > 0 and math.floor(cur / max * 100) or 0
				if cur == percent and strfind(sb:GetName(), "Health") then
					string:SetText(percent .. "%")
				elseif sb:GetName() == "TargetFrameHealthBar" and cur < max then
					string:SetText(LHT_Abbreviate(cur) .. " - " .. percent .. "%")
				else
					string:SetText(LHT_Abbreviate(cur))
				end
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
end

local function LHT_Apply()
	if not LHT_TargetHealthText then return end
	if LargeHealthTextDB.enabled then
		LHT_Replace(TargetFrameHealthBar, LHT_TargetHealthText)
		LHT_Replace(TargetFrameManaBar, LHT_TargetManaText)
		LHT_Replace(PlayerFrameHealthBar, LHT_PlayerHealthText)
		LHT_Replace(PlayerFrameManaBar, LHT_PlayerManaText)
	else
		LHT_Restore(TargetFrameHealthBar)
		LHT_Restore(TargetFrameManaBar)
		LHT_Restore(PlayerFrameHealthBar)
		LHT_Restore(PlayerFrameManaBar)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
	LHT_Setup()
	LHT_Apply()
end)

SLASH_LARGEHEALTHTEXT1 = "/lht"
SlashCmdList["LARGEHEALTHTEXT"] = function(msg)
	LargeHealthTextDB.enabled = not LargeHealthTextDB.enabled
	LHT_Apply()
	if LargeHealthTextDB.enabled then
		DEFAULT_CHAT_FRAME:AddMessage("Large Health Text: on")
	else
		DEFAULT_CHAT_FRAME:AddMessage("Large Health Text: off")
	end
end
