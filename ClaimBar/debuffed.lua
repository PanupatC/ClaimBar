--[[
* Credits to the original creators Auk/beauxq. I'm sorry for
* not knowing the links to their repository. I grabbed this 
* addon from Ashita Discord. Google failed to give me
* relevant results.
*
* _addon.author   = 'Auk / beauxq';
* _addon.name     = 'debuffed';
* _addon.version  = '2.1.2';
*
* Ashita Discord = https://discord.gg/Ashita
*
]]--

require 'common'

local frame_time = 0;
local targeted_mobs = {};
local lookingForName = 0;  -- ID of unknown ability name
local timeStartLooking;
local lookingForNameMobName = nil;
local nameFromServerId = {};

local res = AshitaCore:GetResourceManager()

local helixes = {278,279,280,281,282,283,284,285,
    885,886,887,888,889,890,891,892}

local bolt_names = {
    [1032] = "Sleep Bolt",
    [1033] = "Venom Bolt",
    [1035] = "Blind Bolt",
    [1149] = "Acid Bolt"
}

local debuffs = {
    [2] = {253,259,273,678, 1032}, --Sleep -- status bolts need to be last
    [3] = {220,221,225,350,351,716, 1033}, --Poison
    [4] = {58,80,341,644,704}, --Paralyze
    [5] = {254,276,347,348, 1035}, --Blind
    [6] = {59,687,727}, --Silence
    [7] = {255,365,722}, --Break
    [10] = {252}, -- stun
    [11] = {258,531}, --Bind
    [12] = {216,217,708}, --Gravity
    [13] = {56,79,344,345,703}, --Slow
    [19] = {259},  -- sleep2 (might be a dsp bug (not [2]))
	[21] = {286,472,884}, --addle/nocturne
	[28] = {575,720,738,746}, --terror
	[31] = {682}, --plague
    [33] = {1}, --haste
    [34] = {249},  -- blaze spikes
    [35] = {250},  -- ice spikes
    [37] = {54},  -- stoneskin?
    [38] = {251},  -- shock spikes
    [40] = {43,44,45,46},  -- protect
    [41] = {48,49,50,51,134},  -- shell
    [42] = {1},  -- regen
    [95] = {101},  -- enblizzard
    [97] = {103},  -- enstone
    [98] = {104},  -- enthunder
    [128] = {235}, -- burn
    [129] = {236}, -- frost
    [130] = {237}, -- choke
    [131] = {238}, -- rasp
    [132] = {239}, -- shock
    [133] = {240}, -- drown
	[136] = {240,705}, --str down
	[137] = {238}, --dex down
	[138] = {237}, --VIT down
	[139] = {236,535}, --AGI down
	[140] = {235,572,719}, --int down
	[141] = {239}, --mnd down
	[146] = {524,699}, --accuracy down
	[147] = {319,651,659,726}, --attack down
    [148] = {610,841,842,882}, --Evasion Down
	[149] = {651,717,728, 1149}, -- defense down
	[156] = {112,707,725}, --Flash
	[167] = {656}, --Magic Def. Down
	[168] = {508}, --inhibit TP
	[192] = {368,369,370,371,372,373,374,375}, --requiem
	[193] = {463,471,376,377}, --lullabies
	[194] = {421,422,423}, --elegy
	[195] = {1}, -- paeon 3?
	[217] = {454,455,456,457,458,459,460,461,871,872,873,874,875,876,877,878}, --threnodies
    [404] = {843,844,883}, --Magic Evasion Down
	[597] = {879}, --inundation

}

-- retail priority
local hierarchy = {
    [23] = 1, --Dia
    [24] = 3, --Dia II
    [25] = 5, --Dia III
    [230] = 2, --Bio
    [231] = 4, --Bio II
    [232] = 6, --Bio III
}
--[[ kupo bugged priority
local hierarchy = {
    [23] = 1, --Dia
    [24] = 2, --Dia II
    [25] = 3, --Dia III
    [230] = 4, --Bio
    [231] = 5, --Bio II
    [232] = 6, --Bio III
}
]]--

----------------------
----- ADDED CODE -----
----------------------
local hello = 'Hello!' 


function dtest()
    print(for_debuff)
end


function get_debuffs_from_entity(e)
    local debuffs = {
        buff = {},
        debuff = {}
    }
    local tbl = targeted_mobs[e.ServerId]

    if not tbl then return debuffs; end

    for effect, spell in pairs(tbl) do
        if (spell and spell.id ~= nil) then
            if is_buff(spell.id) then
                table.insert(debuffs.buff, effect)
            else
                table.insert(debuffs.debuff, effect)
            end
        end
    end
    return debuffs
end

---------------------
---- DEBUFFED.LUA ---
---------------------

---- PACKET ----
function debuffed_incoming_text(mode, message, modifiedmode, modifiedmessage, blocked)
    if (string.sub(message, 1, 3) == "===") then  -- zone change
        targeted_mobs = {};
        nameFromServerId = {};
        lookingForName = 0;
    elseif lookingForName ~=0 then
        if timeStartLooking + 9 < os.time() then
            -- if we look for more than 9 seconds, give up
            lookingForName = 0;
            return false;
        end
        local name = pullAbilityName(message);
        if name ~= nil then
            debuffed_config.abilityNames[tostring(lookingForName)] = name;
            lookingForName = 0;
            -- print("time to find name: " .. os.time() - timeStartLooking);
        end
    end
end


function debuffed_incoming_packet(id, size, data)
    if id == 0x028 then
        inc_action(unpackaction(data));  -- status on
    elseif id == 0x029 then
        local arr = {}
        arr.target_id = get_bit_packed(data,(0x09 - 1) * 8,(0x09 - 1) * 8 + 32)
        arr.param_1 = get_bit_packed(data,(0x0D - 1) * 8,(0x0D - 1) * 8 + 32)
        arr.message_id = get_bit_packed(data,(0x19 - 1) * 8,(0x19 - 1) * 8 + 32)%32768  -- ? different from 'H' in original
        
        inc_action_message(arr);  -- status wear off
    --elseif id == 13 then
        --local packetTable = dataToPacketTable(data, size);
        --print(myDump(packetTable));
    --elseif id ~= 14 then
        --print("packet id: " .. id);
    end
end

---- FUNCTIONS ----
function is_buff(spellId)
    if spellId > 3000 then
        return true;  -- don't know what this might do for BST
    elseif spellId > 1023 then
        return false;
    else
        return res:GetSpellById(spellId).ValidTargets % 2 == 1;
    end
end

function get_spell_name(id)
    if id > 3000 then
        local name = debuffed_config.abilityNames[tostring(id)];
        if name == nil then
            return "unknown name";
        else
            return name;
        end
    elseif id > 1023 then
        return bolt_names[id];
    else
        return res:GetSpellById(id).Name[0];
    end
end

function get_duration(id)
    local string_id = get_spell_name(id);

    if debuffed_config.durations[string_id] then
        return debuffed_config.durations[string_id]
    else
        return 0
    end
end


function set_duration(id, seconds)
    local string_id = get_spell_name(id);
    if string_id == "unknown name" then
        return;
    end
    
    -- don't overwrite an integer unless it's 0
    if debuffed_config.durations[string_id] and
       debuffed_config.durations[string_id] == math.floor(debuffed_config.durations[string_id]) and
       debuffed_config.durations[string_id] ~= 0 then
        return;
    else
        debuffed_config.durations[string_id] = seconds;
    end
end


function contains(items, value)
    for _,v in pairs(items) do
        if v == value then
            return true;
        end
    end
    return false;
end


function apply_dot(target, spell)
    if not targeted_mobs[target] then
        targeted_mobs[target] = {}
    end

    local priority = 0
    local id134 = nil
    if targeted_mobs[target][134] then
        id134 = targeted_mobs[target][134].id
    end
    local id135 = nil
    if targeted_mobs[target][135] then
        id135 = targeted_mobs[target][135].id
    end
    local current = id134 or id135
    if current then
        priority = hierarchy[current]
    end

    if hierarchy[spell] > priority then
        if contains({23,24,25}, spell) then
            targeted_mobs[target][134] = {id = spell, timer = os.clock() + get_duration(spell)}
            targeted_mobs[target][135] = nil
        elseif contains({230,231,232}, spell) then
            targeted_mobs[target][134] = nil
            targeted_mobs[target][135] = {id = spell, timer = os.clock() + get_duration(spell)}
        end
    end
end


function apply_helix(target, spell)
    if not targeted_mobs[target] then
        targeted_mobs[target] = {}
    end
    targeted_mobs[target][186] = {id = spell, timer = os.clock() + 230}
end


function show_bio(target_table)
    if target_table then
        if target_table[134] and target_table[134] == 25 then
            return false
        elseif target_table[135] and (target_table[135] == 231 or target_table[135] == 232) then
            return false
        end
    end
    return true
end


function inc_action(act)
    -- 4 spell - 11 mob tp move end
    if act.category == 4 or act.category == 11 then
        --print("4 or 11");
        local targetIndex = 1;
        while act.targets[targetIndex] do  -- for each target
            --print("while loop targetIndex: " .. targetIndex);
            local message = act.targets[targetIndex].actions[1].message;
            if message == 2 or message == 252 then
                if contains({23,24,25,230,231,232}, act.param) then
                    apply_dot(act.targets[targetIndex].id, act.param)
                elseif contains(helixes, act.param) then
                    apply_helix(act.targets[targetIndex].id, act.param)
                end
            --                       230 is buff(ice spikes) 278 is horde lullaby secondary target
            --                   186 is TP buff          277 is sleepga secondary target
            --               101 is mob 2hr
            elseif contains({101,186,230,236,237,268,271,277,278}, message) then
                local effect = act.targets[targetIndex].actions[1].param;
                local target = act.targets[targetIndex].id;
                local spell = act.param;

                if act.category == 11 then  -- mob tp move end or mob 2hr
                    --print("cat: " .. act.category .. "  spell: " .. spell .. "  effect: " .. effect);
                    spell = spell + 3000;
                    if debuffed_config.abilityNames[tostring(spell)] == nil then
                        lookingForName = spell;
                        timeStartLooking = os.time();
                        lookingForNameMobName = nameFromServerId[act.actor_id];
                        -- print("actor id: " .. act.actor_id);
                        -- print("looking for name of ability: " .. spell .. "  from mob: " .. lookingForNameMobName);  -- this will crash if I don't target the mob before seeing it tp
                    end
                end

                if not targeted_mobs[target] then
                    targeted_mobs[target] = {};
                end

                if true then
                --if debuffs[effect] and contains(debuffs[effect], spell) then
                    -- special cases for mismatch between effect on and effect off
                    if spell == 259 then effect = 2  -- sleep 2
                    elseif spell == 274 then effect = 2  -- sleepga 2
                    elseif spell == 463 then effect = 2  -- lullaby
                    elseif spell == 376 then effect = 2  -- horde lullaby
                    end
                    
                    is_buff(spell);
                    
                    --print("adding debuff spell: " .. spell .. "  effect: " .. effect);
                    targeted_mobs[target][effect] = {id = spell, timer = os.clock() + get_duration(spell)}
                elseif debuffs[effect] then
                    print("known effect: " .. effect .. " but unknown spell: " .. spell);
                else
                    print("unknown effect: " .. effect);
                end
            elseif contains({341, 83}, message) then  -- 341 is erase removing something (at least bind), 83 is -na removing something (at least blind)
                local effect = act.targets[targetIndex].actions[1].param;
                local target = act.targets[targetIndex].id;

                if targeted_mobs[target] then
                    targeted_mobs[target][effect] = nil;
                end
            else
                -- TODO: find protectra secondary target
                -- TODO: find mazurka and other songs secondary targets
                -- message 75 is "no effect"
                -- message 85 is "resist"
                --print("category 4, but not known message: " .. message)
                --local effect = act.targets[targetIndex].actions[1].param;
                --local target = act.targets[targetIndex].id;
                --local spell = act.param;
                --print("eff: " .. effect .. "  target: " .. target .. "  spell" .. spell);
            end
            
            targetIndex = targetIndex + 1;
        end  -- while for all targets
    -- status bolts
    elseif act.category == 2 and
           act.targets[1].actions[1].has_add_effect and
           act.targets[1].actions[1].add_effect_message == 160 then
        --print("add eff 160")
        local effect = act.targets[1].actions[1].add_effect_param
        local target = act.targets[1].id
        local spell = debuffs[effect][#(debuffs[effect])]  -- last thing in the list of spells for the effect

        if not targeted_mobs[target] then
            targeted_mobs[target] = {}
        end

        if debuffs[effect] and contains(debuffs[effect], spell) then
            targeted_mobs[target][effect] = {id = spell, timer = os.clock() + get_duration(spell)}
        end
    --[[
    elseif act.category == 11 then  -- mob tp move end
        print("category 11 spell Id: " .. act.param);
        print("name: " .. res:GetAbilityById(act.param).Name[0]);
        print("message: " .. act.targets[1].actions[1].message);
        print("effect: " .. act.targets[1].actions[1].param);
        print("target: " .. act.targets[1].id);
    ]]--
    --[[
    elseif act.category ~= 1 then
        print("cat: " .. act.category);
    ]]--
    end
    --if act.targets[1].actions[1].has_add_effect then
    --    print(act.category)
    --    print(act.targets[1].actions[1].add_effect_message)
    --end
end


function inc_action_message(arr)
    if contains({6,20,113,406,605,646}, arr.message_id) then
        targeted_mobs[arr.target_id] = nil
    elseif contains({204,206}, arr.message_id) then
        --print("got recognizeed wear off message: " .. arr.message_id .. " param_1: " .. arr.param_1);
        if targeted_mobs[arr.target_id] then
            spell = targeted_mobs[arr.target_id][arr.param_1]
            if spell and type(spell) == 'table' then
                time = spell.timer - os.clock()
                if time < 0 then
                    set_duration(spell.id, get_duration(spell.id) - time)
                end
            end
            targeted_mobs[arr.target_id][arr.param_1] = nil
        end
    else
        -- print("unknown message_id in wear off: " .. arr.message_id);
    end
end


function hasNonStringIndex(T)
    for i, v in pairs(T) do
        if type(i) ~= "string" then return true end
    end
    return false
end


local function pullAbilityName(message)
    local mobNameEnd, uses = string.find(message, " uses ", 1, true);
    if uses == nil then return nil; end

    mobNameEnd = mobNameEnd - 1;
    local mobNameStart = 1;
    if string.sub(message, 1, 4) == "The " then
        -- print("found 'The ' at the beginning of the line");
        mobNameStart = 5;
    end
    local mobName = string.sub(message, mobNameStart, mobNameEnd);
    -- print("found mob name: " .. mobName);
    if mobName ~= lookingForNameMobName then return nil; end

    uses = uses + 1;
    -- print("abi name start at: " .. uses);
    local period, _ = string.find(message, ".", uses, true);
    if period == nil then return nil; end
    local comma, _ = string.find(message, ",", uses, true);
    if comma ~= nil and comma < period then
        period = comma;  -- pretend the sentence ends at the comma
    end
    -- print("abi name end at: " .. period);
    return string.sub(message, uses, period-1);
end


-- table to string for debugging
local function myDump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. myDump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end


 local function dataToPacketTable(data, size)
    --local testPacket = {26, 14, 200};
    --print("testPacket: " .. myDump(testPacket));

    local packet = {};
    for i = 1, size do
        --print("putting in packet: " .. struct.unpack('B', data, i));
        packet[i] = struct.unpack('B', data, i);
        --print(myDump(packet));
    end
    return packet;
end
---------------------
-- PACKETHELP.LUA ---
---------------------
function get_bit_packed(dat_string,start,stop)
    local newval = 0
    local c_count = math.ceil(stop/8)
    while c_count >= math.ceil((start+1)/8) do
        -- Grabs the most significant byte first and works down towards the least significant.
        local cur_val = dat_string:byte(c_count)
        local scal = 256
        if c_count == math.ceil(stop/8) then -- Take the least significant bits of the most significant byte
            -- Moduluses by 2^number of bits into the current byte. So 8 bits in would %256, 1 bit in would %2, etc.
            -- Cuts off the top.
            cur_val = cur_val%(2^((stop-1)%8+1)) -- -1 and +1 set the modulus result range from 1 to 8 instead of 0 to 7.
        end
        if c_count == math.ceil((start+1)/8) then -- Take the most significant bits of the least significant byte
            -- Divides by the significance of the final bit in the current byte. So 8 bits in would /128, 1 bit in would /1, etc.
            -- Cuts off the bottom.
            cur_val = math.floor(cur_val/(2^(start%8)))
            scal = 2^(8-start%8)
        end
        newval = newval*scal + cur_val -- Need to multiply by 2^number of bits in the next byte
        c_count = c_count - 1
    end
    return newval
end
function assemble_bit_packed(init,val,initial_length,final_length,debug_val)
    if type(val) == 'boolean' then
        if val then val = 1 else val = 0 end
    end
    local bits = initial_length%8
    local byte_length = math.ceil(final_length/8)
    local out_val = 0
    if bits > 0 then
        out_val = init:byte(#init) -- Initialize out_val to the remainder in the active byte.
        init = init:sub(1,#init-1) -- Take off the active byte
    end
    out_val = out_val + val*2^bits -- left-shift val by the appropriate amount and add it to the remainder (now the lsb-s in val)
    if debug_val then print(out_val..' '..#init) end
    while out_val > 0 do
        init = init..string.char(out_val%256)
        out_val = math.floor(out_val/256)
    end
    while #init < byte_length do
        init = init..string.char(0)
    end
    return init
end
function unpackaction(packet)
    local data = packet:sub(5)
    local act = {}
    act.do_not_need = get_bit_packed(data,0,8)
    act.actor_id = get_bit_packed(data,8,40)
    act.target_count = get_bit_packed(data,40,50)
    act.category = get_bit_packed(data,50,54)
    act.param = get_bit_packed(data,54,70)
    act.unknown = get_bit_packed(data,70,86)
    act.recast = get_bit_packed(data,86,118)
    act.targets = {}    
    local offset = 118
    for i = 1,act.target_count do
        act.targets[i] = {}
        act.targets[i].id = get_bit_packed(data,offset,offset+32)
        act.targets[i].action_count = get_bit_packed(data,offset+32,offset+36)
        offset = offset + 36
        act.targets[i].actions = {}
        for n = 1,act.targets[i].action_count do
            act.targets[i].actions[n] = {}
            act.targets[i].actions[n].reaction = get_bit_packed(data,offset,offset+5)
            act.targets[i].actions[n].animation = get_bit_packed(data,offset+5,offset+16)
            act.targets[i].actions[n].effect = get_bit_packed(data,offset+16,offset+21)
            act.targets[i].actions[n].stagger = get_bit_packed(data,offset+21,offset+27)
            act.targets[i].actions[n].param = get_bit_packed(data,offset+27,offset+44)
            act.targets[i].actions[n].message = get_bit_packed(data,offset+44,offset+54)
            act.targets[i].actions[n].unknown = get_bit_packed(data,offset+54,offset+85)
            act.targets[i].actions[n].has_add_effect = get_bit_packed(data,offset+85,offset+86)
            offset = offset + 86
            if act.targets[i].actions[n].has_add_effect == 1 then
                act.targets[i].actions[n].has_add_effect = true
                act.targets[i].actions[n].add_effect_animation = get_bit_packed(data,offset,offset+6)
                act.targets[i].actions[n].add_effect_effect = get_bit_packed(data,offset+6,offset+10)
                act.targets[i].actions[n].add_effect_param = get_bit_packed(data,offset+10,offset+27)
                act.targets[i].actions[n].add_effect_message = get_bit_packed(data,offset+27,offset+37)
                offset = offset + 37
                else
                act.targets[i].actions[n].has_add_effect = false
                act.targets[i].actions[n].add_effect_animation = 0
                act.targets[i].actions[n].add_effect_effect = 0
                act.targets[i].actions[n].add_effect_param = 0
                act.targets[i].actions[n].add_effect_message = 0
            end
            act.targets[i].actions[n].has_spike_effect = get_bit_packed(data,offset,offset+1)
            offset = offset +1
            if act.targets[i].actions[n].has_spike_effect == 1 then
                act.targets[i].actions[n].has_spike_effect = true
                act.targets[i].actions[n].spike_effect_animation = get_bit_packed(data,offset,offset+6)
                act.targets[i].actions[n].spike_effect_effect = get_bit_packed(data,offset+6,offset+10)
                act.targets[i].actions[n].spike_effect_param = get_bit_packed(data,offset+10,offset+24)
                act.targets[i].actions[n].spike_effect_message = get_bit_packed(data,offset+24,offset+34)
                offset = offset + 34
                else
                act.targets[i].actions[n].has_spike_effect = false
                act.targets[i].actions[n].spike_effect_animation = 0
                act.targets[i].actions[n].spike_effect_effect = 0
                act.targets[i].actions[n].spike_effect_param = 0
                act.targets[i].actions[n].spike_effect_message = 0
            end
        end
    end    
    return act
end
function packaction(act)
        local react = assemble_bit_packed('',act.do_not_need,0,8)
        react = assemble_bit_packed(react,act.actor_id,8,40)
        react = assemble_bit_packed(react,act.target_count,40,50)
        react = assemble_bit_packed(react,act.category,50,54)
        react = assemble_bit_packed(react,act.param,54,70)
        react = assemble_bit_packed(react,act.unknown,70,86)
        react = assemble_bit_packed(react,act.recast,86,118)
        local offset = 118
        for i = 1,act.target_count do
            react = assemble_bit_packed(react,act.targets[i].id,offset,offset+32)
            react = assemble_bit_packed(react,act.targets[i].action_count,offset+32,offset+36)
            offset = offset + 36
            for n = 1,act.targets[i].action_count do
                react = assemble_bit_packed(react,act.targets[i].actions[n].reaction,offset,offset+5)
                react = assemble_bit_packed(react,act.targets[i].actions[n].animation,offset+5,offset+16)
                react = assemble_bit_packed(react,act.targets[i].actions[n].effect,offset+16,offset+21)
                react = assemble_bit_packed(react,act.targets[i].actions[n].stagger,offset+21,offset+27)
                react = assemble_bit_packed(react,act.targets[i].actions[n].param,offset+27,offset+44)
                react = assemble_bit_packed(react,act.targets[i].actions[n].message,offset+44,offset+54)
                react = assemble_bit_packed(react,act.targets[i].actions[n].unknown,offset+54,offset+85)
                react = assemble_bit_packed(react,act.targets[i].actions[n].has_add_effect,offset+85,offset+86)
                offset = offset + 86
                if act.targets[i].actions[n].has_add_effect then
                    react = assemble_bit_packed(react,act.targets[i].actions[n].add_effect_animation,offset,offset+6)
                    react = assemble_bit_packed(react,act.targets[i].actions[n].add_effect_effect,offset+6,offset+10)
                    react = assemble_bit_packed(react,act.targets[i].actions[n].add_effect_param,offset+10,offset+27)
                    react = assemble_bit_packed(react,act.targets[i].actions[n].add_effect_message,offset+27,offset+37)
                    offset = offset + 37
                end
                react = assemble_bit_packed(react,act.targets[i].actions[n].has_spike_effect,offset,offset+1)
                offset = offset + 1
                if act.targets[i].actions[n].has_spike_effect then
                    react = assemble_bit_packed(react,act.targets[i].actions[n].spike_effect_animation,offset,offset+6)
                    react = assemble_bit_packed(react,act.targets[i].actions[n].spike_effect_effect,offset+6,offset+10)
                    react = assemble_bit_packed(react,act.targets[i].actions[n].spike_effect_param,offset+10,offset+24)
                    react = assemble_bit_packed(react,act.targets[i].actions[n].spike_effect_message,offset+24,offset+34)
                    offset = offset + 34
                end
            end
        end
    return react
end
