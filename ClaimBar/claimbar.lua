_addon.author   = 'Jaza (Jaza#6599)';
_addon.name     = 'ClaimBar';
_addon.version  = '0.5.0';

require 'common'
require 'd3d8'
require 'imguidef'

-- Default config.
-- Recommend to leave as is and override in json instead
local config = {
    theme = 'darksouls',
    max_bar = 1,
    scale = 1.0,
    anim_time = 0.6 -- seconds
};
local theme_config = {}
local images = {}
local fonts = {}
local icons = {}
local claimed = {}
local render_flags = ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoTitleBar

local fps = { }
fps.count = 0
fps.timer = 0
fps.frame = 0

local anim = {}
-- anim[entity_id] = {hpp=hpp, tween={0.0 -> 1.0}, pause=8}
--
--

----------------------------------
--     event and main loop      --
----------------------------------
ashita.register_event('load', function()
    config = ashita.settings.load_merged(_addon.path..'claimbar_settings.json', config);
    load_icons()
    load_theme()
end);


ashita.register_event('render', function()
    fps.count = fps.count + 1;
    if (os.time() >= fps.timer + 1) then
        fps.frame = fps.count;
        fps.count = 0;
        fps.timer = os.time();
    end

    main_loop()

end);


ashita.register_event('unload', function()
    ashita.settings.save(_addon.path..'/claimbar_settings.json', config);
end);


ashita.register_event('command', function(cmd, nType)
    local args = cmd:args()
	if (#args == 0 ) then
		return false
	end

    if (string.lower(args[1]) ~= '/claimbar' and string.lower(args[1]) ~= '/cb') then
        return false
    end

    if (#args > 1) then
        local cmd = string.lower(args[2])

        if (cmd == 'scale') then
            if (args[3] == nil or tonumber(args[3]) == nil) then
                print('[|ClaimBar] current scale --> '..config.scale)
                return false
            end
            local scale = tonumber(args[3])
            if (scale <= 0) then
                print('[|ClaimBar] scale cannot be 0 or negative')
                return false
            end
            print('[|ClaimBar] set scale --> '.. scale)
            config.scale = scale
            return true
        
        elseif (cmd == 'anim') then
            if (args[3] == nil or tonumber(args[3]) == nil) then
                print('[|ClaimBar] Current anim length --> '..config.anim)
                return false
            end
            local sec = tonumber(args[3])
            if (sec < 0 ) then
                print('[|ClaimBar] anim cannot be negative')
                return false
            end
            print('[|ClaimBar] setting anim length --> '.. sec ..' seconds')
            config.anim = sec
            return true
        
        elseif (cmd == 'bars') then
            if (args[3] == nil or tonumber(args[3]) == nil) then
                print('[|ClaimBar] Current bar limit --> '..config.max_bar)
                return false
            end
            local bars = math.floor(tonumber(args[3]))
            if (bars < 1) then
                print('[|ClaimBar] Minimum bar is 1')
                return false
            end
            print('[|ClaimBar] setting max bar --> '.. bars)
            config.max_bars = bars
            return true

        elseif (cmd == 'theme') then
            if (args[3] == nil) then
                print('[|ClaimBar] Pick a theme')
                print('[|ClaimBar] 1 -> Darksouls')
                print('[|ClaimBar] 2 -> CustomHud')
                return false
            end
            local theme = nil
            if (args[3] == '1') then theme = 'darksouls' end
            if (args[3] == '2') then theme = 'customhud' end
            if (theme ~= nil) then
                config.theme = theme
                print('[ClaimBar] set theme -->' ..config.theme)
                load_theme()
                return true
            end
            return false

        elseif (cmd == 'test') then
            test()
            return true
        end
    end

    return false
end);


function main_loop()
    local party = AshitaCore:GetDataManager():GetParty();
    if (party:GetMemberActive(0) == false or party:GetMemberServerId(0) == 0) then
        return;
	end

    -- store id as hashtable for quick easy search
    local party_ids = {}
    for x = 0, 17 do
        local member_id = AshitaCore:GetDataManager():GetParty():GetMemberServerId(x)
        if (member_id > 0) then
            party_ids[member_id] = true;
        end
    end

    -- loop for possible entities, check their claim id against party's id
    claimed = {}
    for x = 0, 2303 do
        local e = GetEntity(x);
        if (e ~= nil and e.WarpPointer ~= 0) then
            if (e.ClaimServerId ~= 0) then
                if (party_ids[e.ClaimServerId] == true) then
                    table.insert(claimed, e)
                    if (#claimed >= config.max_bar) then break; end
                end
            end
        end
    end
    
    if (#claimed == 0) then return; end


    imgui.Begin(
		'claimbar',
		nil,1,1,0,render_flags -- bool p_open, init size x2, bg alpha, flags
	)
    for index, entity in pairs(claimed) do
        draw_bar(index, entity)
    end
    imgui.End()
end


----------------------------------
--    utilities and functions   --
----------------------------------
function load_icons()
    local template = _addon.path..'\\icons\\{X}.png'
    local sub = '{X}'
end

function load_theme()
    theme_config = {}
    images = {}
    theme_config = ashita.settings.load_merged(
        _addon.path..'themes\\'..config.theme.."\\theme_settings.json",
        theme_config)
    load_images()
end

function load_images()
    local template = _addon.path..'themes\\'..config.theme..'\\{X}.png'
    local sub = '{X}'

    local elem = {"bar_fg", "bar_bg"}

    for i, e in pairs(elem) do
        local path = template:gsub(sub, e)
        images[e] = {}
        images[e].w, images[e].h = png_width_height(path)
        images[e].tx = create_texture(path)
    end

    elem = "abcdefghijklmnopqrstuvwxyz()'-"
    template = _addon.path..'themes\\'..config.theme..'\\font\\{X}.png'
    for i = 1, #elem do  
        local c = string.sub(elem, i, i) 
        local path = template:gsub(sub, c)
        images[c] = {}
        images[c].w, images[c].h = png_width_height(path)
        images[c].tx = create_texture(path)
    end

    elem = {'ellipsis', 'dot', 'space'}
    for i, c in pairs(elem) do
        local path = template:gsub(sub, c)
        images[c] = {}
        images[c].w, images[c].h = png_width_height(path)
        images[c].tx = create_texture(path)
    end

    elem = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    template = _addon.path..'themes\\'..config.theme..'\\font\\{X}.png'
    for i = 1, #elem do  
        local c = string.sub(elem, i, i) 
        local path = template:gsub(sub, c:lower()..c:lower())
        images[c] = {}
        images[c].w, images[c].h = png_width_height(path)
        images[c].tx = create_texture(path)
    end

end

function draw_bar(index, entity)
    local id = entity.ServerId
    local name = entity.Name
    local hpp = entity.HealthPercent/100
    local bg = images.bar_bg
    local fg = images.bar_fg
    local x, y = 0, (index-1) * theme_config.height_per_target * config.scale
    if (hpp > 0 ) then
        r,g,b = 1,1,1
    else
        r,g,b = 0.4,0.4,0.4
    end

    x = x + (theme_config.bar_bg.x * config.scale)
    y = y + (theme_config.bar_bg.y * config.scale)
    imgui.SetCursorPos(x, y)
    imgui.Image(
        bg.tx:Get(),
        bg.w * config.scale,
        bg.h * config.scale,
        0,0,1,1, -- UV1
        r,g,b,1 -- Color
    )

    x = x + (theme_config.bar_fg.x * config.scale)
    y = y + (theme_config.bar_fg.y * config.scale)
    if (hpp > 0) then
        imgui.SetCursorPos(x, y)
        imgui.Image(
            fg.tx:Get(),
            fg.w * config.scale * hpp,
            fg.h * config.scale,
            0,0,hpp,1, -- UV1
            r,g,b,1 -- Color
        )
    end

    -- animation --
    if (theme_config.anim ~= nil and theme_config.anim.enable == true) then
        local diff = 0
        local frames = math.floor(config.anim_time * fps.frame)

        if (anim[id] == nil or hpp > anim[id].hpp) then 
            anim[id] = {hpp=hpp, pause=0, tween={}}
        end
        
        if (hpp < anim[id].hpp) then

            diff = anim[id].hpp - hpp
            anim[id].tween = {}
            for i= 0, frames do
                table.insert(
                    anim[id].tween,
                    outQuad(i, anim[id].hpp, -diff, frames))
            end
            -- for i = 1, frames do
            --     table.insert(anim[id].tween, 1, anim[id].tween[1])
            -- end
            anim[id].pause = frames
            anim[id].hpp = hpp
            -- for i, v in pairs(anim[id].tween) do print(v) end
        end

        local loss_hp = 0
        local x_offset = 0
        if (#anim[id].tween > 0) then
            loss_hp = anim[id].tween[1]
            if (anim[id].pause <= 0 ) then
                table.remove(anim[id].tween, 1)
            else
                anim[id].pause = anim[id].pause - 1
            end
            x_offset = x + (fg.w * hpp * config.scale) 
            imgui.SetCursorPos(x_offset, y)
            imgui.Image(
                fg.tx:Get(),
                fg.w * config.scale * (loss_hp-hpp),
                fg.h * config.scale,
                0,0,(loss_hp-hpp),1, -- UV1
                theme_config.anim.r,
                theme_config.anim.g,
                theme_config.anim.b,
                theme_config.anim.a
            )
        end
    end

    -- if (anim[id].hpp == 0 and #anim[id].tween == 0) then
    --     anim[id] = nil
    -- end
    
    y = (index-1) * theme_config.height_per_target * config.scale
    imgui.SetCursorPos(theme_config.name.x, theme_config.name.y + y)
    imgui.Text('')
    local txt = ''
    for i = 1, #name do  
        if (i > theme_config.max_char) then
            txt = 'ellipsis'
        else
            txt = string.sub(name, i, i) 
            if (txt ==' ') then txt = 'space' end
            if (txt == '.') then txt = 'dot' end
        end
        
        imgui.SameLine(0, 0)
        imgui.Image(
            images[txt].tx:Get(),
            images[txt].w * config.scale,
            images[txt].h * config.scale,
            0,0,1,1,
            r,g,b,1
        )
        if (i > theme_config.max_char) then break; end
    end
end


function png_width_height(png_path)
    -- Credit to https://sites.google.com/site/nullauahdark/getimagewidthheight
    -- print('attemping to load -> '.. png_path)
    local fileio = io.open(png_path)
    if (fileio == nil) then 
        print('error loading -> '..png_path)
    end

    local width,height = 0,0

    local function refresh()
		if type(fileinfo)=="number" then 
            fileio:seek("set",fileinfo)
        else fileio:close() end
	end

	fileio:seek("set",1)
	if fileio:read(3)=="PNG" then
		fileio:seek("set",16)
		local widthstr,heightstr=fileio:read(4),fileio:read(4)
		if type(fileinfo)=="number" then
			fileio:seek("set",fileinfo)
		else
			fileio:close()
		end
		width=widthstr:sub(1,1):byte()*16777216+widthstr:sub(2,2):byte()*65536+widthstr:sub(3,3):byte()*256+widthstr:sub(4,4):byte()
		height=heightstr:sub(1,1):byte()*16777216+heightstr:sub(2,2):byte()*65536+heightstr:sub(3,3):byte()*256+heightstr:sub(4,4):byte()
	end
    return width,height
end


function create_texture(filepath)
    local res, texture = ashita.d3dx.CreateTextureFromFileA(filepath)
	if (res ~= 0) then
		local _, err = ashita.d3dx.GetErrorStringA(res)
        print(string.format('[|ClaimBar Error] Failed to load background texture for slot: %s - Error: (%08X) %s', path, res, err))
        return nil
	end
	return texture
end

-- tween function from https://github.com/nicolausYes
-- t = current time
-- b = first value
-- c = first - last value
-- d = how long it lasted
function outQuad(t, b, c, d)
    t = t / d
    return -c * t * (t - 2) + b
end

---------------------------------------------------------------
function test()
    print(images['ellipsis'].tx)
end


