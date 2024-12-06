-- [[ CONFIG ]]
local RESPONSE_LENGTH = 10
local ACTIONS_MAX = 10
local SLEEP = 1
local DEFAULT_TASK = "Go make some friends"
local API_KEY = "AIzaSyB7cDpZgSY_rOSEr16sJWT14DeF2UcJ2us"
local URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=" .. API_KEY


-- [[ HELPERS ]]
-- inspect world around robot
local function get_world_state()
    local world_state = {
        (function() local ok, data = turtle.inspect(); return ok and data.name or "nothing" end)(),
        (function() local ok, data = turtle.inspectUp(); return ok and data.name or "nothing" end)(),
        (function() local ok, data = turtle.inspectDown(); return ok and data.name or "nothing" end)()
    }
    return "WORLD: " .. table.concat(world_state, ", ")
end

-- get inventory state
local function get_inventory_state()
    local inventory = {}
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot, true)
        table.insert(inventory, item and item.displayName or "nothing")
    end
    return "INVENTORY: " .. table.concat(inventory, ", ")
end


-- play SAY message via TTS
local function play_tts(message)
    local url = "https://music.madefor.cc/tts?text=" .. textutils.urlEncode(message) .. "&voice=en-gb-scotland"
    local response, err = http.get { url = url, binary = true }
    if not response then return printError("TTS Error: " .. (err or "Unknown error")) end

    local speaker = peripheral.find("speaker")
    if not speaker then return printError("No speaker peripheral found!") end

    local decoder = require("cc.audio.dfpwm").make_decoder()
    while true do
        local chunk = response.read(16 * 1024)
        if not chunk then break end

        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer) do os.pullEvent("speaker_audio_empty") end
    end
end

-- play random sound effect (IDLE)
local function play_random_sound(folder)
    local dfpwm = require("cc.audio.dfpwm")
    local decoder = dfpwm.make_decoder()
    local speaker = peripheral.find("speaker")
    local files = fs.list(folder)
    local sounds = {}

    for _, file in ipairs(files) do
        if file:match("%.dfpwm$") then table.insert(sounds, folder .. "/" .. file) end
    end

    if #sounds == 0 then return end
    local sound_file = sounds[math.random(#sounds)]
    local handle = fs.open(sound_file, "rb")

    while true do
        local chunk = handle.read(16 * 1024)
        if not chunk then break end

        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer) do os.sleep(0.05) end
    end

    handle.close()
end

-- create request body
local function create_request_body(history)
    return textutils.serializeJSON({ contents = {{ parts = {{ text = history }}}}})
end

-- turn response json into string
local function process_response(response)
    if response then
        local data = textutils.unserializeJSON(response.readAll())
        return data and data.candidates and data.candidates[1] and data.candidates[1].content.parts[1].text
    end
end

-- [[ ROBOT LOGIC ]]

-- ACTION / COMMAND pairs
local VALID_ACTIONS = {
    ["idle"] = function() if play_random_sound("dumb_idiot/data/sounds") then return "success" else return "fail" end end,

    ["move_forward"] = function() print("> move_forward"); if turtle.forward() then return "success" else return "fail" end end,
    ["move_back"] = function() print("> move_back"); if turtle.back() then return "success" else return "fail" end end,
    ["move_up"] = function() print("> move_up"); if turtle.up() then return "success" else return "fail" end end,
    ["move_down"] = function() print("> move_down"); if turtle.down() then return "success" else return "fail" end end,
    ["turn_left"] = function() print("> turn_left"); if turtle.turnLeft() then return "success" else return "fail" end end,
    ["turn_right"] = function() print("> turn_right"); if turtle.turnRight() then return "success" else return "fail" end end,

    ["dig"] = function() print("> dig"); if turtle.dig() then return "success" else return "fail" end end,
    ["place"] = function() print("> place"); if turtle.place() then return "success" else return "fail" end end,
    ["drop"] = function() print("> drop"); if turtle.drop() then return "success" else return "fail" end end,
    ["pick"] = function() print("> pick"); if turtle.suck() then return "success" else return "fail" end end,
    ["attack"] = function() print("> attack"); if turtle.attack() then return "success" else return "fail" end end,
    ["poop_pants"] = function() if play_tts("prrrrrrrrrrrrrrrrrrrrooottttt!!!") then return "success" else return "fail" end end,

    ["select_slot1"] = function() print("select_slot1"); if turtle.select(1) then return "success" else return "fail" end end,
    ["select_slot2"] = function() print("select_slot2"); if turtle.select(2) then return "success" else return "fail" end end,
    ["select_slot3"] = function() print("select_slot3"); if turtle.select(3) then return "success" else return "fail" end end,
    ["select_slot4"] = function() print("select_slot4"); if turtle.select(4) then return "success" else return "fail" end end,
    ["select_slot5"] = function() print("select_slot5"); if turtle.select(5) then return "success" else return "fail" end end,
    ["select_slot6"] = function() print("select_slot6"); if turtle.select(6) then return "success" else return "fail" end end,
    ["select_slot7"] = function() print("select_slot7"); if turtle.select(7) then return "success" else return "fail" end end,
    ["select_slot8"] = function() print("select_slot8"); if turtle.select(8) then return "success" else return "fail" end end,
    ["select_slot9"] = function() print("select_slot9"); if turtle.select(9) then return "success" else return "fail" end end,
    ["select_slot10"] = function() print("select_slot10"); if turtle.select(10) then return "success" else return "fail" end end,
    ["select_slot11"] = function() print("select_slot11"); if turtle.select(11) then return "success" else return "fail" end end,
    ["select_slot12"] = function() print("select_slot12"); if turtle.select(12) then return "success" else return "fail" end end,
    ["select_slot13"] = function() print("select_slot13"); if turtle.select(13) then return "success" else return "fail" end end,
    ["select_slot14"] = function() print("select_slot14"); if turtle.select(14) then return "success" else return "fail" end end,
    ["select_slot15"] = function() print("select_slot15"); if turtle.select(15) then return "success" else return "fail" end end,
    ["select_slot16"] = function() print("select_slot16"); if turtle.select(16) then return "success" else return "fail" end end,
    ["equip"] = function() if turtle.equipLeft() then return "success" else return "fail" end end,
}

-- actions list to comma-separated (used in PROMPT)
local valid_actions_list = table.concat((function()
    local keys = {}
    for key in pairs(VALID_ACTIONS) do
        keys[#keys + 1] = key
    end
    return keys
end)(), ", ")

-- parse response into actions
local function parse_and_validate_actions(actions_string)
    local actions = {}
    for action in actions_string:gmatch("([^,%s]+)") do
        if VALID_ACTIONS[action] then
            table.insert(actions, action)
        else
            return nil, "Invalid action: " .. action
        end
    end
    return #actions > 0 and actions or { "idle" }
end

-- run commands associated with actions and capture outcomes
local function execute_actions(actions)
    local outcomes = {}
    for _, action in ipairs(actions) do
        if VALID_ACTIONS[action] then
            status, result = pcall(VALID_ACTIONS[action])
            outcomes[action] = result
        end
    end

    local outcome_strings = {}
    for action, outcome in pairs(outcomes) do
        table.insert(outcome_strings, string.format('%s:"%s"', action, tostring(outcome)))
    end
    return "OUTCOMES: " .. table.concat(outcome_strings, ", ")
end

-- PROMPT
local PREFIX = [[
You are controlling a robot inside Minecraft.
At each request, the input is a string formatted as:

WORLD: front, up, down
INVENTORY: slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9, slot10, slot11, slot12, slot13, slot14, slot15, slot16
OUTCOMES: action1:outcome1, action2:outcome2, action3:outcome3 ...
TASK: do something, robot!

here is an explanation:

WORLD: A list of 3 elements representing the blocks in front, above, and under the robot.
At each new request, this list is updated.
INVENTORY: The content of the 16 slots of the robot's inventory
OUTCOMES: the outcomes of your previous actions, so that you know if they failed.
TASK: A natural language sentence that describes the robot's goal.
It could happen that you have no TASK. If so, just decide one by yourself.

Your job is to give a reply formatted as:
SAY: a comment to the task given. Stay in character and don't go over ]] .. RESPONSE_LENGTH .. [[ words.
ACTIONS: a series of actions separated by commas (e.g., move_forward, dig, turn_left) to complete the TASK given the information you have in WORLD.

The available actions are: ]] .. valid_actions_list .. [[

important rules:
Ensure the actions logically address the TASK.
Your response must depend on WORLD.
Do not format your response as code or use backticks or newlines. Respond in plain text ONLY.
Do not include explanations or anything else other than the response.

here is an example, your request is:

WORLD: minecraft:iron_ore, minecraft:diamond_block, nothing
INVENTORY: minecraft:iron_pickaxe, minecraft:acacia_slab, cobblestone, poop, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, minecraft:egg, nothing
OUTCOMES: equip:"SUCCESS", dig:"SUCCESS"
TASK: give me some diamond please!

For your response you should consider WORLD and you should choose up to ]] .. ACTIONS_MAX .. [[ actions that complete TASK.
So this means your reply should be something like:

SAY: Ok bossman! there's some big ass diamond block here.
ACTIONS: move_forward, dig, suck, select_slot4, drop

And absolutely NOTHING ELSE.

changing task:
If the outcome you see is FAIL, for example:

OUTCOMES: equip:"success", dig:"fail"

or you dont like the assigned task you have to try a different approach.
To do this, you have to put a NEWTASK tag in the SAY field, followed by your new self-assigned task:

SAY: NEWTASK a new approach or a new task
the new task will be fed back to you so you will have a different starting point at the next request

Begin:
]]

-- robot - autonomous
local function robot_behavior()
    local conversation_history = PREFIX
    while true do
        local world_state = get_world_state()
        local inventory_state = get_inventory_state()
        local full_input = world_state .. "\n" .. inventory_state .. "\nTASK: " .. DEFAULT_TASK

        local request_body = create_request_body(conversation_history .. "\nUser: " .. full_input)
        local response = http.post(URL, request_body, { ["Content-Type"] = "application/json" })
        local reply = process_response(response)

        if reply then
            local say, actions_text = reply:match("SAY:%s*(.-)%s*ACTIONS:%s*(.+)")
            if say and actions_text then
                local new_task = say:match("NEWTASK%s*%-[%s]*(.+)")
                if new_task then
                    DEFAULT_TASK = new_task
                    print("> NEW TASK: " .. new_task)
                else
                    play_tts(say)
                    print("> SAY: " .. say)
                end

                local actions = parse_and_validate_actions(actions_text)
                local outcomes = execute_actions(actions)
                print(outcomes)
                conversation_history = conversation_history .. "\nAssistant: SAY: " .. say .. " ACTIONS: " .. table.concat(actions, ", ") .. " " .. outcomes
            end
        else
            printError("No response from AI. Retrying...")
        end

        sleep(SLEEP)
    end
end

-- robot - user input
local function user_input()
    while true do
        local input = read()
        if input and input:match("%S") then DEFAULT_TASK = input end
    end
end

-- start async
parallel.waitForAny(robot_behavior, user_input)


