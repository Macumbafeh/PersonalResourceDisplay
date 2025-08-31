-- PersonalResourcesDisplay.lua
-- Standalone version of Personal Resources (originally from KPack)
local ADDON_NAME = ...
local addon = {}

local DB
local defaults = {
    enabled = true,
    combat = false,
    text = true,
    font = "Friz Quadrata TT",
    fontSize = 12,
    fontOutline = "OUTLINE",
    texture = "Blizzard",
    color = {0, 0, 0, 0.5}, -- Background color
    width = 180,
    height = 32,
    scale = 1,
    point = "CENTER",
    xOfs = 0,
    yOfs = -120,
    healthColor = {0.2, 0.7, 0.2, 1}, -- Green
    powerColor = {0.2, 0.2, 0.7, 1},   -- Blue
}

-- Fallback media fetch
local LSM = LibStub("LibSharedMedia-3.0", true)
local function MediaFetch(mediatype, key, default)
    if LSM then
        return LSM:Fetch(mediatype, key) or LSM:Fetch(mediatype, default)
    end
    if mediatype == "font" then
        return "Fonts\\FRIZQT__.TTF"
    elseif mediatype == "statusbar" then
        return "Interface\\TargetingFrame\\UI-StatusBar"
    end
    return default
end

-- Deep copy defaults
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Setup database
local function SetupDatabase()
    if type(PersonalResourcesDB) ~= "table" then
        PersonalResourcesDB = {}
    end
    CopyDefaults(defaults, PersonalResourcesDB)
    DB = PersonalResourcesDB
end

-- Resize the inner bars based on current frame size
local function ResizeBars()
    local f = PersonalResourcesFrame
    if not f or not f.health or not f.power then return end

    local height = f:GetHeight()
    f.health:SetHeight(height * 0.6)
    f.power:SetHeight(height * 0.4)
end

-- Create a status bar with custom color and texture
local function CreateBar(parent, color, texture, name)
    local bar = CreateFrame("StatusBar", name, parent)
    if not bar then
        print("PersonalResourcesDisplay: Failed to create StatusBar")
        return nil
    end

    bar:SetMinMaxValues(0, 100)

    -- Use passed texture or fallback
    local tex = MediaFetch("statusbar", texture or DB.texture, "Blizzard")
    bar:SetStatusBarTexture(tex)

    -- Use passed color or fallback (green/blue)
    local r, g, b = color[1], color[2], color[3]
    bar:SetStatusBarColor(r or 0.2, g or 0.7, b or 0.2)

    -- Background
    local bg = bar:CreateTexture(name .. "BG", "BACKGROUND")
    if bg then
        bg:SetAllPoints(bar)
        local c = DB.color
        bg:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.5)
        bar.bg = bg
    else
        print("PersonalResourcesDisplay: Failed to create BG for", name)
    end

    -- Text
    local text = bar:CreateFontString(name .. "Text", "OVERLAY", "GameFontNormal")
    if text then
        text:SetFont(MediaFetch("font", DB.font, "Friz Quadrata TT"), DB.fontSize, DB.fontOutline)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetPoint("CENTER")
        text:SetText("")
        text:Hide()
        bar.text = text
    else
        print("PersonalResourcesDisplay: Failed to create text for", name)
    end

    return bar
end

-- Update health and power values
local function UpdateBars(self)
    if not self.health or not self.power then
        -- Bars not created yet
        return
    end

    local hp, hpMax = UnitHealth("player"), UnitHealthMax("player")
    local pw, pwMax = UnitPower("player"), UnitPowerMax("player")
    local percentHP = hpMax > 0 and (hp / hpMax) * 100 or 0
    local percentPW = pwMax > 0 and (pw / pwMax) * 100 or 0

    self.health:SetValue(percentHP)
    self.power:SetValue(percentPW)

    if DB.text then
        self.health.text:SetText(string.format("%.0f%%", percentHP))
        self.power.text:SetText(string.format("%.0f%%", percentPW))
        self.health.text:Show()
        self.power.text:Show()
    else
        self.health.text:Hide()
        self.power.text:Hide()
    end
end

-- Refresh bar appearance (texture, color, font, etc.)
local function RefreshBars()
    if not PersonalResourcesFrame or not PersonalResourcesFrame.health or not PersonalResourcesFrame.power then
        return
    end

    local healthBar = PersonalResourcesFrame.health
    local powerBar = PersonalResourcesFrame.power

    -- Update textures
    healthBar:SetStatusBarTexture(MediaFetch("statusbar", DB.texture))
    powerBar:SetStatusBarTexture(MediaFetch("statusbar", DB.texture))

    -- Update colors
    healthBar:SetStatusBarColor(unpack(DB.healthColor))
    powerBar:SetStatusBarColor(unpack(DB.powerColor))

    -- Update background color
    if healthBar.bg then
        healthBar.bg:SetColorTexture(unpack(DB.color))
    end
    if powerBar.bg then
        powerBar.bg:SetColorTexture(unpack(DB.color))
    end

    -- Update text font
    if healthBar.text then
        healthBar.text:SetFont(MediaFetch("font", DB.font), DB.fontSize, DB.fontOutline)
    end
    if powerBar.text then
        powerBar.text:SetFont(MediaFetch("font", DB.font), DB.fontSize, DB.fontOutline)
    end
end

-- Initialize frame
local function Initialize()
    SetupDatabase()

    local f = CreateFrame("Frame", "PersonalResourcesFrame", UIParent)
    if not f then
        print("PersonalResourcesDisplay: Failed to create main frame!")
        return
    end

    f:SetSize(DB.width, DB.height)
    f:SetPoint(DB.point, UIParent, DB.point, DB.xOfs, DB.yOfs)
    f:SetScale(DB.scale)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() or IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        DB.point = point
        DB.xOfs = x
        DB.yOfs = y
    end)

    -- ✅ Delay bar creation until the next frame to ensure parent is valid
    f:HookScript("OnShow", function()
		if f.barsCreated then return end

		-- Create health bar
		f.health = CreateBar(f, DB.healthColor, DB.texture, "PersonalResourcesHealthBar")
		if not f.health then return end
		f.health:SetPoint("TOPLEFT", 2, -2)
		f.health:SetPoint("TOPRIGHT", -2, -2)

		-- Create power bar
		f.power = CreateBar(f, DB.powerColor, DB.texture, "PersonalResourcesPowerBar")
		if not f.power then
			f:Hide()
			return
		end
		f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
		f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)

		f.barsCreated = true

		-- ✅ Now resize based on current DB.height
		ResizeBars()

		RefreshBars()
		print("PersonalResourcesDisplay: Bars created and resized.")
	end)

    -- OnUpdate
    f:SetScript("OnUpdate", function(self, elapsed)
        self.nextUpdate = (self.nextUpdate or 0) + elapsed
        if self.nextUpdate > 0.05 then
            UpdateBars(self)
            self.nextUpdate = 0
        end
    end)

    -- Combat toggle
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function(self, event)
        if DB.combat then
            if event == "PLAYER_REGEN_ENABLED" then
                self:Show()
            elseif event == "PLAYER_REGEN_DISABLED" then
                self:Hide()
            end
        end
    end)

    -- Show/hide based on enabled state
	if DB.enabled then
		f:Show()
		-- If OnShow didn't run (e.g., frame already shown), create bars now
		if not f.barsCreated then
			f:HookScript("OnShow", function()
				if f.barsCreated then return end
				-- Your existing bar creation code
				f.health = CreateBar(f, DB.healthColor, DB.texture, "PersonalResourcesHealthBar")
				if not f.health then return end
				f.health:SetPoint("TOPLEFT", 2, -2)
				f.health:SetPoint("TOPRIGHT", -2, -2)
				f.health:SetHeight(DB.height * 0.6)

				f.power = CreateBar(f, DB.powerColor, DB.texture, "PersonalResourcesPowerBar")
				if not f.power then
					f:Hide()
					return
				end
				f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
				f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)
				f.power:SetHeight(DB.height * 0.4)

				f.barsCreated = true
				RefreshBars()
				print("PersonalResourcesDisplay: Bars created on demand.")
			end)

			-- ✅ Manually trigger OnShow logic if frame is already shown
			if f:IsShown() then
				f:GetScript("OnShow")(f)
			end
		end
	else
		f:Hide()
	end
end

-- Slash command
local function SlashHandler(msg)
    msg = string.lower(msg or "")
    if msg == "toggle" then
        if PersonalResourcesFrame:IsShown() then
            PersonalResourcesFrame:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99PersonalResourcesDisplay:|r Hidden.")
        else
            PersonalResourcesFrame:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99PersonalResourcesDisplay:|r Shown.")
        end
    elseif msg == "config" then
        addon:OpenConfig()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99PersonalResourcesDisplay|r commands:")
        DEFAULT_CHAT_FRAME:AddMessage("/pr toggle - Show/hide the bar")
        DEFAULT_CHAT_FRAME:AddMessage("/pr config - Open configuration")
    end
end



-- AceConfig options
local function GetOptions()
    local options = {
        type = "group",
        name = "Personal Resources Display",
        args = {
            enabled = {
                type = "toggle",
                name = "Enabled",
                desc = "Show the personal resources bar.",
                order = 1,
                get = function() return DB.enabled end,
                set = function(_, v) 
					DB.enabled = v; 
					if PersonalResourcesFrame then 
						if v then
							PersonalResourcesFrame:Show()
						else
							PersonalResourcesFrame:Hide()
						end
					end 
				end,
            },
            combat = {
                type = "toggle",
                name = "Hide in Combat",
                desc = "Hide the bar during combat.",
                order = 2,
                get = function() return DB.combat end,
                set = function(_, v) DB.combat = v end,
            },
            text = {
                type = "toggle",
                name = "Show Percentage Text",
                desc = "Display percentage values on the bars.",
                order = 3,
                get = function() return DB.text end,
                set = function(_, v) DB.text = v end,
            },
            width = {
                type = "range",
                name = "Width",
                desc = "Width of the bar.",
                order = 4,
                min = 50,
                max = 500,
                step = 1,
                get = function() return DB.width end,
                set = function(_, v) DB.width = v; if PersonalResourcesFrame then PersonalResourcesFrame:SetWidth(v) end end,
            },
            height = {
                type = "range",
                name = "Height",
                desc = "Height of the bar.",
                order = 5,
                min = 10,
                max = 100,
                step = 1,
                get = function() return DB.height end,
                set = function(_, v) 
					DB.height = v; 
					if PersonalResourcesFrame then 
						PersonalResourcesFrame:SetHeight(v) 
						ResizeBars()
					end 
				end,
            },
            scale = {
                type = "range",
                name = "Scale",
                desc = "Scale of the bar.",
                order = 6,
                min = 0.5,
                max = 3,
                step = 0.1,
                get = function() return DB.scale end,
                set = function(_, v) DB.scale = v; if PersonalResourcesFrame then PersonalResourcesFrame:SetScale(v) end end,
            },
            font = {
				type = "select",
				name = "Font",
				desc = "Font to use for the text.",
				order = 10,
				values = function() return LSM:List("font") end,
				get = function() return DB.font end,
				set = function(info, v)
					DB.font = v
					RefreshBars()
				end,
			},
            fontSize = {
                type = "range",
                name = "Font Size",
                desc = "Size of the font.",
                order = 11,
                min = 8,
                max = 30,
                step = 1,
                get = function() return DB.fontSize end,
                set = function(_, v) 
					DB.fontSize = v 
					RefreshBars()
				end,
            },
            fontOutline = {
                type = "select",
                name = "Font Outline",
                desc = "Outline style for the font.",
                order = 12,
                values = {
                    NONE = "NONE",
                    OUTLINE = "OUTLINE",
                    THICKOUTLINE = "THICKOUTLINE",
                },
                get = function() return DB.fontOutline end,
                set = function(_, v) 
					DB.fontOutline = v 
					RefreshBars()
				end,
            },
            texture = {
                type = "select",
                name = "Texture",
                desc = "Status bar texture.",
                order = 13,
                values = LSM:List("statusbar"),
                get = function() return DB.texture end,
                set = function(_, v) 
					DB.texture = v 
					RefreshBars()
				end,
            },
            color = {
                type = "color",
                name = "Background Color",
                desc = "Background color of the bar.",
                order = 14,
                hasAlpha = true,
                get = function()
                    return unpack(DB.color)
                end,
                set = function(_, r, g, b, a)
                    DB.color = {r, g, b, a}
					RefreshBars()
                end,
            },
            healthColor = {
                type = "color",
                name = "Health Bar Color",
                desc = "Color of the health bar.",
                order = 15,
                hasAlpha = true,
                get = function()
                    return unpack(DB.healthColor)
                end,
                set = function(_, r, g, b, a)
                    DB.healthColor = {r, g, b, a}
					RefreshBars()
                end,
            },
            powerColor = {
                type = "color",
                name = "Power Bar Color",
                desc = "Color of the power bar.",
                order = 16,
                hasAlpha = true,
                get = function()
                    return unpack(DB.powerColor)
                end,
                set = function(_, r, g, b, a)
                    DB.powerColor = {r, g, b, a}
					RefreshBars()
                end,
            },
        }
    }
    return options
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions)
-- Add to Blizzard Options
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "Personal Resources Display")

-- Open config
function addon:OpenConfig()
    local ACD = LibStub("AceConfigDialog-3.0", true)
    if not ACD then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000PersonalResourcesDisplay:|r AceConfigDialog-3.0 not loaded!")
        return
    end
    ACD:Open(ADDON_NAME)
end

-- Register slash command
SLASH_PERSONALRESOURCESDISPLAY1 = "/pr"
SlashCmdList["PERSONALRESOURCESDISPLAY"] = SlashHandler

-- Load on PLAYER_LOGIN
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == ADDON_NAME then
        Initialize()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        -- Ensure bars are created and shown
        if PersonalResourcesFrame and DB.enabled then
            PersonalResourcesFrame:Show()
            -- Force OnShow if not already created
            if PersonalResourcesFrame:IsShown() and not PersonalResourcesFrame.barsCreated then
                PersonalResourcesFrame:GetScript("OnShow")(PersonalResourcesFrame)
            end
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)