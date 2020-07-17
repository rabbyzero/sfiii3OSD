print("fightingOSD port. by zero 2020")

local c = { --colors ARGB (not rgba)
	bg            = {fill   = 0x40000000, outline  = 0xFF000000},
	stun_level    = {normal = 0xFFFF0000, overflow = 0xFFFFAAAA},
	stun_timeout  = {normal = 0xFFFFFF00, overflow = 0xFFFFA000},
	stun_duration = {normal = 0xFF00C0FF, overflow = 0xFFA0FFFF},
	stun_grace    = {normal = 0xFF00FF00, overflow = 0xFFFFFFFF},

	green  = 0xFF00FF00,
	yellow = 0xFFFFFF00,
	pink   = 0xFFFFB0FF,
	gray   = 0xFFCCCCFF,
	cyan   = 0xFF00FFFF,
}

local show_numbers = true
local show_bars    = true

local player = {}
player[1] = {}
player[2] = {}

local cpu = manager:machine().devices[":maincpu"]
local memread = cpu.spaces["program"]
-- local rb, rw, rd = cpu.spaces["program"]:read_u8, cpu.spaces["program"]:read_u16, cpu.spaces["program"]:read_u32
-- local rbs, rws, rds = cpu.spaces["program"]:read_i8, cpu.spaces["program"]:read_i16, cpu.spaces["program"]:read_i32


playeraddr = 0x02068C6C
space = 0x498 
text = {
	life  = {offset = 0x09E, pos_X = 0x28, pos_Y = 0x08, color = c.green,
		align = "align outer", max = function(p) return memread:read_u16(p.base + 0x09C) end},
	stun  = {pos_X = 0x3C, pos_Y = 0x20, color = c.pink, 
		val = function(p) return memread:read_u16(memread:read_u32(p.base + 0x3F8) + 0x08) end, 
		max = function(p) return memread:read_u16(memread:read_u32(p.base + 0x3F8) + 0x02) end,
		condition = function(p) return memread:read_u16(0x02028808 + memread:read_u8(p.base + 0x002) * 0x18 + 0xE) == 0 end},
	stun_duration = {pos_X = 0x3C, pos_Y = 0x20, color = c.cyan, 
		val = function(p) return memread:read_u16(memread:read_u32(p.base + 0x3F8) + 0x04) end, max = 150,
		condition = function(p) return memread:read_u16(0x02028808 + memread:read_u8(p.base + 0x002) * 0x18 + 0xE) > 0 end},
	stun_recovery = {pos_X = 0x5C, pos_Y = 0x20, color = c.gray, 
		val = function(p) return memread:read_u32(memread:read_u32(p.base + 0x3F8) + 0x0C) end},
	super = {pos_X = 0x10, pos_Y = 0xD8, color = c.yellow, align = "align outer", 
		val = function(p) return memread:read_u16(memread:read_u32(p.base + 0x3F0) + 0x18) end, 
		max = function(p) return memread:read_u16(memread:read_u32(p.base + 0x3F0) + 0x16) end},
	damage_bonus  = {pos_X = 0x2C, pos_Y = 0x20, align = "align outer", 
		val = function(p) return "dmg +" .. memread:read_u16(p.base + 0x43A) end, 
		condition = function(p) return memread:read_u16(p.base + 0x43A) > 0 end},
	stun_bonus    = {pos_X = 0x2C, pos_Y = 0x28, align = "align outer", 
		val = function(p) return "stn +" .. memread:read_u16(p.base + 0x43E) end,
		condition = function(p) return memread:read_u16(p.base + 0x43E) > 0 end},
	defense_bonus = {pos_X = 0x28, pos_Y = 0x00, align = "align outer", 
		val = function(p) return "def +" .. memread:read_u16(p.base + 0x440) end,
		condition = function(p) return memread:read_u16(p.base + 0x440) > 0 end},
	juggle = {pos_X = 0x04, pos_Y = 0x00, color = c.cyan, 
		val = function(p) return "J" .. memread:read_u16(p.base + 0x3C4) end},
}
char_offset = 0x3C0
charge_chars = {
	[0x01] = {3, 4}, --Alex
	[0x09] = {0, 2}, --Oro
	[0x0D] = {0, 1, 3}, --Urien
	[0x10] = {0}, --Chun Li
	[0x12] = {0, 1}, --Q
	[0x14] = {0, 1, 2}, --Remy
}
charge_base = 0x020259D4
charge_space = 0x620 
match_status = 0x020154A6


local functionize = function(param)
	if type(param) == "number" then
		return (function() return param end)
	end
	return param
end

for _, text in pairs(text or {}) do
	if text.offset then
		text.val = function(p) return memread:read_u16(p.base + text.offset) end
	end
	text.max = functionize(text.max)
	text.pos_X = functionize(text.pos_X)
	text.pos_Y = functionize(text.pos_Y)
	text.condition = text.condition or function() return true end
end

local get_player_base = {
	["direct"] = function(p)
		return playeraddr + (p-1)*space
	end,

	["pointer"] = function(p)
		return memread:read_u32(player_ptr + (p-1)*space)
	end,
}

-- base_type = player_ptr and "pointer" or "direct"
base_type = "direct"

local function player_active()
	return true
end

X_offset = {0,0}
Y_offset = {0,0}

s = manager:machine().screens[":screen"]

local screenwidth = s:width()
local screenheight = s:height()


-- local set_bar_text_X = {
-- 	["align inner"] = function(text) --default
-- 		return game.stun_bar.pos_X + game.stun_bar.length + 0x4
-- 	end,

-- 	["align outer"] = function(text)
-- 		return game.stun_bar.pos_X - string.len(text) * 4 - 0x4
-- 	end,
-- }


local set_text_X = {
	["align inner"] = function(p, text) --default
		return screenwidth/2 + p.side * (text.X + p.X_offset) - (p.side < 1 and 1 or 0) * text.width
	end,

	["align outer"] = function(p, text)
		return (p.side < 1 and 0 or 1) * (screenwidth - text.width) - p.side * text.X
	end,
}


local set_bar_base = {
	["align inner"] = function(p) --default
		return screenwidth/2, p.side
	end,

	["align outer"] = function(p)
		return (p.side < 1 and 0 or 1) * screenwidth, -p.side
	end,
}

local function set_bar_params(p, bar)
	bar.X = bar.X + p.X_offset
	bar.top = bar.Y + p.Y_offset
	bar.bottom = bar.top + bar.height
	bar.bg_inner = bar.base + bar.side * bar.X
	bar.bg_outer = bar.base + bar.side * (bar.X + bar.length)
	if bar.data.val == 0 then
		return
	end
	bar.normal_inner = bar.bg_inner
	bar.normal_outer = bar.data.val/bar.data.max >= 1 and bar.bg_outer or 
		bar.base + bar.side * (bar.X + bar.data.val/bar.data.max%1 * bar.length)
	if bar.data.val/bar.data.max < 1 then
		return
	end
	bar.over_inner = bar.bg_inner
	bar.over_outer = bar.base + bar.side * (bar.X + bar.data.val/bar.data.max%1 * bar.length)
end

local function special(p)
	local pos_X, pos_Y, max = 0x04, 0x30, 0x2A
	local length, height, space = max, 0x03, 0x08
	p.char = memread:read_u16(p.base + char_offset)
	for _, slot in ipairs(charge_chars[p.char] or {}) do
		local charge_base = charge_base + memread:read_u8(p.base + 0x002) * charge_space + 0x1C * slot
		local charge_level = {X = pos_X + length + 0x4, Y = pos_Y, align = "align outer", 
			val = max - memread:read_i16(charge_base + 0x4), max = max + 1, color = c.pink}
		local top_bar = {X = screenwidth/2 - length - pos_X, Y = pos_Y, 
			length = length, height = height, data = charge_level, color = c.stun_level}
		if charge_level.val >= max then
			charge_level.color = c.green
			top_bar.color = c.stun_grace
		end
		table.insert(p.text, charge_level)
		table.insert(p.bar, top_bar)
		local charge_timeout = {X = pos_X + length + 0xE, Y = pos_Y, align = "align outer", 
			val = memread:read_i16(charge_base + 0x2) + 1, max = max, color = c.yellow}
		local bottom_bar = {X = screenwidth/2 - length - pos_X, Y = pos_Y + height, 
			length = length, height = height, data = charge_timeout, color = c.stun_timeout}
		if memread:read_u16(charge_base) == 0x1 then
			charge_timeout.color = c.cyan
			bottom_bar.color = c.stun_duration
		end
		table.insert(p.text, charge_timeout)
		table.insert(p.bar, bottom_bar)
		pos_Y = pos_Y + space
	end
end


local get_char_data = function(p)
	for _, text in pairs(text or {}) do
		if text.condition(p) then
			local data = {X = text.pos_X(p), Y = text.pos_Y(p), color = text.color, 
				align = text.align, val = text.val(p), max = text.max and text.max(p)}
			if text.max then
				data.max = text.max(p)
				data.val = (data.val > data.max and "-" or data.val) .. "/" .. data.max
			end
			table.insert(p.text, data)
		end
	end

	special(p)

	-- if not game.stun_bar then
	-- 	return
	-- end

	-- p.text.stun_level = {Y = game.stun_bar.pos_Y - 2, align = game.stun_bar.align}
	-- p.text.stun_level.val, p.text.stun_level.max = game.stun_bar.level(p)
	-- p.bar.stun_level = {X = game.stun_bar.pos_X, Y = game.stun_bar.pos_Y, 
	-- 	length = game.stun_bar.length, height = game.stun_bar.height, 
	-- 	data = p.text.stun_level, align = game.stun_bar.align, color = c.stun_level}

	-- p.text.stun_timeout = {Y = game.stun_bar.pos_Y + 6, align = game.stun_bar.align}
	-- p.bar.stun_timeout = {X = game.stun_bar.pos_X, Y = game.stun_bar.pos_Y + game.stun_bar.height, 
	-- 	length = game.stun_bar.length, height = game.stun_bar.height, 
	-- 	data = p.text.stun_timeout, align = game.stun_bar.align}

	-- p.state, p.text.stun_timeout.val, p.text.stun_timeout.max = game.stun_bar.timeout(p)
	-- if p.state == "countdown" then
	-- 	p.bar.stun_timeout.color = c.stun_duration
	-- elseif p.state == "grace" then
	-- 	p.bar.stun_timeout.color = c.stun_grace
	-- else
	-- 	p.bar.stun_timeout.color = c.stun_timeout
	-- end

	-- p.text.stun_level.display = p.text.stun_level.val
	-- if p.state == "precountdown" or p.state == "countdown" then
	-- 	p.text.stun_level.val = p.text.stun_level.max
	-- 	p.text.stun_level.display = "-"
	-- end
	-- p.text.stun_level.display = p.text.stun_level.display .. "/" .. p.text.stun_level.max
	-- p.text.stun_level.X   = set_bar_text_X[game.stun_bar.align](p.text.stun_level.display)
	-- p.text.stun_timeout.X = set_bar_text_X[game.stun_bar.align](p.text.stun_timeout.val)
end

local function updateOSD()
	nplayers = 2
	for p = 1, nplayers do
		player[p].base = get_player_base[base_type](p)
		player[p].active = player_active(player[p])
		if p == 1 then 
			player[p].side = -1
			else
			player[p].side = 1
		end
		-- player[p].side = bit.band(p, 1) > 0 and -1 or 1
		player[p].X_offset = X_offset[p]
		player[p].Y_offset = Y_offset[p]
	end
	-- swap_sides(player)
	for p = 1, nplayers do
		local p = player[p]
		p.bar, p.text = {}, {}
		if p.active then
			get_char_data(p)
		end
		for _, text in pairs(p.text) do
			text.display = text.display or text.val
			text.width = 4 * string.len(text.display)
			text.X = set_text_X[text.align or "align inner"](p, text)
			text.Y = text.Y + p.Y_offset
		end
		for _, bar in pairs(p.bar) do
			bar.base, bar.side = set_bar_base[bar.align or "align inner"](p)
			set_bar_params(p, bar)
		end
		local bar = p.bar.stun_level
		if bar then
			p.stun_X = bar.base + bar.side * (bar.X + bar.length/2) - 13
			p.stun_Y = bar.Y - 1
		end
	end
end

local function show_OSD()
	local match = memread:read_u32(match_status)
	return match > 0x00010003 and match < 0x00090000
end

local draw_player_objects = function(p)
	if show_bars then
		for _, bar in pairs(p.bar) do
			s:draw_box(bar.bg_inner, bar.top, bar.bg_outer, bar.bottom, c.bg.fill, c.bg.outline)
			if bar.normal_outer then
				s:draw_box(bar.normal_inner, bar.top, bar.normal_outer, bar.bottom, bar.color.normal, 0)
			end
			if bar.over_outer then
				s:draw_box(bar.over_inner, bar.top, bar.over_outer, bar.bottom, bar.color.overflow, 0)
			end
		end
		-- if (p.state == "precountdown" or p.state == "countdown") and bit.band(emu.framecount(), 2) > 0 then
		-- 	draw_stun(p)
		-- end
	end
	if show_numbers then
		for _, text in pairs(p.text) do
			s:draw_text(text.X, text.Y, text.display, text.color)
		end
	end
end

local draw_OSD = function()
	if not show_OSD() then
		return
	end
	for p = 1, nplayers do
		if player[p].active then
			draw_player_objects(player[p])
		end
	end
end


local function mainloop()
	updateOSD()
	draw_OSD()
end

emu.register_frame_done(mainloop)