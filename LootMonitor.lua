local strfind = string.find
local strlower = string.lower
local strsub = string.sub
local strformat = string.format
local strgsub = string.gsub
local strlen = string.len
local tinsert = table.insert
local tremove = table.remove
local tgetn = table.getn
local mathmod = math.mod
local gettime = GetTime
local tonumber = tonumber
local tostring = tostring
local getglobal = getglobal
local pairs = pairs
local ipairs = ipairs
local type = type

local CreateFrame = CreateFrame
local GetTime = GetTime
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemInfo = GetContainerItemInfo
local UIParent = UIParent
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

local TEXTURE_PATH_QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local COIN_ICON_COPPER = "Interface\\Icons\\INV_Misc_Coin_01"
local COIN_ICON_SILVER = "Interface\\Icons\\INV_Misc_Coin_03"
local COIN_ICON_GOLD = "Interface\\Icons\\INV_Misc_Coin_05"
local BACKGROUND_TEXTURE = "Interface\\TransmogFrame\\anim\\loot_frame_xmog_30.blp"

local BACKGROUND_ANIMATION_FRAMES = 30
local BACKGROUND_ANIMATION_FRAME_DURATION = 0.05
local BACKGROUND_ANIMATION_TOTAL_DURATION = BACKGROUND_ANIMATION_FRAMES * BACKGROUND_ANIMATION_FRAME_DURATION

local QUALITY_COLORS = {
	[0] = { 1.00, 1.00, 1.00 },
	[1] = { 1.00, 1.00, 1.00 },
	[2] = { 0.12, 1.00, 0.00 },
	[3] = { 0.00, 0.44, 0.87 },
	[4] = { 0.64, 0.21, 0.93 },
	[5] = { 1.00, 0.50, 0.00 },
}

local LOOT_CELEBRATION_ITEMS = {
	"正义宝珠",
	"骨火",
	"黑莲花",
	"奥术水晶",
	"恶魔布",
	"提布的炽炎长剑",
	"瑞文戴尔之剑",
	"克罗之刃",
	"泰坦合剂",
	"超级能量合剂",
	"精炼智慧合剂",
}

local COIN_SCALE_FACTOR = 0.8
local COIN_FADEIN_FACTOR = 1.0
local COIN_DISPLAY_FACTOR = 1.0
local COIN_FADEOUT_FACTOR = 1.0

local YOU_RECEIVE_PATTERNS = {
	"你获得了物品：",
	"你得到了物品：",
	"你获得了",
	"你得到了",
	"你拾取了",
	"你制造了",
	"你赢得了",
}
local BRACKET_OPEN = "%["
local BRACKET_CLOSE = "%]"

LootMonitor = {}
LootMonitor.activeNotifications = {}
LootMonitor.maxNotifications = 5
LootMonitor.frame = nil
LootMonitor.moveFrame = nil
LootMonitor.moveMode = false
LootMonitor.settingsFrame = nil
LootMonitor.keyboardFrame = nil
LootMonitor.settingsMoveBtn = nil

local function Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[战利品监控]|r " .. msg)
	end
end

function LootMonitor:ExtractQuantityFromMessageCN(message, startPos)
	if not message or not startPos then
		return 1
	end

	local xPos = strfind(message, "x", startPos)
	if xPos then
		local numberStart = xPos + 1
		local numberEnd = numberStart
		while numberEnd <= strlen(message) do
			local char = strsub(message, numberEnd, numberEnd)
			if char >= "0" and char <= "9" then
				numberEnd = numberEnd + 1
			else
				break
			end
		end
		if numberEnd > numberStart then
			local quantityStr = strsub(message, numberStart, numberEnd - 1)
			local quantity = tonumber(quantityStr)
			if quantity and quantity > 0 then
				return quantity
			end
		end
	end

	local numPattern = "(%d+)个"
	local _, _, quantityStr = strfind(message, numPattern)
	if quantityStr then
		local quantity = tonumber(quantityStr)
		if quantity and quantity > 0 then
			return quantity
		end
	end

	local colonXPattern = "：(%d+)x"
	local _, _, quantityStr = strfind(message, colonXPattern)
	if quantityStr then
		local quantity = tonumber(quantityStr)
		if quantity and quantity > 0 then
			return quantity
		end
	end

	local parenPattern = "%((%d+)%)"
	local _, _, quantityStr = strfind(message, parenPattern)
	if quantityStr then
		local quantity = tonumber(quantityStr)
		if quantity and quantity > 0 then
			return quantity
		end
	end

	return 1
end

function LootMonitor:IsCoinMessageCN(message)
	return strfind(message, "%d+金") or strfind(message, "%d+银") or strfind(message, "%d+铜")
end

function LootMonitor:ProcessCoinMessage(message)
	if not message then
		return
	end
	local goldAmount, silverAmount, copperAmount = 0, 0, 0
	local pattern = "(%d+)[%s,]*金[^%d]*(%d+)[%s,]*银[^%d]*(%d+)[%s,]*铜"
	local _, _, goldStr, silverStr, copperStr = strfind(message, pattern)
	if goldStr and silverStr and copperStr then
		goldAmount = tonumber(goldStr) or 0
		silverAmount = tonumber(silverStr) or 0
		copperAmount = tonumber(copperStr) or 0
	else
		pattern = "(%d+)[%s,]*金[^%d]*(%d+)[%s,]*银"
		_, _, goldStr, silverStr = strfind(message, pattern)
		if goldStr and silverStr then
			goldAmount = tonumber(goldStr) or 0
			silverAmount = tonumber(silverStr) or 0
		else
			pattern = "(%d+)[%s,]*金[^%d]*(%d+)[%s,]*铜"
			_, _, goldStr, copperStr = strfind(message, pattern)
			if goldStr and copperStr then
				goldAmount = tonumber(goldStr) or 0
				copperAmount = tonumber(copperStr) or 0
			else
				pattern = "(%d+)[%s,]*银[^%d]*(%d+)[%s,]*铜"
				_, _, silverStr, copperStr = strfind(message, pattern)
				if silverStr and copperStr then
					silverAmount = tonumber(silverStr) or 0
					copperAmount = tonumber(copperStr) or 0
				else
					pattern = "(%d+)[%s,]*金"
					_, _, goldStr = strfind(message, pattern)
					if goldStr then
						goldAmount = tonumber(goldStr) or 0
					end
					pattern = "(%d+)[%s,]*银"
					_, _, silverStr = strfind(message, pattern)
					if silverStr then
						silverAmount = tonumber(silverStr) or 0
					end
					pattern = "(%d+)[%s,]*铜"
					_, _, copperStr = strfind(message, pattern)
					if copperStr then
						copperAmount = tonumber(copperStr) or 0
					end
				end
			end
		end
	end

	local existingCoinNotification = nil
	local activeList = self.activeNotifications
	for i = 1, tgetn(activeList) do
		local notification = activeList[i]
		if notification.isCoin and not notification.fadingOut then
			existingCoinNotification = notification
			break
		end
	end

	if existingCoinNotification then
		local totalCopper = (existingCoinNotification.copper or 0) + copperAmount
		local totalSilver = (existingCoinNotification.silver or 0) + silverAmount
		local totalGold = (existingCoinNotification.gold or 0) + goldAmount

		if totalCopper >= 100 then
			totalSilver = totalSilver + math.floor(totalCopper / 100)
			totalCopper = math.mod(totalCopper, 100)
		end

		if totalSilver >= 100 then
			totalGold = totalGold + math.floor(totalSilver / 100)
			totalSilver = math.mod(totalSilver, 100)
		end

		existingCoinNotification.gold = totalGold
		existingCoinNotification.silver = totalSilver
		existingCoinNotification.copper = totalCopper

		local coinText = ""
		if totalGold > 0 then
			coinText = coinText .. totalGold .. "金"
		end
		if totalSilver > 0 then
			coinText = coinText .. totalSilver .. "银"
		end
		if totalCopper > 0 then
			coinText = coinText .. totalCopper .. "铜"
		end

		existingCoinNotification.name = coinText
		existingCoinNotification.startTime = gettime()
		existingCoinNotification.count = 1

		self:UpdateNotificationText(existingCoinNotification)

		self:MoveCoinNotificationToTop(existingCoinNotification)
	else
		local totalCopper = copperAmount
		local totalSilver = silverAmount
		local totalGold = goldAmount

		if totalCopper >= 100 then
			totalSilver = totalSilver + math.floor(totalCopper / 100)
			totalCopper = math.mod(totalCopper, 100)
		end

		if totalSilver >= 100 then
			totalGold = totalGold + math.floor(totalSilver / 100)
			totalSilver = math.mod(totalSilver, 100)
		end

		local coinText = ""
		if totalGold > 0 then
			coinText = coinText .. totalGold .. "金"
		end
		if totalSilver > 0 then
			coinText = coinText .. totalSilver .. "银"
		end
		if totalCopper > 0 then
			coinText = coinText .. totalCopper .. "铜"
		end

		if coinText ~= "" then
			self:AddLootItem(coinText, true, 1, true, totalGold, totalSilver, totalCopper)
		end
	end
end

function LootMonitor:ProcessLootMessageCN(message)
	if not message or not LootMonitorDB.enabled then
		return
	end
	if self:IsCoinMessageCN(message) then
		self:ProcessCoinMessage(message)
		return
	end
	local isReceiveMessage = false
	for i = 1, tgetn(YOU_RECEIVE_PATTERNS) do
		if strfind(message, YOU_RECEIVE_PATTERNS[i]) then
			isReceiveMessage = true
			break
		end
	end
	if isReceiveMessage then
		local linkStart = strfind(message, "|c")
		if linkStart then
			local hStart = strfind(message, "|H", linkStart)
			if hStart then
				local linkEnd = strfind(message, "|r", hStart)
				if linkEnd then
					local itemLink = strsub(message, linkStart, linkEnd + 1)
					if strfind(itemLink, "|Hitem:") then
						local quantity = self:ExtractQuantityFromMessageCN(message, linkEnd + 2)
						self:AddLootItem(itemLink, false, quantity)
						return
					end
				end
			end
		end
		local bracketStart = strfind(message, BRACKET_OPEN)
		if bracketStart then
			local bracketEnd = strfind(message, BRACKET_CLOSE, bracketStart)
			if bracketEnd then
				local itemName = strsub(message, bracketStart + 1, bracketEnd - 1)
				local quantity = self:ExtractQuantityFromMessageCN(message, bracketEnd + 1)
				self:AddLootItem(itemName, true, quantity)
			end
		end
	end
end

function LootMonitor:ProcessSystemMessageCN(message)
	if not message or not LootMonitorDB.enabled then
		return
	end
	if self:IsCoinMessageCN(message) then
		self:ProcessCoinMessage(message)
		return
	end
	if
		strfind(message, "获得物品")
		or strfind(message, "你获得了")
		or strfind(message, "你得到了")
		or strfind(message, "你拾取了")
		or strfind(message, "你制造了")
		or strfind(message, "获得")
		or strfind(message, "你赢得了")
	then
		local linkStart = strfind(message, "|c")
		if linkStart then
			local hStart = strfind(message, "|H", linkStart)
			if hStart then
				local linkEnd = strfind(message, "|r", hStart)
				if linkEnd then
					local itemLink = strsub(message, linkStart, linkEnd + 1)
					if strfind(itemLink, "|Hitem:") then
						local quantity = self:ExtractQuantityFromMessageCN(message, linkEnd + 2)
						self:AddLootItem(itemLink, false, quantity)
						return
					end
				end
			end
		end

		local bracketStart = strfind(message, "%[")
		if bracketStart then
			local bracketEnd = strfind(message, "%]", bracketStart)
			if bracketEnd then
				local itemName = strsub(message, bracketStart + 1, bracketEnd - 1)
				local quantity = self:ExtractQuantityFromMessageCN(message, bracketEnd + 1)
				self:AddLootItem(itemName, true, quantity)
				return
			end
		end

		if strfind(message, "你制造了：") then
			local colonPattern = "你制造了：%[(.-)%]"
			local _, _, itemName = strfind(message, colonPattern)
			if itemName then
				self:AddLootItem(itemName, true, 1)
				return
			end
		end

		if strfind(message, "你赢得了：") then
			local winPattern = "你赢得了：%[(.-)%]"
			local _, _, itemName = strfind(message, winPattern)
			if itemName then
				self:AddLootItem(itemName, true, 1)
				return
			end
		end
	end
end

function LootMonitor:CheckLootCelebration(itemName)
	if not itemName then
		return
	end
	for _, name in ipairs(LOOT_CELEBRATION_ITEMS) do
		if strfind(itemName, name) then
			DoEmote("CHEER")
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage("|cFF0070DD[稀有物品]|r " .. itemName)
			end
			return true
		end
	end
end

function LootMonitor:AddLootItem(itemData, isNameOnly, quantity, isCoin, gold, silver, copper)
	if not LootMonitorDB.enabled then
		return
	end
	local itemName
	local actualQuantity = quantity or 1
	if not isNameOnly then
		local bracketStart = strfind(itemData, BRACKET_OPEN)
		local bracketEnd = strfind(itemData, BRACKET_CLOSE)
		if bracketStart and bracketEnd then
			itemName = strsub(itemData, bracketStart + 1, bracketEnd - 1)
		else
			itemName = "未知物品"
		end
	else
		itemName = itemData
	end

	local existingNotification = nil
	local activeList = self.activeNotifications

	if isCoin then
		for i = 1, tgetn(activeList) do
			local notification = activeList[i]
			if notification.isCoin and not notification.fadingOut then
				existingNotification = notification
				break
			end
		end
	else
		for i = 1, tgetn(activeList) do
			local notification = activeList[i]
			if notification.name == itemName and not notification.fadingOut then
				existingNotification = notification
				break
			end
		end
	end

	if existingNotification then
		if isCoin then
			local totalCopper = (existingNotification.copper or 0) + (copper or 0)
			local totalSilver = (existingNotification.silver or 0) + (silver or 0)
			local totalGold = (existingNotification.gold or 0) + (gold or 0)

			if totalCopper >= 100 then
				totalSilver = totalSilver + math.floor(totalCopper / 100)
				totalCopper = math.mod(totalCopper, 100)
			end

			if totalSilver >= 100 then
				totalGold = totalGold + math.floor(totalSilver / 100)
				totalSilver = math.mod(totalSilver, 100)
			end

			existingNotification.gold = totalGold
			existingNotification.silver = totalSilver
			existingNotification.copper = totalCopper

			local coinText = ""
			if totalGold > 0 then
				coinText = coinText .. totalGold .. "金"
			end
			if totalSilver > 0 then
				coinText = coinText .. totalSilver .. "银"
			end
			if totalCopper > 0 then
				coinText = coinText .. totalCopper .. "铜"
			end

			existingNotification.name = coinText
		else
			existingNotification.count = existingNotification.count + actualQuantity
		end

		existingNotification.startTime = gettime()
		self:UpdateNotificationText(existingNotification)

		if isCoin then
			self:MoveCoinNotificationToTop(existingNotification)
		end
	else
		self:CheckLootCelebration(itemName)
		self:CreateLootNotification(itemName, actualQuantity, itemData, isNameOnly, isCoin, gold, silver, copper)
	end
end

function LootMonitor:MoveCoinNotificationToTop(coinNotification)
	local activeList = self.activeNotifications

	for i = 1, tgetn(activeList) do
		if activeList[i] == coinNotification then
			if i > 1 then
				tremove(activeList, i)
				tinsert(activeList, 1, coinNotification)
				self:RepositionNotifications()
			end
			break
		end
	end
end

local defaults = {
	enabled = true,
	scale = 4.9,
	fadeInTime = 0.3,
	displayTime = 5.0,
	fadeOutTime = 1.0,
	showTotalCount = true,
	fontSize = 14,
	maxNotifications = 5,
	backgroundAnimation = true,
	position = { point = "CENTER", x = 200, y = 100 },
}

function LootMonitor:OnLoad()
	if not LootMonitorDB then
		LootMonitorDB = {}
	end
	for key, value in pairs(defaults) do
		if LootMonitorDB[key] == nil then
			if key == "position" then
				LootMonitorDB[key] = { point = value.point, x = value.x, y = value.y }
			else
				LootMonitorDB[key] = value
			end
		elseif key == "position" and LootMonitorDB[key] then
			if not LootMonitorDB[key].point then
				LootMonitorDB[key].point = value.point
			end
			if LootMonitorDB[key].x == nil then
				LootMonitorDB[key].x = value.x
			end
			if LootMonitorDB[key].y == nil then
				LootMonitorDB[key].y = value.y
			end
		end
	end
	self.maxNotifications = LootMonitorDB.maxNotifications or defaults.maxNotifications
	self:CreateNotificationFrame()
	Print("插件已加载！战利品通知已启用。")
end

function LootMonitor:SavePosition()
	if self.frame then
		local point, relativeTo, relativePoint, x, y = self.frame:GetPoint()
		if point and x and y then
			if not LootMonitorDB.position then
				LootMonitorDB.position = {}
			end
			LootMonitorDB.position.point = point
			LootMonitorDB.position.x = x
			LootMonitorDB.position.y = y
		end
	end
end

function LootMonitor:CreateNotificationFrame()
	local frame = CreateFrame("Frame", "LootMonitorNotificationFrame", UIParent)
	frame:SetWidth(225)
	frame:SetHeight(150)
	local point = LootMonitorDB.position.point or "CENTER"
	local x = LootMonitorDB.position.x or 200
	local y = LootMonitorDB.position.y or 100
	frame:SetPoint(point, UIParent, point, x, y)
	frame:SetMovable(true)
	frame:EnableMouse(false)
	frame:RegisterForDrag("LeftButton")
	self.frame = frame
	frame:Show()
end

function LootMonitor:RegisterEvents()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_LOOT")
	frame:RegisterEvent("CHAT_MSG_MONEY")
	frame:RegisterEvent("CHAT_MSG_SYSTEM")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGOUT")
	frame:SetScript("OnEvent", function()
		if event == "ADDON_LOADED" then
			if not LootMonitor.initialized then
				LootMonitor:OnLoad()
				LootMonitor.initialized = true
			end
		elseif event == "CHAT_MSG_LOOT" then
			LootMonitor:ProcessLootMessageCN(arg1)
		elseif event == "CHAT_MSG_MONEY" then
			LootMonitor:ProcessCoinMessage(arg1)
		elseif event == "CHAT_MSG_SYSTEM" then
			LootMonitor:ProcessSystemMessageCN(arg1)
		elseif event == "PLAYER_LOGOUT" then
			LootMonitor:SavePosition()
		end
	end)
end

function LootMonitor:FindItemInBags(itemName)
	if not itemName then
		return nil, nil, nil
	end
	for bag = 0, 4 do
		local numSlots = GetContainerNumSlots(bag)
		if numSlots and numSlots > 0 then
			for slot = numSlots, 1, -1 do
				local itemLink = GetContainerItemLink(bag, slot)
				if itemLink then
					local linkStart = strfind(itemLink, BRACKET_OPEN)
					local linkEnd = strfind(itemLink, BRACKET_CLOSE)
					if linkStart and linkEnd then
						local linkName = strsub(itemLink, linkStart + 1, linkEnd - 1)
						if linkName == itemName then
							local texture = GetContainerItemInfo(bag, slot)
							if texture then
								return texture, bag, slot
							end
						end
					end
				end
			end
		end
	end
	return nil, nil, nil
end

function LootMonitor:IsCoinItem(itemName)
	if not itemName then
		return false
	end
	local name = strlower(itemName)
	return strfind(name, "%d+金") or strfind(name, "%d+银") or strfind(name, "%d+铜")
end

function LootMonitor:CountItemInBags(itemName)
	if not itemName then
		return 0
	end
	local totalCount = 0
	for bag = 0, 4 do
		local numSlots = GetContainerNumSlots(bag)
		if numSlots and numSlots > 0 then
			for slot = 1, numSlots do
				local itemLink = GetContainerItemLink(bag, slot)
				if itemLink then
					local linkStart = strfind(itemLink, BRACKET_OPEN)
					local linkEnd = strfind(itemLink, BRACKET_CLOSE)
					if linkStart and linkEnd then
						local linkName = strsub(itemLink, linkStart + 1, linkEnd - 1)
						if linkName == itemName then
							local _, itemCount = GetContainerItemInfo(bag, slot)
							if itemCount then
								totalCount = totalCount + itemCount
							end
						end
					end
				end
			end
		end
	end
	return totalCount
end

function LootMonitor:CleanupNotifications()
	local toRemove = {}
	local currentTime = gettime()
	for i, notification in ipairs(self.activeNotifications) do
		local elapsed = currentTime - notification.startTime
		local totalTime = LootMonitorDB.fadeInTime + LootMonitorDB.displayTime + LootMonitorDB.fadeOutTime
		if elapsed > totalTime then
			tinsert(toRemove, notification)
		end
	end
	for _, notification in ipairs(toRemove) do
		self:RemoveNotification(notification)
	end
end

function LootMonitor:RemoveNotification(notification)
	if notification.animFrame then
		notification.animFrame:SetScript("OnUpdate", nil)
		notification.animFrame = nil
	end
	if notification.bgAnimFrame then
		notification.bgAnimFrame:SetScript("OnUpdate", nil)
		notification.bgAnimFrame = nil
	end
	if notification.frame then
		notification.frame:Hide()
		notification.frame:SetParent(nil)
		notification.frame = nil
	end
	local activeList = self.activeNotifications
	for i = 1, tgetn(activeList) do
		if activeList[i] == notification then
			tremove(activeList, i)
			break
		end
	end
	self:RepositionNotifications()
end

function LootMonitor:RepositionNotifications()
	local activeList = self.activeNotifications
	local listLength = tgetn(activeList)
	for i = 1, listLength do
		local notification = activeList[i]
		if notification.frame then
			local yOffset = (i - 1) * -30
			notification.frame:ClearAllPoints()
			notification.frame:SetPoint("TOP", self.frame, "TOP", 0, yOffset)
		end
	end
end

function LootMonitor:GetItemQuality(itemLink)
	if not itemLink then
		return 0
	end
	local _, _, itemID = strfind(itemLink, "item:(%d+):")
	if itemID then
		itemID = tonumber(itemID)
		if itemID then
			local _, _, quality = GetItemInfo(itemID)
			if quality and quality >= 0 and quality <= 5 then
				return quality
			end
		end
	end
	local _, _, color = strfind(itemLink, "|cff(%x%x%x%x%x%x)")
	if color then
		color = strlower(color)
		if color == "1eff00" then
			return 2
		elseif color == "0070dd" then
			return 3
		elseif color == "a335ee" then
			return 4
		elseif color == "ff8000" then
			return 5
		elseif color == "9d9d9d" then
			return 0
		else
			return 1
		end
	end
	return 1
end

function LootMonitor:UpdateNotificationText(notification)
	local displayText = notification.name
	if notification.count > 1 then
		displayText = displayText .. " x" .. notification.count
	end
	local fontSize = (LootMonitorDB.fontSize or 14) * 0.5
	notification.text:SetFont("Fonts\\ARKai_T.ttf", fontSize + 2, "OUTLINE")
	notification.text:SetText(displayText)

	local showTotal = LootMonitorDB.showTotalCount
		and not notification.isCoin
		and self:CountItemInBags(notification.name) > 0
	local iconY = -24
	local textYOffset
	if showTotal then
		textYOffset = 5
	else
		textYOffset = -32 - iconY + 8
	end
	notification.text:ClearAllPoints()
	notification.text:SetPoint("LEFT", notification.icon, "RIGHT", 15, textYOffset)

	local textWidth = notification.text:GetStringWidth()
	local frameWidth = notification.frame:GetWidth()
	local iconWidth = notification.icon:GetWidth()
	local padding = 10
	if textWidth > (frameWidth - iconWidth - padding) then
		notification.text:SetWidth(frameWidth - iconWidth - padding)
	else
		notification.text:SetWidth(textWidth + 5)
	end

	if LootMonitorDB.showTotalCount and not notification.isCoin then
		local totalCount = self:CountItemInBags(notification.name)
		if totalCount > 0 then
			notification.totalText:SetFont("Fonts\\ARKai_T.ttf", fontSize, "OUTLINE")
			notification.totalText:SetText("(总数: " .. totalCount .. ")")
			local totalTextWidth = notification.totalText:GetStringWidth()
			if totalTextWidth > 0 then
				notification.totalText:SetWidth(totalTextWidth + 5)
			end
			notification.totalText:ClearAllPoints()
			notification.totalText:SetPoint("TOPLEFT", notification.text, "BOTTOMLEFT", 0, -2)
		else
			notification.totalText:SetText("")
		end
	else
		notification.totalText:SetText("")
	end

	if notification.isCoin then
		notification.text:SetTextColor(1, 0.82, 0)
	else
		local quality = self:GetItemQuality(notification.data)
		local color = QUALITY_COLORS[quality] or { 1, 1, 1 }
		notification.text:SetTextColor(color[1], color[2], color[3])
	end
end

function LootMonitor:ScheduleIconSearch(notification)
	local searchFrame = CreateFrame("Frame")
	local startTime = gettime()
	local maxSearchTime = 3.0
	local searchInterval = 0.2
	local lastSearch = 0
	local fallbackUsed = false
	searchFrame:SetScript("OnUpdate", function()
		local elapsed = gettime() - startTime
		local timeSinceLastSearch = gettime() - lastSearch
		if elapsed > maxSearchTime then
			if not fallbackUsed then
				local fallbackTexture = self:GetFallbackIcon(notification.name)
				if fallbackTexture then
					notification.icon:SetTexture(fallbackTexture)
				end
			end
			searchFrame:SetScript("OnUpdate", nil)
			return
		end
		if timeSinceLastSearch < searchInterval then
			return
		end
		lastSearch = gettime()
		local texture = self:FindItemTextureInBags(notification.name)
		if texture then
			notification.icon:SetTexture(texture)
			searchFrame:SetScript("OnUpdate", nil)
		elseif not fallbackUsed and elapsed > 0.5 then
			local fallbackTexture = self:GetFallbackIcon(notification.name)
			if fallbackTexture then
				notification.icon:SetTexture(fallbackTexture)
				fallbackUsed = true
			end
		end
	end)
end

function LootMonitor:GetFallbackIcon(itemName)
	if not itemName then
		return nil
	end
	local name = strlower(itemName)
	if strfind(name, "铜") then
		return COIN_ICON_COPPER
	elseif strfind(name, "银") then
		return COIN_ICON_SILVER
	elseif strfind(name, "金") then
		return COIN_ICON_GOLD
	elseif strfind(name, "药") then
		return "Interface\\Icons\\INV_Potion_52"
	elseif strfind(name, "布") then
		return "Interface\\Icons\\INV_Fabric_Linen_01"
	elseif strfind(name, "皮") then
		return "Interface\\Icons\\INV_Misc_LeatherScrap_02"
	elseif strfind(name, "矿") then
		return "Interface\\Icons\\INV_Ore_Copper_01"
	elseif strfind(name, "草") or strfind(name, "花") then
		return "Interface\\Icons\\INV_Misc_Herb_07"
	elseif strfind(name, "石") then
		return "Interface\\Icons\\INV_Misc_Gem_01"
	elseif strfind(name, "食物") or strfind(name, "面包") or strfind(name, "肉") then
		return "Interface\\Icons\\INV_Misc_Food_15"
	else
		return TEXTURE_PATH_QUESTION
	end
end

function LootMonitor:StartBackgroundAnimation(notification)
	if not LootMonitorDB.backgroundAnimation then
		notification.background:SetTexture("Interface\\TransmogFrame\\anim\\loot_frame_xmog_30.blp")
		notification.background:SetTexCoord(0, 1, 0, 1)
		return
	end

	local animFrame = CreateFrame("Frame")
	notification.bgAnimFrame = animFrame
	local startTime = gettime()
	local frameDuration = BACKGROUND_ANIMATION_FRAME_DURATION
	local totalFrames = BACKGROUND_ANIMATION_FRAMES
	local totalDuration = BACKGROUND_ANIMATION_TOTAL_DURATION

	animFrame:SetScript("OnUpdate", function()
		local elapsed = gettime() - startTime

		if elapsed > totalDuration then
			local texturePath = "Interface\\TransmogFrame\\anim\\loot_frame_xmog_30.blp"
			notification.background:SetTexture(texturePath)
			notification.background:SetTexCoord(0, 1, 0, 1)
			animFrame:SetScript("OnUpdate", nil)
			notification.bgAnimFrame = nil
			return
		end

		local frameIndex = math.floor(elapsed / frameDuration) + 1
		if frameIndex > totalFrames then
			frameIndex = totalFrames
		end

		local texturePath = strformat("Interface\\TransmogFrame\\anim\\loot_frame_xmog_%02d.blp", frameIndex)
		notification.background:SetTexture(texturePath)
		notification.background:SetTexCoord(0, 1, 0, 1)
	end)
end

function LootMonitor:StartNotificationAnimation(notification)
	local animFrame = CreateFrame("Frame")
	notification.animFrame = animFrame
	local dbScale = LootMonitorDB.scale
	local dbFadeIn = LootMonitorDB.fadeInTime
	local dbDisplay = LootMonitorDB.displayTime
	local dbFadeOut = LootMonitorDB.fadeOutTime
	local baseScale = (notification.isCoin and (dbScale * COIN_SCALE_FACTOR) or dbScale) * 0.5
	local fadeInTime = notification.isCoin and (dbFadeIn * COIN_FADEIN_FACTOR) or dbFadeIn
	local displayTime = notification.isCoin and (dbDisplay * COIN_DISPLAY_FACTOR) or dbDisplay
	local fadeOutTime = notification.isCoin and (dbFadeOut * COIN_FADEOUT_FACTOR) or dbFadeOut
	notification.frame:SetAlpha(0)
	notification.frame:SetScale(baseScale * 0.8)
	animFrame:SetScript("OnUpdate", function()
		local elapsed = gettime() - notification.startTime
		if elapsed < fadeInTime then
			local progress = elapsed / fadeInTime
			local alpha = progress
			local scale = baseScale * (0.8 + 0.2 * progress)
			notification.frame:SetAlpha(alpha)
			notification.frame:SetScale(scale)
		elseif elapsed < fadeInTime + displayTime then
			notification.frame:SetAlpha(1)
			notification.frame:SetScale(baseScale)
		elseif elapsed < fadeInTime + displayTime + fadeOutTime then
			if not notification.fadingOut then
				notification.fadingOut = true
			end
			local fadeProgress = (elapsed - fadeInTime - displayTime) / fadeOutTime
			local alpha = 1 - fadeProgress
			local scale = baseScale * (1 + 0.1 * fadeProgress)
			notification.frame:SetAlpha(alpha)
			notification.frame:SetScale(scale)
		else
			self:RemoveNotification(notification)
		end
	end)
end

function LootMonitor:CreateLootNotification(itemName, quantity, itemData, isNameOnly, isCoin, gold, silver, copper)
	self:CleanupNotifications()
	local maxNotifications = LootMonitorDB.maxNotifications or self.maxNotifications
	while tgetn(self.activeNotifications) >= maxNotifications do
		local oldest = self.activeNotifications[tgetn(self.activeNotifications)]
		self:RemoveNotification(oldest)
	end

	if isCoin == nil then
		isCoin = self:IsCoinItem(itemName)
	end

	local notification = CreateFrame("Frame", nil, self.frame)
	notification:SetWidth(300)
	notification:SetHeight(64)

	local notificationData = {
		frame = notification,
		name = itemName,
		count = quantity,
		data = itemData,
		isNameOnly = isNameOnly,
		isCoin = isCoin,
		startTime = gettime(),
		fadingOut = false,
		gold = gold,
		silver = silver,
		copper = copper,
	}

	if isCoin then
		tinsert(self.activeNotifications, 1, notificationData)
	else
		tinsert(self.activeNotifications, notificationData)
	end

	self:RepositionNotifications()

	local yOffset = 0
	for i = 1, tgetn(self.activeNotifications) do
		if self.activeNotifications[i] == notificationData then
			yOffset = (i - 1) * -30
			break
		end
	end

	notification:SetPoint("TOP", self.frame, "TOP", 0, yOffset)

	local background = notification:CreateTexture(nil, "ARTWORK")
	background:SetAllPoints(notification)
	background:SetTexture("Interface\\TransmogFrame\\anim\\loot_frame_xmog_01.blp")
	background:SetTexCoord(0, 1, 0, 1)
	notificationData.background = background

	local icon = notification:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(24)
	icon:SetHeight(24)
	icon:SetPoint("TOPLEFT", notification, "TOPLEFT", 93, -24)
	if isCoin then
		local coinTexture = self:GetFallbackIcon(itemName)
		if coinTexture then
			icon:SetTexture(coinTexture)
		else
			icon:SetTexture(COIN_ICON_GOLD)
		end
	else
		icon:SetTexture(TEXTURE_PATH_QUESTION)
	end
	notificationData.icon = icon

	local text = notification:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", icon, "RIGHT", 15, 5)
	text:SetJustifyH("LEFT")
	notificationData.text = text

	local totalText = notification:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	totalText:SetPoint("LEFT", text, "RIGHT", 5, 0)
	totalText:SetJustifyH("LEFT")
	totalText:SetTextColor(0.8, 0.4, 1)
	notificationData.totalText = totalText

	self:UpdateNotificationText(notificationData)

	if not isCoin then
		self:StartBackgroundAnimation(notificationData)
	else
		background:SetTexture("Interface\\TransmogFrame\\anim\\loot_frame_xmog_30.blp")
		background:SetTexCoord(0, 1, 0, 1)
	end

	self:StartNotificationAnimation(notificationData)
	if not isCoin then
		self:ScheduleIconSearch(notificationData)
	end
end

function LootMonitor:FindItemTextureInBags(itemName)
	local texture, _, _ = self:FindItemInBags(itemName)
	return texture
end

function LootMonitor:CreateSettingsPanel()
	local frame = CreateFrame("Frame", "LootMonitorSettingsFrame", UIParent)
	frame:SetWidth(300)
	frame:SetHeight(365)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
	end)
	tinsert(UISpecialFrames, "LootMonitorSettingsFrame")
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
	bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
	bg:SetTexture("Interface\\Stationery\\StationeryTest1")
	bg:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	frame:SetBackdrop({
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 12, right = 12, top = 12, bottom = 12 },
	})
	frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", frame, "TOP", 0, -20)
	title:SetText("战利品监控")
	title:SetFont("Fonts\\ARKai_T.ttf", 16, "OUTLINE")
	title:SetTextColor(1, 0.82, 0)
	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -8)
	subtitle:SetText("设置")
	subtitle:SetFont("Fonts\\ARKai_T.ttf", 12)
	subtitle:SetTextColor(0.8, 0.8, 0.8)
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	closeBtn:SetWidth(30)
	closeBtn:SetHeight(30)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)
	local contentY = -60
	local enableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	enableCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
	enableCheck:SetWidth(25)
	enableCheck:SetHeight(25)
	enableCheck:SetChecked(LootMonitorDB.enabled)
	local enableLabel = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 8, 0)
	enableLabel:SetText("启用通知")
	enableLabel:SetFont("Fonts\\ARKai_T.ttf", 12)
	enableCheck:SetScript("OnClick", function()
		LootMonitorDB.enabled = enableCheck:GetChecked()
	end)

	contentY = contentY - 35
	local totalCountCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	totalCountCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
	totalCountCheck:SetWidth(25)
	totalCountCheck:SetHeight(25)
	totalCountCheck:SetChecked(LootMonitorDB.showTotalCount)
	local totalCountLabel = totalCountCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	totalCountLabel:SetPoint("LEFT", totalCountCheck, "RIGHT", 8, 0)
	totalCountLabel:SetText("显示总数")
	totalCountLabel:SetFont("Fonts\\ARKai_T.ttf", 12)
	totalCountCheck:SetScript("OnClick", function()
		LootMonitorDB.showTotalCount = totalCountCheck:GetChecked()
	end)

	local bgAnimCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	bgAnimCheck:SetPoint("LEFT", totalCountCheck, "RIGHT", 120, 0)
	bgAnimCheck:SetWidth(25)
	bgAnimCheck:SetHeight(25)
	bgAnimCheck:SetChecked(LootMonitorDB.backgroundAnimation)
	local bgAnimLabel = bgAnimCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	bgAnimLabel:SetPoint("LEFT", bgAnimCheck, "RIGHT", 8, 0)
	bgAnimLabel:SetText("背景动画")
	bgAnimLabel:SetFont("Fonts\\ARKai_T.ttf", 12)
	bgAnimCheck:SetScript("OnClick", function()
		LootMonitorDB.backgroundAnimation = bgAnimCheck:GetChecked()
	end)

	contentY = contentY - 40
	local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	scaleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
	scaleLabel:SetText("拾取界面缩放: " .. format("%.1f", LootMonitorDB.scale))
	scaleLabel:SetFont("Fonts\\ARKai_T.ttf", 12)
	local scaleSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
	scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -10)
	scaleSlider:SetMinMaxValues(0.5, 10.0)
	scaleSlider:SetValue(LootMonitorDB.scale)
	scaleSlider:SetValueStep(0.1)
	scaleSlider:SetWidth(250)
	scaleSlider:SetScript("OnValueChanged", function()
		local value = scaleSlider:GetValue()
		LootMonitorDB.scale = value
		scaleLabel:SetText("拾取界面缩放: " .. format("%.1f", value))
	end)
	contentY = contentY - 60
	local timeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	timeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
	timeLabel:SetText("提示持续时间: " .. format("%.1f秒", LootMonitorDB.displayTime))
	timeLabel:SetFont("Fonts\\ARKai_T.ttf", 12)
	local timeSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
	timeSlider:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -10)
	timeSlider:SetMinMaxValues(1.0, 60.0)
	timeSlider:SetValue(LootMonitorDB.displayTime)
	timeSlider:SetValueStep(0.5)
	timeSlider:SetWidth(250)
	timeSlider:SetScript("OnValueChanged", function()
		local value = timeSlider:GetValue()
		LootMonitorDB.displayTime = value
		timeLabel:SetText("提示持续时间: " .. format("%.1f秒", value))
	end)
	contentY = contentY - 60
	local maxNotificationsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	maxNotificationsLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, contentY)
	maxNotificationsLabel:SetText("最大通知数量: " .. LootMonitorDB.maxNotifications)
	maxNotificationsLabel:SetFont("Fonts\\ARKai_T.ttf", 12)
	local maxNotificationsSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
	maxNotificationsSlider:SetPoint("TOPLEFT", maxNotificationsLabel, "BOTTOMLEFT", 0, -10)
	maxNotificationsSlider:SetMinMaxValues(1, 10)
	maxNotificationsSlider:SetValue(LootMonitorDB.maxNotifications)
	maxNotificationsSlider:SetValueStep(1)
	maxNotificationsSlider:SetWidth(250)
	maxNotificationsSlider:SetScript("OnValueChanged", function()
		local value = maxNotificationsSlider:GetValue()
		LootMonitorDB.maxNotifications = value
		maxNotificationsLabel:SetText("最大通知数量: " .. value)
		LootMonitor.maxNotifications = value
		while tgetn(LootMonitor.activeNotifications) > value do
			local oldest = LootMonitor.activeNotifications[tgetn(LootMonitor.activeNotifications)]
			LootMonitor:RemoveNotification(oldest)
		end
	end)
	local buttonY = -410
	local moveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	moveBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 20)
	moveBtn:SetWidth(120)
	moveBtn:SetHeight(30)
	moveBtn:SetText("移动位置")
	moveBtn:GetFontString():SetFont("Fonts\\ARKai_T.ttf", 12)
	moveBtn:SetScript("OnClick", function()
		LootMonitor:ToggleMoveMode()
		if LootMonitor.moveMode then
			moveBtn:SetText("退出移动")
		else
			moveBtn:SetText("移动位置")
		end
	end)
	LootMonitor.settingsMoveBtn = moveBtn

	local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	resetBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
	resetBtn:SetWidth(120)
	resetBtn:SetHeight(30)
	resetBtn:SetText("重置设置")
	resetBtn:GetFontString():SetFont("Fonts\\ARKai_T.ttf", 12)
	resetBtn:SetScript("OnClick", function()
		LootMonitorDB.enabled = defaults.enabled
		LootMonitorDB.scale = defaults.scale
		LootMonitorDB.fadeInTime = defaults.fadeInTime
		LootMonitorDB.displayTime = defaults.displayTime
		LootMonitorDB.fadeOutTime = defaults.fadeOutTime
		LootMonitorDB.showTotalCount = defaults.showTotalCount
		LootMonitorDB.fontSize = defaults.fontSize
		LootMonitorDB.maxNotifications = defaults.maxNotifications
		LootMonitorDB.backgroundAnimation = defaults.backgroundAnimation
		LootMonitorDB.position = { point = defaults.position.point, x = defaults.position.x, y = defaults.position.y }
		enableCheck:SetChecked(defaults.enabled)
		totalCountCheck:SetChecked(defaults.showTotalCount)
		bgAnimCheck:SetChecked(defaults.backgroundAnimation)
		scaleSlider:SetValue(defaults.scale)
		timeSlider:SetValue(defaults.displayTime)
		maxNotificationsSlider:SetValue(defaults.maxNotifications)
		scaleLabel:SetText("拾取界面缩放: " .. format("%.1f", defaults.scale))
		timeLabel:SetText("提示持续时间: " .. format("%.1f秒", defaults.displayTime))
		maxNotificationsLabel:SetText("最大通知数量: " .. defaults.maxNotifications)
		Print("设置已重置为默认值")
	end)
	self.settingsFrame = frame
	frame:Hide()
	frame:SetScript("OnShow", function()
		if LootMonitor.moveMode then
			moveBtn:SetText("退出移动")
		else
			moveBtn:SetText("移动位置")
		end
	end)
end

function LootMonitor:ShowSettings()
	if not self.settingsFrame then
		self:CreateSettingsPanel()
	end
	self.settingsFrame:Show()
end

function LootMonitor:ToggleMoveMode()
	if self.moveMode then
		self:ExitMoveMode()
	else
		self:EnterMoveMode()
	end
end

function LootMonitor:EnterMoveMode()
	self.moveMode = true

	if not self.keyboardFrame then
		self.keyboardFrame = CreateFrame("Frame")
		self.keyboardFrame:SetScript("OnKeyDown", function(frame, key)
			if key == "ESCAPE" and LootMonitor.moveMode then
				LootMonitor:ExitMoveMode()
			end
		end)
	end
	self.keyboardFrame:EnableKeyboard(true)

	if not self.moveFrame then
		local moveFrame = CreateFrame("Frame", "LootMonitorMoveFrame", UIParent)
		moveFrame:SetWidth(125)
		moveFrame:SetHeight(75)
		tinsert(UISpecialFrames, "LootMonitorMoveFrame")
		local mainPoint, _, _, mainX, mainY = self.frame:GetPoint()
		if mainPoint and mainX and mainY then
			moveFrame:SetPoint(mainPoint, UIParent, mainPoint, mainX, mainY)
		else
			moveFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 100)
		end
		local bg = moveFrame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(moveFrame)
		bg:SetTexture("Interface\\Stationery\\StationeryTest1")
		bg:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		bg:SetAlpha(0.7)
		local border = CreateFrame("Frame", nil, moveFrame)
		border:SetAllPoints(moveFrame)
		border:SetBackdrop({
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		local title = moveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", moveFrame, "TOP", 0, -5)
		title:SetText("通知区域")
		title:SetTextColor(1, 1, 1)
		title:SetFont("Fonts\\ARKai_T.ttf", 10)
		local instructions = moveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		instructions:SetPoint("CENTER", moveFrame, "CENTER", 0, 0)
		instructions:SetTextColor(1, 1, 0)
		instructions:SetJustifyH("CENTER")
		instructions:SetFont("Fonts\\ARKai_T.ttf", 8)
		instructions:SetText("拖动此框调整位置\n点击X退出")
		local closeBtn = CreateFrame("Button", nil, moveFrame, "UIPanelCloseButton")
		closeBtn:SetPoint("TOPRIGHT", moveFrame, "TOPRIGHT", -3, -3)
		closeBtn:SetWidth(15)
		closeBtn:SetHeight(15)
		closeBtn:SetScript("OnClick", function()
			LootMonitor:ExitMoveMode()
		end)
		moveFrame:SetMovable(true)
		moveFrame:EnableMouse(true)
		moveFrame:RegisterForDrag("LeftButton")
		moveFrame:SetScript("OnDragStart", function()
			moveFrame:StartMoving()
		end)
		moveFrame:SetScript("OnDragStop", function()
			moveFrame:StopMovingOrSizing()
			local point, _, _, x, y = moveFrame:GetPoint()
			if point and x and y then
				LootMonitor.frame:ClearAllPoints()
				LootMonitor.frame:SetPoint(point, UIParent, point, x, y)
			end
		end)
		self.moveFrame = moveFrame
	end
	self.moveFrame:Show()

	if self.settingsMoveBtn then
		self.settingsMoveBtn:SetText("退出移动")
	end

	Print("[战利品监控] 移动模式已启用。拖动框架可重新定位通知。")
	Print("输入 '/lootmonitor move' 或点击X退出移动模式。")
end

function LootMonitor:ExitMoveMode()
	self.moveMode = false

	if self.keyboardFrame then
		self.keyboardFrame:EnableKeyboard(false)
	end

	if self.moveFrame then
		local point, _, _, x, y = self.moveFrame:GetPoint()
		if point and x and y and x ~= 0 and y ~= 0 then
			if not LootMonitorDB.position then
				LootMonitorDB.position = {}
			end
			LootMonitorDB.position.point = point
			LootMonitorDB.position.x = x
			LootMonitorDB.position.y = y
			self.frame:ClearAllPoints()
			self.frame:SetPoint(point, UIParent, point, x, y)
			Print("[战利品监控] 位置已保存。")
		end
		self.moveFrame:Hide()
	end

	if self.settingsMoveBtn then
		self.settingsMoveBtn:SetText("移动位置")
	end

	Print("[战利品监控] 移动模式已禁用。")
end

SLASH_LOOTMONITOR1 = "/lootmonitor"
SLASH_LOOTMONITOR2 = "/lm"
SlashCmdList["LOOTMONITOR"] = function(msg)
	local cmd = strlower(msg or "")
	if cmd == "toggle" then
		LootMonitorDB.enabled = not LootMonitorDB.enabled
		if LootMonitorDB.enabled then
			Print("战利品通知已启用")
		else
			Print("战利品通知已禁用")
		end
	elseif cmd == "" then
		LootMonitor:ShowSettings()
	elseif cmd == "clear" then
		for _, notification in ipairs(LootMonitor.activeNotifications) do
			LootMonitor:RemoveNotification(notification)
		end
		Print("已清除所有通知")
	elseif cmd == "move" then
		LootMonitor:ToggleMoveMode()
	elseif cmd == "settings" then
		LootMonitor:ShowSettings()
	elseif cmd == "help" then
		Print("命令列表:")
		Print("  /lm - 打开设置面板")
		Print("  /lm toggle - 切换通知开关")
		Print("  /lm clear - 清除当前通知")
		Print("  /lm move - 调整通知位置")
		Print("  /lm settings - 打开设置面板")
		Print("  /lm help - 显示帮助")
	else
		Print("未知命令，输入 /lm help 查看帮助")
	end
end

LootMonitor:RegisterEvents()
