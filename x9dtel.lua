--[[
	OpenTX Telemetry GUI for FrSky Taranis X9D+ SE 2019
	include TBS Crossfire Telemetry
	
	Rolf Wirtz (rolf.wirtz@gmail.com)
--]]

-- settings
local cellMaxV	= 4.20 -- display max - 4.1 LiIo 4.20 LiPo, 3.35 LiHv
local cellMinV	= 3.30 -- display min
local cellNomV	= 4.35 -- Nominal Voltage for detecting cell count

-- globals
-- FrSky Taranis X9D+ SE 2019 Display
local displayWidth	= 212 
local displayHight	= 64
local popupMenu		= 0
local cellCountTX	= 0
local cellCountRX	= 0
local modelName		= "unknown"
local lastValidGPS

local function calcCellCount(value)
	local cells = ((value - (value % cellNomV)) / cellNomV) + 1
	return cells
end

local function drawTXBattery(pos_x, pos_y)
	local batWidth = 18
	local value = getValue('tx-voltage')
	
	local valueCell = calcCellCount(value)
	if cellCountTX < valueCell then
		cellCountTX = valueCell
	end
	
	local precent = 100 / ((cellCountTX * cellMaxV) - (cellCountTX * cellMinV)) * (value - (cellCountTX * cellMinV))
	if precent < 0 then
		precent = 0
	elseif precent > 100 then
		precent = 100
	end
	
	-- draw Battery
	lcd.drawRectangle(pos_x, pos_y, batWidth, 6, SOLID)
	lcd.drawLine(pos_x + batWidth, pos_y + 1, pos_x + batWidth, pos_y + 4, SOLID, FORCE)
	lcd.drawFilledRectangle(pos_x + 1, pos_y + 1, ((batWidth-2) / 100 * precent) , 4)
	
	lcd.drawText(pos_x + batWidth + 3, pos_y, string.format("%.2f", value) .. "V", SMLSIZE)
end

local function drawRXVolt(pos_x, pos_y)
	local value = getValue('RxBt')
	lcd.drawText(pos_x, pos_y, string.format("%5.2f", value) .. "V " .. cellCountRX .. "S", MIDSIZE)
end

local function drawRXBatteryGraph(pos_x, pos_y)
	local batHight = 51
	local batWidth = 10
	local value = getValue('RxBt')

	local valueCell = calcCellCount(value)
	if cellCountRX < valueCell then
		cellCountRX = valueCell
	end

	local precent = 100 / ((cellCountRX * cellMaxV) - (cellCountRX * cellMinV)) * (value - (cellCountRX * cellMinV))
	if precent < 0 then
		precent = 0
	elseif precent > 100 then
		precent = 100
	end
	
	-- draw Battery
	lcd.drawRectangle(pos_x, pos_y, batWidth, batHight, SOLID)
	lcd.drawLine(pos_x + batWidth - 1, (pos_y + (batHight/100*25)), (pos_x + batWidth - (batWidth/100*25)), (pos_y + (batHight/100*25)), SOLID, FORCE )
	lcd.drawLine(pos_x + batWidth - 1, (pos_y + (batHight/100*50)), (pos_x + batWidth - (batWidth/100*50)), (pos_y + (batHight/100*50)), SOLID, FORCE )
	lcd.drawLine(pos_x + batWidth - 1, (pos_y + (batHight/100*75)), (pos_x + batWidth - (batWidth/100*25)), (pos_y + (batHight/100*75)), SOLID, FORCE )
	
	lcd.drawText(pos_x + batWidth + 2, (pos_y + (batHight/100*-2)), string.format("%.2f", cellMaxV) .. "V", SMLSIZE)
	lcd.drawText(pos_x + batWidth + 2, (pos_y + (batHight/100*21)), string.format("%.2f", cellMinV + ((cellMaxV - cellMinV)*0.75)) .. "V", SMLSIZE)
	lcd.drawText(pos_x + batWidth + 2, (pos_y + (batHight/100*45)), string.format("%.2f", cellMinV + ((cellMaxV - cellMinV)*0.50)) .. "V", SMLSIZE)
	lcd.drawText(pos_x + batWidth + 2, (pos_y + (batHight/100*69)), string.format("%.2f", cellMinV + ((cellMaxV - cellMinV)*0.25)) .. "V", SMLSIZE)
	lcd.drawText(pos_x + batWidth + 2, (pos_y + (batHight/100*90)), string.format("%.2f", cellMinV) .. "V", SMLSIZE)
	
	lcd.drawFilledRectangle(pos_x + 1, pos_y + 1 + math.ceil((batHight - 2)/100*(100-precent)), batWidth - 2, math.floor((batHight - 2)/100*precent) )
end

local function drawRXBatCap(pos_x, pos_y)
	--   12mAh
	--  999mAh
	--  1.20Ah
	-- 99.99Ah
	local valueCurr = getValue('Curr') 
	local valueCapa = getValue('Capa')
	local lblCapa = 0
	
	if valueCapa >= 1000 then
		valueCapa = valueCapa / 1000.0
		lblCapa = 1
	end
	
	lcd.drawText(pos_x, pos_y, "Cur " .. string.format("%5.1f", valueCurr) .. "A")	
	if lblCapa == 1 then
		lcd.drawText(pos_x, pos_y + 8, "Cap " .. string.format("%5.2f", valueCapa) .. "Ah")
	else
		lcd.drawText(pos_x, pos_y + 8, "Cap " .. string.format("%4d", valueCapa) .. "mAh")
	end
end

local function drawRSSI(pos_x, pos_y)
	local value
	--local value = getRSSI()
	local rssi1 = getValue('1RSS')
	local rssi2 = getValue('2RSS')
	if rssi1 >= rssi2 then
		value = rssi1
	else
		value = rssi2
	end
	--local value = 100 -- (dbg)
	lcd.drawText(pos_x, pos_y, "RSSI " .. string.format("%3d", value) .. "dB", MIDSIZE)
end

local function drawLQ(pos_x, pos_y)
	local valueLQ = getValue('RQly')	-- LQ
	local valueRSNR = getValue('RSNR')	-- Receiver SNR
	local valueMode = getValue('RFMD')	-- Hz 2 = 150Hz; 1 = 50Hz; 0 = 4Hz
	
	if valueMode == 0 then
		valueMode = "4"
	elseif valueMode == 1 then
		valueMode = "50"
	elseif valueMode == 2 then
		valueMode = "150"
	end
	
	lcd.drawText(pos_x, pos_y, "LQ " .. string.format("%3d", valueLQ) .. "%",MIDSIZE)
	lcd.drawText(pos_x + 53, pos_y, string.format("%3d", valueRSNR) .. "dB SNR", SMLSIZE)
	lcd.drawText(pos_x + 53, pos_y + 7, string.format("%3d", valueMode) .. "Hz", SMLSIZE)
end

local function drawTXPwr(pos_x, pos_y)
	local value = getValue('TPWR')
	lcd.drawText(pos_x, pos_y, "TX Power " .. string.format("%4d", value) .. "mW")
end

local function drawVTX(pos_x, pos_y)
	-- blablabla
end

local function drawGPSInfo(pos_x, pos_y)
	local valueGSpd = getValue('GSpd')
	local valueAlt = getValue('Alt')
	local valueSat = getValue('Sats')
	
	lcd.drawText(pos_x, pos_y, string.format("%5.1f", valueGSpd) .. "kmh", MIDSIZE)
	lcd.drawText(pos_x, pos_y + 12, string.format("%4d", valueAlt) .. "m")
	lcd.drawText(pos_x + 28, pos_y + 12, string.format("%2d", valueSat) .. "Sat")
end

local function drawGPSCoord(pos_x, pos_y)
	local value = getValue('GPS')
	if type(value) == "table" then
		lastValidGPS = value
		lcd.drawText(pos_x, pos_y, "Lat " .. string.format("%09.6f", value.lat) .. "N")
		lcd.drawText(pos_x, pos_y + 8, "Lon " .. string.format("%09.6f", value.lon) .. "E")
	elseif type(lastValidGPS) == "table" then
		lcd.drawText(pos_x, pos_y, "Lat " .. string.format("%09.6f", lastValidGPS.lat) .. "N")
		lcd.drawText(pos_x, pos_y + 8, "Lon " .. string.format("%09.6f", lastValidGPS.lon) .. "E")
		lcd.drawText(pos_x + 72, pos_y, "GPS", BLINK)
		lcd.drawText(pos_x + 72, pos_y + 8, "Lost", BLINK)
	else
		lcd.drawText(pos_x, pos_y, "NO GPS", MIDSIZE)
	end
end

local function drawTime(pos_x, pos_y)
	local datenow = getDateTime()
	lcd.drawText(pos_x, pos_y, string.format("%02d:%02d", datenow.hour, datenow.min), SMLSIZE)
end

local function drawModel(pos_x, pos_y)
	lcd.drawText(pos_x, pos_y, modelName, SMLSIZE)
end


local function resetConfig()
	cellCountRX = 0
end

local function drawPopupMenu()
	local popupSizeW = 160
	local popupSizeH = 35
	lcd.drawFilledRectangle((displayWidth / 2) - (popupSizeW / 2), (displayHight / 2) - (popupSizeH / 2), popupSizeW, popupSizeH, ERASE)
	lcd.drawRectangle((displayWidth / 2) - (popupSizeW / 2) + 1, (displayHight / 2) - (popupSizeH / 2) + 1, popupSizeW - 2, popupSizeH - 2, SOLID)
	lcd.drawText((displayWidth / 2) - (popupSizeW / 2) + 40, (displayHight / 2) - (popupSizeH / 2) + 6, "Reset Script...?")
	lcd.drawText((displayWidth / 2) - (popupSizeW / 2) + 20, (displayHight / 2) - (popupSizeH / 2) + 20, "[EXIT] NO    [ENTER] YES")
end


local function run(event)
	lcd.clear()
	lcd.drawLine(0, 7, displayWidth, 7, SOLID, FORCE)
	drawTXBattery(0, 0)
	drawModel(50, 0)
	drawTime(188,0)
	
	drawRXBatteryGraph(5, 11)
	drawRXVolt(50, 9)
	drawRXBatCap(50, 22)
	drawRSSI(115, 9)
	drawLQ(115, 22)
	drawTXPwr(115, 37)
	
	drawGPSInfo(47, 42)
	drawGPSCoord(115, 47)
	
	if popupMenu == 1 then
		drawPopupMenu()
		if event == EVT_ENTER_BREAK then
			resetConfig()
			popupMenu = 0
		elseif event == EVT_EXIT_BREAK then
			popupMenu = 0
		end	
	elseif event == EVT_ENTER_BREAK then
		popupMenu = 1
	end
	
	return 0
end

local function init()
	local modeldata= model.getInfo()
	if modeldata then
		modelName = modeldata['name']
	end
end

return { run = run, init = init }
