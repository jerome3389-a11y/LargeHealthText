-- LargeHealthText 1.4
-- Large health numbers on player, pet and target unit frames.
-- Extracted from ShaguTweaks "Real Health Numbers" (shagu/ShaguTweaks),
-- standalone, no dependencies. Turtle WoW 1.18.1 / WoW 1.12.
-- Toggle: /lht  (on/off, saved per character account in LargeHealthTextDB)
-- 1.1: optional Nampower support (GetUnitField direct reads, bar fallback).
-- 1.2: pcall GetUnitField; delayed re-apply on target change / entering
-- world; assertive Replace.
-- 1.3: font set on this addon's OWN strings (fix "Font not set");
-- nil-guard pet-bar font setup.
-- 1.4: FIX (a) turning /lht off left two health numbers: Restore put
-- Blizzard's text back but never hid this addon's own string, so both
-- showed. Restore now hides and clears the owned string.
-- FIX (b) target bar never changed: the game / another addon can reset
-- bar.TextString after Apply runs, so the hook now re-asserts ownership
-- on every bar update (if the bar's TextString is not ours, take it
-- back immediately), instead of relying only on event-time Apply.

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

-- Nampower (new DLL): direct memory reads via GetUnitField, fastest and
-- most accurate. Detected once; if absent, fall back to the bar's values
-- (which in Turtle WoW are already real values from the server).
-- Field names verified against Nampower SCRIPTS.md / UNIT_FIELDS.md:
-- health / maxHealth, power1..power5 / maxPower1..maxPower5.
local LHT_UseNampower = (type(GetUnitField) == "function")

-- pcall wrapper: an old Nampower that rejects a field name raises a Lua
-- error; that must fall back to the bar, never break the hook.
local function LHT_SafeGetField(unit, field)
	local ok, val = pcall(GetUnitField, unit, field)
	if ok then return val end
	return nil
end

-- power field for a unit's current power bar (UnitPowerType: 0 mana,
-- 1 rage, 2 focus, 3 energy, 4 happiness)
local function LHT_PowerFields(unit)
	local ptype = UnitPowerType(unit)
	if ptype == 1 then return "power2", "maxPower2"
	elseif ptype == 2 then return "power3", "maxPower3"
	elseif ptype == 3 then return "power4", "maxPower4"
	elseif ptype == 4 then return "power5", "maxPower5"
	else return "power1", "maxPower1" end
end

-- cur/max for a status bar. Prefers Nampower direct reads; falls back to
-- the bar's own values when Nampower is absent, errors, or returns nil.
local function LHT_GetBarValues(sb)
	local cur, max
	if LHT_UseNampower and sb.unit then
		if strfind(sb:GetName(), "Health") then
			cur = LHT_SafeGetField(sb.unit, "health")
			max = LHT_SafeGetField(sb.unit, "maxHealth")
		else
			local curField, maxField = LHT_PowerFields(sb.unit)
			cur = LHT_SafeGetField(sb.unit, curField)
			max = LHT_SafeGetField(sb.unit, maxField)
		end
		if cur and max then return cur, max end
	end
	cur = sb:GetValue()
	local _, maxVal = sb:GetMinMaxValues()
	return cur, maxVal or 0
end

-- only SetText when the text changed (perf: avoids redundant font updates)
local LHT_LastText = {}
local function LHT_SetBarText(fontString, newText)
	if LHT_LastText[fontString] ~= newText then
		LHT_LastText[fontString] = newText
		fontString:SetText(newText)
	end
end

-- saved originals, so /lht off restores Blizzard's text
local LHT_Orig = {}  -- [bar] = original TextString
local LHT_OwnedByBar = {}  -- [bar] = this addon's owned font string
local LHT_Hooked = false
local LHT_OrigUpdate = nil

local function LHT_IsOurs(textString)
	return textString == LHT_TargetHealthText or textString == LHT_TargetManaText
		or textString == LHT_PlayerHealthText or textString == LHT_PlayerManaText
end

-- Take ownership of a bar's TextString. Assertive: if the bar currently
-- shows someone else's string (Blizzard's, or another addon that replaced
-- it), adopt that string as the restore target and put ours on the bar.
-- If the bar has no TextString yet (no target selected), do nothing;
-- the delayed re-apply on target change picks it up.
local function LHT_Replace(bar, owned)
	if not bar or not owned then return end
	local current = bar.TextString
	if current == owned then return end
	if not current then return end
	if not LHT_Orig[bar] then
		LHT_Orig[bar] = current
	end
	bar.TextString = owned
	current:Hide()
	current:SetText("")
end

local function LHT_Restore(bar)
	local orig = LHT_Orig[bar]
	local owned = LHT_OwnedByBar[bar]
	-- Always hide and clear our own string first, or it keeps showing
	-- next to the restored Blizzard text (the "two health numbers"
	-- seen when turning /lht off).
	if owned then
		owned:Hide()
		owned:SetText("")
		LHT_LastText[owned] = nil
	end
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
		LHT_OwnedByBar[TargetFrameHealthBar] = LHT_TargetHealthText
		LHT_OwnedByBar[TargetFrameManaBar] = LHT_TargetManaText
		LHT_OwnedByBar[PlayerFrameHealthBar] = LHT_PlayerHealthText
		LHT_OwnedByBar[PlayerFrameManaBar] = LHT_PlayerManaText
		-- Font goes on THIS addon's own strings. Setting it on the bars'
		-- TextString (Blizzard's original) leaves the owned strings
		-- font-less and every SetText raises "Font not set".
		for _, fontString in pairs({ LHT_TargetHealthText, LHT_TargetManaText, LHT_PlayerHealthText, LHT_PlayerManaText }) do
			fontString:SetFontObject("GameFontWhite")
			fontString:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
			fontString:SetHeight(32)
		end
		-- Pet bars keep Blizzard's TextString; only re-font it, and only
		-- if it exists (nil-safe: a bar with no TextString must not abort Setup).
		for _, frame in pairs({ PetFrameHealthBar, PetFrameManaBar }) do
			if frame and frame.TextString then
				frame.TextString:SetFontObject("GameFontWhite")
				frame.TextString:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
				frame.TextString:SetHeight(32)
				frame.TextString:SetJustifyH("LEFT")
			end
		end
		if PetFrameHealthBar.TextString then
			PetFrameHealthBar.TextString:SetPoint("CENTER", PetFrameHealthBar, "CENTER", -2, 0)
		end
		if PetFrameManaBar.TextString then
			PetFrameManaBar.TextString:SetPoint("CENTER", PetFrameManaBar, "CENTER", -2, -2)
		end
	end
	if not LHT_Hooked then
		LHT_Hooked = true
		LHT_OrigUpdate = TextStatusBar_UpdateTextString
		TextStatusBar_UpdateTextString = function(sb)
			if not sb then sb = this end
			LHT_OrigUpdate(sb)
			if not LargeHealthTextDB.enabled then return end
			-- Re-assert ownership on every update: the game or another
			-- addon can reset bar.TextString after Apply runs, which is
			-- what kept the target bar on Blizzard's default. If this
			-- bar is one of ours and it is not showing our string,
			-- take it back right now.
			local owned = LHT_OwnedByBar[sb]
			if owned and sb.TextString ~= owned then
				LHT_Replace(sb, owned)
			end
			local string = sb.TextString
			if string and sb.unit then
				sb.lockShow = 42
				sb:Show()
				local cur, max = LHT_GetBarValues(sb)
				local percent = max > 0 and math.floor(cur / max * 100) or 0
				if cur == percent and strfind(sb:GetName(), "Health") then
					LHT_SetBarText(string, percent .. "%")
				elseif sb:GetName() == "TargetFrameHealthBar" and cur < max then
					LHT_SetBarText(string, LHT_Abbreviate(cur) .. " - " .. percent .. "%")
				else
					LHT_SetBarText(string, LHT_Abbreviate(cur))
				end
				if max == 0 then
					string:Hide()
					LHT_SetBarText(string, "")
				elseif sb.unit == "target" and UnitIsDead("target") then
					string:Hide()
					LHT_SetBarText(string, "")
				elseif sb.unit == "target" and UnitIsGhost("target") then
					string:Hide()
					LHT_SetBarText(string, "")
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

-- Delayed re-apply (0.2s). Other addons that also replace TextString run
-- their handlers immediately on the same event; the delay lets this addon
-- take the bars back after them, and catches the target bar once its
-- TextString exists after a target is selected.
local lhtTimer = CreateFrame("Frame")
lhtTimer:Hide()
local lhtDelay = 0
lhtTimer:SetScript("OnUpdate", function()
	lhtDelay = lhtDelay - arg1
	if lhtDelay <= 0 then
		lhtTimer:Hide()
		LHT_Apply()
	end
end)
local function LHT_ApplyDelayed()
	lhtDelay = 0.2
	lhtTimer:Show()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		LHT_Setup()
		LHT_Apply()
		LHT_ApplyDelayed()
		if LHT_UseNampower then
			DEFAULT_CHAT_FRAME:AddMessage("LargeHealthText: Nampower detected, using direct reads")
		else
			DEFAULT_CHAT_FRAME:AddMessage("LargeHealthText: Nampower not found, using bar values")
		end
	else
		LHT_ApplyDelayed()
	end
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
