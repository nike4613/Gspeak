local function send_setting( table, client )
	if client then
		gspeak:ChangeSetting(string.Explode( ".", table.name ), gspeak.cl.settings, table.name, table.value)
		return
	end
	net.Start("gspeak_setting_change")
		net.WriteTable( table )
	net.SendToServer()
end

local function gui_think_slider(Panel)
	if Panel.Slider and Panel.Slider:GetDragging() then return end
	local value = math.Round( Panel:GetValue(), Panel:GetDecimals() )
	Panel.last_value = Panel.last_value or value
	if Panel.last_value == value then return end

	Panel.last_value = value
	send_setting( { name = Panel:GetName(), value = value }, Panel.client )
end

local function gui_change(Panel)
	local value
	if Panel.GetChecked then value = Panel:GetChecked()
	else value = Panel:GetValue() end

	send_setting( { name = Panel:GetName(), value = value }, Panel.client )
end

local function gui_key_trapper( TPanel )
	input.StartKeyTrapping()
	local DermaPanel = vgui.Create( "DFrame" )
	DermaPanel:SetName( TPanel:GetName() )
	DermaPanel:Center()
	DermaPanel:SetSize( 250, 75 )
	DermaPanel:SetTitle( "Gspeak Config" )
	DermaPanel:SetDraggable( true )
	DermaPanel:MakePopup()
	DermaPanel.Paint = function( self, w, h )
		draw.RoundedBox( 0, 0, 0, w, h, Color( 50, 50, 50, 255 ) )
	end
	DermaPanel:ShowCloseButton( false )
	DermaPanel.Think = function ( Panel )
		local panel_name = Panel:GetName()
		local key = input.CheckKeyTrapping()
		if key != nil then
			send_setting( { name = panel_name, value = key }, TPanel.Client )
			Panel:Close()
		end
	end
	DermaPanel.OnClose = function ( Panel )
		TPanel:SetDisabled( false )
	end

	local DLabel = vgui.Create( "DLabel", DermaPanel )
	DLabel:SetPos( 25, 25 )
	DLabel:SetSize( 200, 25 )
	DLabel:SetText( "Press the key you want to set!" )
end

local function GetKeyString( key_enum )
	return (key_enum == KEY_NONE ) and "error" or input.GetKeyName(key_enum)
end

local function MakeSettingPane(xp, yp, ydist, parent) 
	return {
		xbase = xp,
		ybase = yp,
		xp = xp,
		yp = yp,
		ydist = ydist,
		parent = parent,
		resetOnRow = false
	}
end

local function KeybindElem(panel, label, setting, defaultText)
	if label then
		local DLabel = vgui.Create( "DLabel", panel.parent )
		DLabel:SetPos( panel.xp, panel.yp )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( label )
	end
	local DLabel = vgui.Create( "DLabel", panel.parent )
	DLabel:SetName( setting )
	DLabel.Client = true
	DLabel:SetPos( panel.xp+100, panel.yp )
	DLabel:SetSize( 150, 25 )
	DLabel:SetColor( Color( 255, 255, 255, 255 ))
	DLabel:SetTextColor( Color(0,0,255,255) )
	DLabel:SetFont("TnfTiny")
	DLabel:SetMouseInputEnabled( true )
	DLabel:SetText( GetKeyString(gspeak.cl.settings[setting]) )
	DLabel.DoClick = gui_key_trapper
	DLabel.Think = function ( Panel )
		if gspeak.cl.settings[setting] != Panel:GetText() then
			Panel:SetText( GetKeyString(gspeak.cl.settings[setting]) )
		end
	end
	if defaultText then
		local DLabel = vgui.Create( "DLabel", panel.parent )
		DLabel:SetPos( panel.xp+200, panel.yp )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( defaultText )
	end
end

local function get_nested(table, name)
	local function impl(names, i, tbl)
		if i < #names then return impl(names, i+1, tbl[names[i]]) end
		return tbl[names[i]]
	end

	return impl(string.Explode(".", name), 1, table)
end

local function set_nested(table, name, value)
	local function impl(names, i, tbl)
		if i < #names then impl(names, i+1, tbl[names[i]]) return end
		tbl[names[i]] = value
	end

	impl(string.Explode(".", name), 1, table)
end

local function CheckboxElem(pane, label, setting, table, multiCol)
	local DCheckBox = vgui.Create( "DCheckBox", pane.parent )
	DCheckBox:SetPos( pane.xp, pane.yp+5 )
	DCheckBox:SetValue( get_nested(table, setting) )
	DCheckBox.OnChange = function( panel )
		set_nested(table, setting, panel:GetChecked())
		if table == gspeak.settings then
			send_setting( { name = setting, value = panel:GetChecked() } )
		end
	end
	local DLabel = vgui.Create( "DLabel", pane.parent )
	DLabel:SetPos( pane.xp+25, pane.yp )
	DLabel:SetSize( 150, 25 )
	DLabel:SetText( label )
	if multiCol then
		pane.xp = pane.xp+175
		pane.resetOnRow = true
	end
end

local function SliderElem(pane, name, min, max, decs, table, label, defaultText)
	local DSlider = vgui.Create( "DNumSlider", pane.parent )
	DSlider:SetName( name )
	DSlider:SetPos( pane.xp, pane.yp )
	DSlider:SetSize( 300, 25 )
	DSlider:SetText( label )
	DSlider:SetMin( min )
	DSlider:SetMax( max )
	DSlider:SetDecimals( decs )
	DSlider:SetValue( get_nested(table, name) )
	DSlider.Think = gui_think_slider
	if defaultText then
		local DLabel = vgui.Create( "DLabel", pane.parent )
		DLabel:SetPos( pane.xp+300, pane.yp )
		DLabel:SetSize( 200, 25 )
		DLabel:SetText( defaultText )
	end
end

local function LabelElem(pane, label, hsize, vsize)
	local DLabel = vgui.Create( "DLabel", pane.parent )
	DLabel:SetPos( pane.xp, pane.yp )
	DLabel:SetSize( hsize or 125, vsize or 25 )
	DLabel:SetText( label )
end

local function ChoiceElem(pane, name, table, choices, label)
	local DLabel = vgui.Create( "DLabel", pane.parent )
	DLabel:SetPos( pane.xp, pane.yp )
	DLabel:SetSize( 50, 25 )
	DLabel:SetText( label )
	local DMulti = vgui.Create( "DComboBox", pane.parent )
	for k, v in pairs(choices) do
		DMulti:AddChoice(v)
	end
	DMulti:SetName( name )
	DMulti:SetPos( pane.xp+50, pane.yp )
	DMulti:SetSize( 100, 25 )
	DMulti:SetText( get_nested(table, name) )
	DMulti.OnSelect = gui_change
end

local function OffsetX(pane, xdist)
	pane.xp = pane.xp + xdist
end

local function ResetX(pane)
	pane.xp = pane.xbase
end

local function EndRow(pane, ydist)
	pane.yp = pane.yp + (ydist or pane.ydist)
	if pane.resetOnRow then
		ResetX(pane)
		pane.resetOnRow = false
	end
end

local function DrawContent(panel, active)
	local dsizex, dsizey = panel:GetSize()
	local txt_color = Color(255,255,255,255)
	local DermaActive = vgui.Create( "DFrame", panel )
	DermaActive:Center()
	DermaActive:SetTitle("")
	DermaActive:SetPos( 202, 0 )
	DermaActive:SetSize( dsizex - 210, dsizey )
	DermaActive.Paint = function( self, w, h )
		draw.RoundedBox( 0, 0, 0, w, h, Color( 100, 100, 100, 255 ) )
	end
	DermaActive:ShowCloseButton( false )
	local dsizex, dsizey = DermaActive:GetSize()
	local DImage = vgui.Create( "DImage", DermaActive )
	DImage:SetSize( 256, 256 )
	DImage:SetPos(dsizex-256, dsizey-256)
	DImage:SetImage( "gspeak/gspeak_logo_new.png" )
	DImage:SetImageColor(Color(255,255,255,40))

	local pane = MakeSettingPane(25, 50, 50, DermaActive)

	if active == 1 then
		KeybindElem(pane, "Talkmode Key", "key", "(default - "..GetKeyString(gspeak.settings.def_key)..")")
		if gspeak.settings.radio.use_key then
			EndRow(pane)
			KeybindElem(pane, "Radio Key", "radio_key", "(default - "..GetKeyString(gspeak.settings.radio.def_key)..")")
		end
		if gspeak.settings.dead_chat then
			EndRow(pane)
			CheckboxElem(pane, "Mute dead/spectator:", "dead_muted", gspeak.cl)
		end
	elseif active == 2 then
		SliderElem(pane, "radio.down", 1, 10, 0, gspeak.settings,
			"Radio downsampling", "def = 4 (lowering samples)")
		EndRow(pane, 25)
		SliderElem(pane, "radio.dist", 0, 10000, 0, gspeak.settings,
			"Radio distortion", "def = 1500 (cuts each sample)" )
		EndRow(pane, 25)
		SliderElem(pane, "radio.volume", 0, 3, 2, gspeak.settings,
			"Radio volume", "def = 1.5 (volume boost for the radio)")
		EndRow(pane, 25)
		SliderElem(pane, "radio.noise", 0, 0.1, 3, gspeak.settings,
			"Radio noise volume", "def = 0.010 (volume of white noise)")
		EndRow(pane)

		local choices = { "start_com", "end_com", "radio_beep1", "radio_beep2", "radio_click1", "radio_click2" }

		LabelElem(pane, "Default radio sound")
		OffsetX(pane, 125)
		ChoiceElem(pane, "radio.start", gspeak.settings, choices, "Startcom:")
		EndRow(pane, 25)
		ChoiceElem(pane, "radio.stop", gspeak.settings, choices, "Endcom:")
		EndRow(pane, 25)
		ResetX(pane)

		CheckboxElem(pane, "Trigger effect at talk", "trigger_at_talk", gspeak.settings, true)
		--EndRow(pane, 25)
		CheckboxElem(pane, "Auto add custom sounds to FastDL", "auto_fastdl", gspeak.settings)
		EndRow(pane, 25)

		CheckboxElem(pane, "Radio Key (on/off)", "radio.use_key", gspeak.settings, true)

		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetName( "radio.def_key" )
		DLabel:SetPos( pane.xp+5, pane.yp )
		DLabel:SetSize( 150, 25 )
		DLabel:SetColor( Color( 255, 255, 255, 255 ))
		DLabel:SetTextColor( Color(0,0,255,255) )
		DLabel:SetFont("TnfTiny")
		DLabel:SetMouseInputEnabled( true )
		DLabel:SetText( GetKeyString(gspeak.settings.radio.def_key) )
		DLabel.DoClick = gui_key_trapper
		DLabel.Think = function ( Panel )
			if gspeak.settings[name] != Panel:GetText() then
				Panel:SetText( GetKeyString(gspeak.settings.radio.def_key) )
			end
		end
		EndRow(pane, 25)
		LabelElem(pane, "If unchecked, radio will start sending when it's held and\nstop when it's holstered.", 325)
		EndRow(pane)

		CheckboxElem(pane, "Should radios be hearable by near players", "radio.hearable", gspeak.settings)
	elseif active == 3 then
		local AppList = vgui.Create( "DListView", DermaActive )
		AppList:SetPos( pane.xp, pane.yp )
		AppList:SetSize( 400, 150 )
		AppList:SetMultiSelect( false )
		AppList:AddColumn( "Name" ):SetFixedWidth( 75 )
		AppList:AddColumn( "Range" ):SetFixedWidth( 40 )
		AppList:AddColumn( "Icon" )
		AppList:AddColumn( "Interface" )
		AppList.Refresh = function( panel, update )
			panel:Clear()
			local update_table = {}
			for i=1, #gspeak.settings.distances.modes, 1 do
				local mode = gspeak.settings.distances.modes[i]
				AppList:AddLine( mode.name, mode.range, mode.icon, mode.icon_ui )
				update_table[i]  = { name = mode.name, range = mode.range, icon = mode.icon, icon_ui = mode.icon_ui }
			end
			if !update then return end
			send_setting( { name = "distances.modes", value = update_table } )
		end
		AppList:Refresh()
		EndRow(pane, 150)

		local xPos = pane.xp
		local yPos = pane.yp
		local diff = pane.ydist

		local function EditMode( TPanel, ID )
			local DermaPanel = vgui.Create( "DFrame" )
			DermaPanel:SetName( TPanel:GetName() )
			DermaPanel:Center()
			DermaPanel:SetSize( 325, 175 )
			DermaPanel:SetTitle( "Gspeak Config" )
			DermaPanel:SetDraggable( true )
			DermaPanel:MakePopup()

			local xPos = 25
			local diff = 25
			local yPos = 25

			local DLabel = vgui.Create( "DLabel", DermaPanel )
			DLabel:SetPos( xPos, yPos )
			DLabel:SetSize( 75, 25 )
			DLabel:SetText( "Name:" )
			local NameTextEntry = vgui.Create( "DTextEntry", DermaPanel )
			NameTextEntry:SetPos( xPos + 75, yPos )
			NameTextEntry:SetSize( 200, 25 )
			NameTextEntry:SetText( ID and gspeak.settings.distances.modes[ID].name or "" )
			yPos = yPos + diff
			local DLabel = vgui.Create( "DLabel", DermaPanel )
			DLabel:SetPos( xPos, yPos )
			DLabel:SetSize( 75, 25 )
			DLabel:SetText( "Range:" )
			local RangeTextEntry = vgui.Create( "DTextEntry", DermaPanel )
			RangeTextEntry:SetPos( xPos + 75, yPos )
			RangeTextEntry:SetSize( 200, 25 )
			RangeTextEntry:SetText( ID and gspeak.settings.distances.modes[ID].range or "" )
			yPos = yPos + diff
			local DLabel = vgui.Create( "DLabel", DermaPanel )
			DLabel:SetPos( xPos, yPos )
			DLabel:SetSize( 75, 25 )
			DLabel:SetText( "Icon:" )
			local IconTextEntry = vgui.Create( "DTextEntry", DermaPanel )
			IconTextEntry:SetPos( xPos + 75, yPos )
			IconTextEntry:SetSize( 200, 25 )
			IconTextEntry:SetText( ID and gspeak.settings.distances.modes[ID].icon or "" )
			yPos = yPos + diff
			local DLabel = vgui.Create( "DLabel", DermaPanel )
			DLabel:SetPos( xPos, yPos )
			DLabel:SetSize( 75, 25 )
			DLabel:SetText( "Interface:" )
			local IconUiTextEntry = vgui.Create( "DTextEntry", DermaPanel )
			IconUiTextEntry:SetPos( xPos + 75, yPos )
			IconUiTextEntry:SetSize( 200, 25 )
			IconUiTextEntry:SetText( ID and gspeak.settings.distances.modes[ID].icon_ui or "" )

			yPos = yPos + diff + 10
			local DButton = vgui.Create( "DButton", DermaPanel )
			DButton:SetPos( xPos, yPos )
			DButton:SetText( "Cancel" )
			DButton:SetSize( 125, 25 )
			DButton.DoClick = function()
				DermaPanel:Close()
			end
			local DButton = vgui.Create( "DButton", DermaPanel )
			DButton:SetPos( xPos+150, yPos )
			DButton:SetText( "Save" )
			DButton:SetSize( 125, 25 )
			DButton.DoClick = function()
				local insertion = {
					name = NameTextEntry:GetText(),
					range = tonumber(RangeTextEntry:GetText()),
					icon = IconTextEntry:GetText(),
					icon_ui = IconUiTextEntry:GetText()
				}

				if ID then
					gspeak.settings.distances.modes[ID] = insertion
				else
					table.insert( gspeak.settings.distances.modes, insertion);
				end

				AppList:Refresh( true )
				DermaPanel:Close()
			end
		end
		local DButton = vgui.Create( "DButton", DermaActive )
		DButton:SetPos( xPos, yPos )
		DButton:SetText( "Add" )
		DButton:SetSize( 75, 25 )
		DButton.DoClick = function( Panel )
			EditMode( Panel )
		end

		local DButton = vgui.Create( "DButton", DermaActive )
		DButton:SetPos( xPos+75, yPos )
		DButton:SetText( "Edit" )
		DButton:SetSize( 75, 25 )
		DButton.DoClick = function( Panel )
			local ID = AppList:GetSelectedLine()
			if !ID then gspeak:chat_text("you have to select an Item!", true) return end
			EditMode( Panel, ID )
		end
		local DButton = vgui.Create( "DButton", DermaActive )
		DButton:SetPos( xPos+157, yPos )
		DButton:SetText( "" )
		DButton:SetSize( 30, 25 )
		DButton.DoClick = function()
			local ID = AppList:GetSelectedLine()
			if !ID then gspeak:chat_text("you have to select an Item!", true) return end

			local temp_mode = gspeak.settings.distances.modes[ID]
			local switch_mode = gspeak.settings.distances.modes[ID-1]
			if !switch_mode or !temp_mode then return end

			gspeak.settings.distances.modes[ID-1] = temp_mode
			gspeak.settings.distances.modes[ID] = switch_mode

			AppList:Refresh( true )
			AppList:SelectItem( AppList:GetLine(ID-1) )
		end
		DButton.Paint = function() end
		local DImage = vgui.Create( "DImage", DermaActive )
		DImage:SetPos( xPos+160, yPos )
		DImage:SetSize( 20, 25 )
		DImage:SetImage( "gspeak/arrow_up.png" )

		local DButton = vgui.Create( "DButton", DermaActive )
		DButton:SetPos( xPos+187, yPos )
		DButton:SetText( "" )
		DButton:SetSize( 30, 25 )
		DButton.DoClick = function()
			local ID = AppList:GetSelectedLine()
			if !ID then gspeak:chat_text("you have to select an Item!", true) return end

			local temp_mode = gspeak.settings.distances.modes[ID]
			local switch_mode = gspeak.settings.distances.modes[ID+1]
			if !switch_mode or !temp_mode then return end

			gspeak.settings.distances.modes[ID+1] = temp_mode
			gspeak.settings.distances.modes[ID] = switch_mode

			AppList:Refresh( true )
			AppList:SelectItem( AppList:GetLine(ID+1) )
		end
		DButton.Paint = function() end
		local DImage = vgui.Create( "DImage", DermaActive )
		DImage:SetPos( xPos+187, yPos )
		DImage:SetSize( 20, 25 )
		DImage:SetImage( "gspeak/arrow_down.png" )

		local DButton = vgui.Create( "DButton", DermaActive )
		DButton:SetPos( xPos+325, yPos )
		DButton:SetText( "Remove" )
		DButton:SetSize( 75, 25 )
		DButton.DoClick = function()
			local ID = AppList:GetSelectedLine()
			if !ID then gspeak:chat_text("you have to select an Item!", true) return end

			table.remove( gspeak.settings.distances.modes, ID)
			AppList:Refresh( true )
		end

		yPos = yPos + diff - 20
		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( xPos, yPos )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( "Iconview Range" )
		local DTextEntry = vgui.Create( "DTextEntry", DermaActive )
		DTextEntry:SetName( "distances.iconview" )
		DTextEntry:SetPos( xPos+150, yPos )
		DTextEntry:SetSize( 75, 25 )
		DTextEntry:SetText( gspeak.settings.distances.iconview )
		DTextEntry.OnEnter = gui_change

		yPos = yPos + diff - 20

		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( xPos, yPos )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( "Default Radio Range" )
		local DTextEntry = vgui.Create( "DTextEntry", DermaActive )
		DTextEntry:SetName( "distances.radio" )
		DTextEntry:SetPos( xPos+150, yPos )
		DTextEntry:SetSize( 75, 25 )
		DTextEntry:SetText( gspeak.settings.distances.radio )
		DTextEntry.OnEnter = gui_change
		yPos = yPos + diff - 20

		local DSlider = vgui.Create( "DNumSlider", DermaActive )
		DSlider:SetName( "distances.heightclamp" )
		DSlider:SetPos( xPos, yPos )
		DSlider:SetSize( 300, 25 )
		DSlider:SetText( "Heightclamp" )
		DSlider:SetMin( 0 )
		DSlider:SetMax( 1 )
		DSlider:SetDecimals( 3 )
		DSlider:SetValue( gspeak.settings.distances.heightclamp )
		DSlider.Think = gui_think_slider

		yPos = yPos + diff - 20
		local DSlider = vgui.Create( "DNumSlider", DermaActive )
		DSlider:SetName( "def_mode" )
		DSlider:SetPos( xPos, yPos )
		DSlider:SetSize( 300, 25 )
		DSlider:SetText( "Default Talkmode" )
		DSlider:SetMin( 1 )
		DSlider:SetMax( #gspeak.settings.distances.modes )
		DSlider:SetDecimals( 0 )
		DSlider:SetValue( gspeak.settings.def_mode )
		DSlider.Think = gui_think_slider

		yPos = yPos + diff - 20
		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( xPos, yPos )
		DLabel:SetSize( 125, 25 )
		DLabel:SetText( "Make Ranges visible:" )
		local DCheckBox = vgui.Create( "DCheckBox", DermaActive )
		DCheckBox:SetPos( xPos+125, yPos+5 )
		DCheckBox:SetValue( gspeak.viewranges )
		DCheckBox.OnChange = function( panel )
			gspeak.viewranges = panel:GetChecked()
		end
	elseif active == 4 then
		LabelElem(pane, "Shown above head:")
		OffsetX(pane, 125)
		CheckboxElem(pane, "Icon", "head_icon", gspeak.settings, true)
		CheckboxElem(pane, "Name", "head_name", gspeak.settings, true)
		EndRow(pane)
		
		SliderElem(pane, "HUD.console.x", 0, 1, 2, gspeak.settings, "Talk UI x")
		OffsetX(pane, 300)
		ChoiceElem(pane, "HUD.console.align", gspeak.settings, { "tl", "tr", "bl", "br" }, "align:")
		ResetX(pane)
		EndRow(pane, 25)

		SliderElem(pane, "HUD.console.y", 0, 1, 2, gspeak.settings, "Talk UI y")
		EndRow(pane, 25)

		SliderElem(pane, "HUD.status.x", 0, 1, 2, gspeak.settings, "Status UI x")
		OffsetX(pane, 300)
		ChoiceElem(pane, "HUD.status.align", gspeak.settings, { "tl", "tr", "bl", "br" }, "align:")
		ResetX(pane)
		EndRow(pane, 25)

		SliderElem(pane, "HUD.status.y", 0, 1, 2, gspeak.settings, "Status UI y")
		EndRow(pane)

		CheckboxElem(pane, "Display players nick instead of name", "nickname", gspeak.settings)
	elseif active == 5 then
		pane.ydist = 40

		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( pane.xp, pane.yp )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( "Channel Password" )
		local DTextEntry = vgui.Create( "DTextEntry", DermaActive )
		DTextEntry:SetName( "password" )
		DTextEntry:SetPos( pane.xp+130, pane.yp )
		DTextEntry:SetSize( 150, 25 )
		DTextEntry:SetText( gspeak.settings.password )
		DTextEntry.OnEnter = gui_change
		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( pane.xp+300, pane.yp )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( "(less than 32 characters)" )
		EndRow(pane)

		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( pane.xp, pane.yp )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( "Command" )
		local DTextEntry = vgui.Create( "DTextEntry", DermaActive )
		DTextEntry:SetName( "cmd" )
		DTextEntry:SetPos( pane.xp+130, pane.yp )
		DTextEntry:SetSize( 150, 25 )
		DTextEntry:SetText( gspeak.settings.cmd )
		DTextEntry.OnEnter = gui_change
		EndRow(pane)

		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( pane.xp, pane.yp )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( "Talkmode Default Key" )
		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetName( "def_key" )
		DLabel:SetPos( pane.xp+130, pane.yp )
		DLabel:SetSize( 150, 25 )
		DLabel:SetColor( Color( 255, 255, 255, 255 ))
		DLabel:SetTextColor( Color(0,0,255,255) )
		DLabel:SetFont("TnfTiny")
		DLabel:SetMouseInputEnabled( true )
		DLabel:SetText( GetKeyString(gspeak.settings.def_key) )
		DLabel.DoClick = gui_key_trapper
		DLabel.Think = function ( Panel )
			if gspeak.settings[name] != Panel:GetText() then
				Panel:SetText( GetKeyString(gspeak.settings.def_key) )
			end
		end
		EndRow(pane, 50)
		
		CheckboxElem(pane, "Use GSpeak?", "enabled", gspeak.settings, true)
		EndRow(pane)
		
		CheckboxElem(pane, "Override Default Voice", "overrideV", gspeak.settings, true)
		CheckboxElem(pane, "Override Default Chat", "overrideC", gspeak.settings, true)
		EndRow(pane)

		CheckboxElem(pane, "Dead/Spectator Voicechat", "dead_chat", gspeak.settings, true)
		CheckboxElem(pane, "Should dead hear living?", "dead_alive", gspeak.settings, true)
		EndRow(pane)

		CheckboxElem(pane, "Initial move into channel?", "def_initialForceMove", gspeak.settings, true)
		CheckboxElem(pane, "Auto rename players in TS3?", "updateName", gspeak.settings, true)
		EndRow(pane)

		CheckboxElem(pane, "Should all hear commander?", "hear_channel_commander", gspeak.settings, true)
		CheckboxElem(pane, "Should dead hear non-GSpeak clients?", "hear_unknown_clients", gspeak.settings, true)
		EndRow(pane)

		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( pane.xp, pane.yp )
		DLabel:SetSize( 300, 25 )
		DLabel:SetText( "IP-Address" )
		local DTextEntry = vgui.Create( "DTextEntry", DermaActive )
		DTextEntry:SetName( "ts_ip" )
		DTextEntry:SetPos( pane.xp+130, pane.yp )
		DTextEntry:SetSize( 150, 25 )
		DTextEntry:SetText( gspeak.settings.ts_ip )
		DTextEntry.OnEnter = gui_change
		EndRow(pane, 20)

		local DLabel = vgui.Create( "DLabel", DermaActive )
		DLabel:SetPos( pane.xp, pane.yp )
		DLabel:SetSize( 450, 25 )
		DLabel:SetText( "note: Just an info for the User, Gspeak will work without an entry" )
	end
	return DermaActive
end

local function OpenConfig()
	local DMenu_active = 1
	local DermaActive
	local DermaPanel = vgui.Create( "DFrame" )
	DermaPanel:Center()
	DermaPanel:SetTitle( "Gspeak Config" )
	DermaPanel:SetDraggable( true )
	DermaPanel:MakePopup()
	DermaPanel:SetSize( 800, 400 )
	DermaPanel.Paint = function( self, w, h )
		draw.RoundedBox( 10, 0, 0, w, h, Color( 75, 75, 80, 255 ) )
	end
	local dsizex, dsizey = DermaPanel:GetSize()
	DermaPanel:SetPos( ScrW()/2-dsizex/2, ScrH()/2-dsizey/2)
	DermaPanel:ShowCloseButton( false )

	DermaActive = DrawContent(DermaPanel, DMenu_active)

	local yPos = 45
	local diff = 52
	local btn_color_idl = Color(50,50,50,255)
	local btn_color_act = Color(6,8,66,255)
	local txt_color = Color(255,255,255,255)
	local DMenu = vgui.Create( "DButton", DermaPanel )
	DMenu:SetPos( 0, yPos )
	DMenu:SetText( "User" )
	DMenu:SetFont("TnfTiny")
	DMenu:SetTextColor( txt_color )
	DMenu:SetSize( 200, diff-2. )
	DMenu.Paint = function( self, w, h )
		if DMenu_active == 1 then
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_act )
		else
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_idl )
		end
	end
	DMenu.DoClick = function()
		DermaActive:Close()
		DMenu_active = 1
		DermaActive = DrawContent(DermaPanel, DMenu_active)
	end

	yPos = yPos + 60
	local DMenu = vgui.Create( "DButton", DermaPanel )
	DMenu:SetPos( 0, yPos )
	DMenu:SetText( "Radio" )
	DMenu:SetFont("TnfTiny")
	DMenu:SetTextColor( txt_color )
	DMenu:SetSize( 200, diff-2 )
	DMenu.Paint = function( self, w, h )
		if DMenu_active == 2 then
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_act )
		else
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_idl )
		end
	end
	DMenu.DoClick = function()
		if !LocalPlayer():IsAdmin() and !LocalPlayer():IsSuperAdmin() then return end
		DermaActive:Close()
		DMenu_active = 2
		DermaActive = DrawContent(DermaPanel, DMenu_active)
	end

	yPos = yPos + diff
	local DMenu = vgui.Create( "DButton", DermaPanel )
	DMenu:SetPos( 0, yPos )
	DMenu:SetText( "Ranges" )
	DMenu:SetFont("TnfTiny")
	DMenu:SetTextColor( txt_color )
	DMenu:SetSize( 200, diff-2 )
	DMenu.Paint = function( self, w, h )
		if DMenu_active == 3 then
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_act )
		else
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_idl )
		end
	end
	DMenu.DoClick = function()
		if !LocalPlayer():IsAdmin() and !LocalPlayer():IsSuperAdmin() then return end
		DermaActive:Close()
		DMenu_active = 3
		DermaActive = DrawContent(DermaPanel, DMenu_active)
	end

	yPos = yPos + diff
	local DMenu = vgui.Create( "DButton", DermaPanel )
	DMenu:SetPos( 0, yPos )
	DMenu:SetText( "Interface" )
	DMenu:SetFont("TnfTiny")
	DMenu:SetTextColor( txt_color )
	DMenu:SetSize( 200, diff-2 )
	DMenu.Paint = function( self, w, h )
		if DMenu_active == 4 then
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_act )
		else
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_idl )
		end
	end
	DMenu.DoClick = function()
		if !LocalPlayer():IsAdmin() and !LocalPlayer():IsSuperAdmin() then return end
		DermaActive:Close()
		DMenu_active = 4
		DermaActive = DrawContent(DermaPanel, DMenu_active)
	end

	yPos = yPos + diff
	local DMenu = vgui.Create( "DButton", DermaPanel )
	DMenu:SetPos( 0, yPos )
	DMenu:SetText( "Teamspeak" )
	DMenu:SetFont("TnfTiny")
	DMenu:SetTextColor( txt_color )
	DMenu:SetSize( 200, diff-2 )
	DMenu.Paint = function( self, w, h )
		if DMenu_active == 5 then
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_act )
		else
			draw.RoundedBox( 0, 0, 0, w, h, btn_color_idl )
		end
	end
	DMenu.DoClick = function()
		if !LocalPlayer():IsAdmin() and !LocalPlayer():IsSuperAdmin() then return end
		DermaActive:Close()
		DMenu_active = 5
		DermaActive = DrawContent(DermaPanel, DMenu_active)
	end

	yPos = yPos + 60
	local DMenu = vgui.Create( "DButton", DermaPanel )
	DMenu:SetPos( 0, yPos )
	DMenu:SetText( "Close" )
	DMenu:SetFont("TnfTiny")
	DMenu:SetTextColor( txt_color )
	DMenu:SetSize( 200, diff-2 )
	DMenu.Paint = function( self, w, h )
		draw.RoundedBox( 0, 0, 0, w, h, btn_color_idl )
	end
	DMenu.DoClick = function()
		DermaPanel:Close()
	end

	local DermaActiveEdge = vgui.Create( "DFrame", DermaPanel )
	DermaActiveEdge:Center()
	DermaActiveEdge:SetTitle("")
	DermaActiveEdge:SetPos( dsizex-20, 0 )
	DermaActiveEdge:SetSize( 20, dsizey )
	DermaActiveEdge.Paint = function( self, w, h )
		draw.RoundedBox( 10, 0, 0, w, h, Color( 100, 100, 100, 255 ) )
	end
	DermaActiveEdge:ShowCloseButton( false )

	return DermaPanel
end
--ConCommand
local MainPanel
concommand.Add( "gspeak", function()
	if MainPanel and MainPanel:IsValid() then
		MainPanel:Close()
	else
		MainPanel = OpenConfig()
	end
end)
