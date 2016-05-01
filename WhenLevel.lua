--
--	WhenLevel
--	Written by scott@mithrandir.com
--
--	Version History
--		001	Initial version that records when leveling is done.
--		002	Added command line to output leveling information.
--		003	Converted to using strings in preparation for localization.
--		004	Computes maximum level instead of hardcoding 80.
--		005	Converted to using a cross-character data store and storing location.
--			Made it so the output appears in a scroll view in the standard Blizzard
--			configuration panel instead of the default chat window.
--		006	Widened the configuration to give more space to the zone.
--			Updated to run on release 4.0.1.
--		007	Eliminating the old per-character data when loaded into new database.
--			Made use of some local variables to eliminate many redundant characters.
--			Made resizing the options panel act reasonably intelligently.
--			Optimized object creation so it no longer is done on each panel showing.
--		008	Fixes the problem where the data was not being displayed properly in the configuration panel.
--			Updates the interface to 40300.
--			Asks for the time played immediately upon startup since Blizzard no longer does this any more.
--		009	Updates the interface to 50400.
--			Changes the frame used for event processing.
--			Changes from using PLAYER_ALIVE to PLAYER_ENTERING_WORLD.
--		010	Updates the interface to 60200
--			Corrects a problem with scrolling.
--
--	Known Issues
--
--	UTF-8 file
--

local WhenLevel_File_Version = 009

if nil == WhenLevel or WhenLevel.versionNumber < WhenLevel_File_Version then

	--	This is the data that is written to disk that records each level date and time played.
	WhenLevelData = { }

	--	Starting in version 005 the data is stored in one central location so character leveling can be compared.
	WhenLevelDatabase = { }

	--	The actual addon itself.
	--	Conceptually a very simple addon that creates a tooltip that is used to receive events for the addon.
	--	The tooltip is hidden and is not used for any other purpose.  A slash command is registered so the
	--	user can request the report of leveling information.  Two events are of importance -- PLAYER_LEVEL_UP
	--	and TIME_PLAYED_MSG.  When the addon receives notification that PLAYER_LEVEL_UP it ensures the server
	--	is asked for how much time is played, causing TIME_PLAYED_MSG to eventually be sent.  Note that within
	--	the processing of the PLAYER_LEVEL_UP event the call to UnitLevel() will not return the new level, so
	--	we use the first argument in the PLAYER_LEVEL_UP event to record this information.  Also note that upon
	--	entry into the world the server now reports the time played so we also receive TIME_PLAYED_MSG.  In
	--	processing TIME_PLAYED_MSG we record the server time and the total time played if we have not already
	--	recorded this information for the current character level.  Since we only record the time played at a
	--	level once, it is safe for the user to use the /played slash command without harming the WhenLevel data.
	--	Since a lot of characters will first use WhenLevel after level one, it is a special case and noted in
	--	the /whenlevel output data.
	WhenLevel = {

		versionNumber = WhenLevel_File_Version,
		currentlyProcessingLevel,
		eventDispatch = {			-- table of functions whose keys are the events
			['ADDON_LOADED'] = function(self, frame)
				self.playerRealm = GetRealmName()
				self.playerName = UnitName('player')
				_, self.playerClass = UnitClass('player')
				self.locale = GetLocale()
				-- if the locale is not found to be supported default to enUS
				if nil == self.s[self.locale] then
					self.locale = 'enUS'
				end
				SlashCmdList["WHENLEVEL"] = function(msg)
					self:SlashCommand(msg)
				end
				SLASH_WHENLEVEL1 = "/whenlevel"
				frame:RegisterEvent("PLAYER_ENTERING_WORLD")
			end,
			['PLAYER_ENTERING_WORLD'] = function(self, frame)
				self.currentlyProcessingLevel = UnitLevel("player")
				frame:RegisterEvent("PLAYER_LEVEL_UP")
				frame:RegisterEvent("TIME_PLAYED_MSG")
				RequestTimePlayed()
			end,
			['PLAYER_LEVEL_UP'] = function(self, frame, arg1)
				--	arg1 tells us the new level, but we just cause another event to be posted
				self.currentlyProcessingLevel = tonumber(arg1)
				RequestTimePlayed()
			end,
			['TIME_PLAYED_MSG'] = function(self, frame, arg1, arg2)
				--	arg1 tells us total time
				--	arg2 tells us total time at level
				local currentLevel = self.currentlyProcessingLevel
				if (nil == WhenLevelDatabase[self.playerRealm]) then
					WhenLevelDatabase[self.playerRealm] = { }
				end
				if (nil == WhenLevelDatabase[self.playerRealm][self.playerName]) then
					WhenLevelDatabase[self.playerRealm][self.playerName] = { }
					WhenLevelDatabase[self.playerRealm][self.playerName]["class"] = self.playerClass
					local whereToStop = UnitLevel('player')
					for i = 1, whereToStop, 1 do
						if (nil ~= WhenLevelData[i]) then
							WhenLevelDatabase[self.playerRealm][self.playerName][i] = { }
							WhenLevelDatabase[self.playerRealm][self.playerName][i]["totalPlayed"] = WhenLevelData[i]["totalPlayed"]
							WhenLevelDatabase[self.playerRealm][self.playerName][i]["serverTime"] = WhenLevelData[i]["serverTime"]
						end
					end
				end
				wipe(WhenLevelData)	-- we do not want the old information now that it is in the new structure
				if (nil == WhenLevelDatabase[self.playerRealm][self.playerName][currentLevel]) then
					local hour, minute = GetGameTime()
					local weekday, month, day, year = CalendarGetDate()
					local x, y = GetPlayerMapPosition("player")
					local L = { }
					L["totalPlayed"] = arg1
					L["serverTime"] = string.format("%4d-%02d-%02d %02d:%02d", year, month, day, hour, minute)
					L["zone"] = GetRealZoneText()
					L["subzone"] = GetSubZoneText()
					L["x"] = x
					L["y"] = y
					WhenLevelDatabase[self.playerRealm][self.playerName][currentLevel] = L
				end
			end,
			},
		locale,
		playerClass,
		playerName,
		playerRealm,
		--	This section has the localization information for all the output text that the addon generates.
		--	Note that it is done this way solely to minimize the namespace pollution this addon causes.
		--	The downfall of this method is a larger runtime size since each of the localizations is kept
		--	in memory, and the need for detecting whether the locale the user is using is actually supported.
		--	We could eliminate the runtime size issue by eliminating the non-used locales, but that would
		--	require a little more code and the desire is smaller.  The number of strings used in this addon
		--	do not require that much memory, so the desire for less namespace pollution wins.
		s = {
			['enUS'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['deDE'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'T',
				HOURS               = 'H',
				MINUTES             = 'M',
				SECONDS             = 'S',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['enGB'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['esES'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['esMX'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['frFR'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'j',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['koKR'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['ptBR'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['ruRU'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['zhCN'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			['zhTW'] = {
				FIRST_USED          = 'First Used',
				DAYS                = 'd',
				HOURS               = 'h',
				MINUTES             = 'm',
				SECONDS             = 's',
				DATE                = 'Date',
				TOTAL_PLAYED		= 'Total Played',
				LEVEL_PLAYED        = 'Level Played',
				NO_DATA_AVAILABLE	= 'No Data Available',
				},
			},

		FormattedSeconds = function(self, totalSeconds)
			local days = math.floor(totalSeconds / 86400)
			local remainder = totalSeconds - (days * 86400)
			local hours = math.floor(remainder / 3600)
			remainder = remainder - (hours * 3600)
			local minutes = math.floor(remainder / 60)
			local seconds = remainder - (minutes * 60)
			local retval = ""
			local L = self.s[self.locale]

			if (days > 0) then retval = retval .. days .. L['DAYS'] end
			if (hours > 0 or days > 0) then retval = retval .. hours .. L['HOURS'] end
			if (minutes > 0 or hours > 0 or days > 0) then retval = retval .. minutes .. L['MINUTES'] end
			retval = retval .. seconds .. L['SECONDS']
			return retval
		end,

		ScrollFrame_OnLoad = function(self, frame)
			HybridScrollFrame_OnLoad(frame)
			frame.update = WhenLevel.ScrollFrame_Update
			HybridScrollFrame_CreateButtons(frame, "com_mithrandir_whenLevelButtonTemplate")
		end,

		ScrollFrame_Update = function(self)
			self = WhenLevel
			local buttons = com_mithrandir_whenLevelConfigFrameScrollFrame.buttons
			local numButtons = #buttons
			local scrollOffset = HybridScrollFrame_GetOffset(com_mithrandir_whenLevelConfigFrameScrollFrame)
			local buttonHeight = buttons[1]:GetHeight()
			local button

			-- Figure out what our level range is, and total level count
			local whereToStop = UnitLevel('player')
			local firstLevelEncountered = -1
			local highestLevelEncountered = 0
			for i = 1, whereToStop do
				if nil ~= WhenLevelDatabase[self.playerRealm][self.playerName][i] then
					if -1 == firstLevelEncountered then
						firstLevelEncountered = i
					end
					if i > highestLevelEncountered then
						highestLevelEncountered = i
					end
				end
			end
			local numEntries = highestLevelEncountered - firstLevelEncountered + 1
			local linePlusOffset
			local index
			local date, zone, totalPlayed, levelPlayed, L
			for i = 1, numButtons do
				button = buttons[i]
				index = i + scrollOffset
				if index <= numEntries then
					linePlusOffset = firstLevelEncountered - 1 + index
					button.level:SetText(linePlusOffset)
					date, zone, totalPlayed, levelPlayed, L = "", "", "", "", WhenLevelDatabase[self.playerRealm][self.playerName][linePlusOffset]
					if nil ~= L then
						if (linePlusOffset ~= firstLevelEncountered or firstLevelEncountered == 1) then
							date = L["serverTime"]
							if (nil ~= L["zone"]) then
								zone = L["zone"]
								if (nil ~= L["subzone"]) then
									if ("" ~= L["subzone"]) then
										zone = zone .. " (" .. L["subzone"] .. ")"
									end
								end
							end
							totalPlayed = self:FormattedSeconds(L["totalPlayed"])
							if (linePlusOffset < whereToStop and nil ~= WhenLevelDatabase[self.playerRealm][self.playerName][linePlusOffset + 1]) then
								local totalSeconds = WhenLevelDatabase[self.playerRealm][self.playerName][linePlusOffset + 1]["totalPlayed"] - L["totalPlayed"]
								levelPlayed = string.format(self:FormattedSeconds(totalSeconds))
							end
						else
--							date = string.format(self.s[self.locale]['FIRST_USED'])
							date = string.format(FIRST_AVAILABLE)
						end
					else
						date = self.s[self.locale]['NO_DATA_AVAILABLE']
					end
					button.date:SetText(date)
					button.zone:SetText(zone)
					button.totalPlayed:SetText(totalPlayed)
					button.levelPlayed:SetText(levelPlayed)
					button:Show()
				else
					button:Hide()
				end
			end
			HybridScrollFrame_Update(com_mithrandir_whenLevelConfigFrameScrollFrame, numEntries * buttonHeight, numButtons * buttonHeight)
		end,

		SlashCommand = function(self, msg)
			InterfaceOptionsFrame_OpenToCategory("WhenLevel")
			InterfaceOptionsFrame_OpenToCategory("WhenLevel")
		end,

		Tooltip_OnEvent = function(self, frame, event, ...)
			if self.eventDispatch[event] then
				self.eventDispatch[event](self, frame, ...)
			end
		end,

		ConfigFrame_OnLoad = function(self, panel)
			panel.name = "WhenLevel"
			panel:Hide()
			InterfaceOptions_AddCategory(panel)
		end,

		ConfigFrame_OnShow = function(self, panel)
			--	Update the user interface
			local L = self.s[self.locale]
			local N = "com_mithrandir_whenLevelConfigFrame"

			--	Set the column heading names to be their localized values
			_G[N.."Level"]:SetText(LEVEL_ABBR)
			_G[N.."Date"]:SetText(L['DATE'])
			_G[N.."Zone"]:SetText(ZONE)
			_G[N.."TotalPlayed"]:SetText(L['TOTAL_PLAYED'])
			_G[N.."LevelPlayed"]:SetText(L['LEVEL_PLAYED'])

			self:ScrollFrame_Update()
		end,

		}

	local me = WhenLevel

	me.notificationFrame = CreateFrame("Frame")
	me.notificationFrame:SetScript("OnEvent", function(frame, event, ...) WhenLevel:Tooltip_OnEvent(frame, event, ...) end)
	me.notificationFrame:RegisterEvent("ADDON_LOADED")

end
