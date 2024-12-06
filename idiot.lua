-- [[ CONFIG ]]
local RESPONSE_LENGTH = 10
local ACTIONS_MAX = 30
local SLEEP = 5
local DEFAULT_TASK = "just chill"
local API_KEY = "AIzaSyB7cDpZgSY_rOSEr16sJWT14DeF2UcJ2us"
local URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=" .. API_KEY

-- variable and lock for task updates
local shared_task = DEFAULT_TASK
local task_lock = false

-- update the task
local function update_task(new_task)
    while task_lock do os.sleep(0.1) end
    task_lock = true
    shared_task = new_task
    task_lock = false
end

-- get the current task
local function get_task()
    while task_lock do os.sleep(0.1) end
    return shared_task
end

-- retrieve info about surroundings
local function get_world_state()
    local world_state = {
        (function() local ok, data = turtle.inspect(); return ok and data.name or "nothing" end)(),
        (function() local ok, data = turtle.inspectUp(); return ok and data.name or "nothing" end)(),
        (function() local ok, data = turtle.inspectDown(); return ok and data.name or "nothing" end)()
    }
    return "WORLD:" .. table.concat(world_state, ",")
end

-- retrieve info about inventory (+refuel)
local function get_inventory_state()
    local inventory = {}
    for slot = 1, 16 do
        turtle.select(slot)
        turtle.refuel()
        local item = turtle.getItemDetail(slot)
        if item then table.insert(inventory, item["name"])
        else table.insert(inventory, "nothing") end
    end
    return "INVENTORY:" .. table.concat(inventory, ",")
end

-- format outcomes
local function format_outcomes(outcomes)
    local outcome_strings = {}
    for action, outcome in pairs(outcomes) do
        table.insert(outcome_strings, string.format('%s:"%s"', action, tostring(outcome)))
    end
    return "OUTCOMES:" .. table.concat(outcome_strings, ",")
end

-- format request
local function format_request(world_state, inventory_state, outcomes, task)
    return table.concat({world_state, inventory_state, outcomes, "TASK:" .. task}, " ")
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

-- create request body (json)
local function create_request_body(history)
    return textutils.serializeJSON({ contents = {{ parts = {{ text = history }}}}})
end

-- process response into usable text
local function process_response(response)
    if response then
        local data = textutils.unserializeJSON(response.readAll())
        return data and data.candidates and data.candidates[1] and data.candidates[1].content.parts[1].text
    end
end

-- pLay random sound effect (IDLE)
local function play_random_sound(folder)
    local dfpwm = require("cc.audio.dfpwm")
    local decoder = dfpwm.make_decoder()
    local speaker = peripheral.find("speaker")
    local files = fs.list(folder)
    local dfpwmFiles = {}

    for _, file in ipairs(files) do
        if file:match("%.dfpwm$") then
            table.insert(dfpwmFiles, (folder) .. "/" .. file)
        end
    end

    local randomFile = dfpwmFiles[math.random(#dfpwmFiles)]
    local handle = fs.open(randomFile, "rb")

    while true do
        local chunk = handle.read(16 * 1024)
        if not chunk then break end

        local decoded = decoder(chunk)
        while not speaker.playAudio(decoded) do
            os.sleep(0.05)
        end
    end

    handle.close()
end

-- action / command pairs
-- ACTION / COMMAND pairs
local VALID_ACTIONS = {
    ["idle"] = function() play_random_sound("dumb_idiot/data/sounds") return "success" end,

    ["move_forward"] = function() if turtle.forward() then return "success" else return "fail" end end,
    ["move_back"] = function() if turtle.back() then return "success" else return "fail" end end,
    ["move_up"] = function() if turtle.up() then return "success" else return "fail" end end,
    ["move_down"] = function() if turtle.down() then return "success" else return "fail" end end,
    ["turn_left"] = function() if turtle.turnLeft() then return "success" else return "fail" end end,
    ["turn_right"] = function() if turtle.turnRight() then return "success" else return "fail" end end,

    ["dig"] = function() if turtle.dig() then return "success" else return "fail" end end,
    ["place"] = function() if turtle.place() then return "success" else return "fail" end end,
    ["drop"] = function() if turtle.drop() then return "success" else return "fail" end end,
    ["pick"] = function() if turtle.suck() then return "success" else return "fail" end end,
    ["attack"] = function() if turtle.attack() then return "success" else return "fail" end end,
    ["poop_pants"] = function() if play_tts("prrrrrrrrrrrrrrrrrrrrooottttt!!!") then return "success" else return "fail" end end,
    ["send_impulse"] = function() redstone.setOutput("front", true) return "success" end,

    ["select_slot1"] = function() if turtle.select(1) then return "success" else return "fail" end end,
    ["select_slot2"] = function() if turtle.select(2) then return "success" else return "fail" end end,
    ["select_slot3"] = function() if turtle.select(3) then return "success" else return "fail" end end,
    ["select_slot4"] = function() if turtle.select(4) then return "success" else return "fail" end end,
    ["select_slot5"] = function() if turtle.select(5) then return "success" else return "fail" end end,
    ["select_slot6"] = function() if turtle.select(6) then return "success" else return "fail" end end,
    ["select_slot7"] = function() if turtle.select(7) then return "success" else return "fail" end end,
    ["select_slot8"] = function() if turtle.select(8) then return "success" else return "fail" end end,
    ["select_slot9"] = function() if turtle.select(9) then return "success" else return "fail" end end,
    ["select_slot10"] = function() if turtle.select(10) then return "success" else return "fail" end end,
    ["select_slot11"] = function() if turtle.select(11) then return "success" else return "fail" end end,
    ["select_slot12"] = function() if turtle.select(12) then return "success" else return "fail" end end,
    ["select_slot13"] = function() if turtle.select(13) then return "success" else return "fail" end end,
    ["select_slot14"] = function() if turtle.select(14) then return "success" else return "fail" end end,
    ["select_slot15"] = function() if turtle.select(15) then return "success" else return "fail" end end,
    ["select_slot16"] = function() if turtle.select(16) then return "success" else return "fail" end end,
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

-- run commands associated with actions and capture outcomes
local function execute_actions(actions)
    local outcomes = {}
    for _, action in ipairs(actions) do
        if VALID_ACTIONS[action] then
            local result = VALID_ACTIONS[action]()
            outcomes[action] = result or "error"
        else
            outcomes[action] = "invalid"
        end
    end

    return format_outcomes(outcomes)
end

-- parse response into actions and validate against valid actions list
local function parse_and_validate_actions(actions_string)
    local actions = {}
    for action in actions_string:gmatch("([^,%s]+)") do
        if VALID_ACTIONS[action] then
            table.insert(actions, action)
        end
    end
    return #actions > 0 and actions or { "idle" }
end

local PROMPT = [[
You are controlling a robot inside Minecraft.
At each request, the input is a string formatted as:

WORLD: front, up, down
INVENTORY: slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9, slot10, slot11, slot12, slot13, slot14, slot15, slot16
OUTCOMES: action1:outcome1, action2:outcome2, action3:outcome3 ...
TASK: do something, robot!

Here is an explanation:

- TASK: You can keep the task as it is in the request.
- WORLD: A list of 3 elements representing the blocks in front, above, and under the robot. Updates every request.
- INVENTORY: A representation of the robot's 16 inventory slots, starting from 1.
- OUTCOMES: The outcomes of the previous actions, e.g., success or fail.

Format your response as:
SAY: A short comment on the task, staying in character and under ]] .. RESPONSE_LENGTH .. [[ words.
ACTIONS: Actions to accomplish the task.

WORLD: minecraft:iron_ore, minecraft:diamond_block, nothing
INVENTORY: minecraft:iron_pickaxe, minecraft:acacia_slab, cobblestone, poop, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, minecraft:egg, nothing
OUTCOMES: equip:"SUCCESS", dig:"SUCCESS"
TASK: give me some diamond please!

Example:
SAY: Let me get that shiny diamond for you!
ACTIONS: move_forward, select_slot1, equip, dig, pick, place

IMPORTANT RULES:
Ensure the actions logically address the TASK.
Your response must depend on the information you have. it shouldn't be random.
Do not format your response as code or use backticks or newlines. Respond in plain text.
Do not include explanations or anything else other than the response.
Try to use as many actions as possible, but no more than ]] .. ACTIONS_MAX ..[[
If OUTCOMES has some fails you get angry, ignore the task and do something crazy: try moving around and breaking stuff, shout and do anything in order to get better outcomes.

AVAILABLE ACTIONS:
]] .. valid_actions_list .. [[

Begin:
]]


term.clear()

-- robot behavior
local function robot_behavior()
    local conversation_history = PROMPT
    local last_outcomes = "OUTCOMES:none"

    while true do
        local world_state = get_world_state()
        local inventory_state = get_inventory_state()
        local task = get_task()
        local full_request = format_request(world_state, inventory_state, last_outcomes, task)

        local request_body = create_request_body(conversation_history .. "\nTASK: " .. full_request)
        local response = http.post(URL, request_body, { ["Content-Type"] = "application/json" })
        local reply = process_response(response)

        term.clearLine()
        print("\nTASK: " .. task .."\n" .. reply)

        if reply then
            local say, actions_text = reply:match("SAY:%s*(.-)%s*ACTIONS:%s*(.+)")
            if say and actions_text then
                play_tts(say)

                local actions = parse_and_validate_actions(actions_text)
                last_outcomes = execute_actions(actions)
                conversation_history = conversation_history .. "\nSAY: " .. say .. " ACTIONS: " .. table.concat(actions, ", ") .. " " .. last_outcomes
            end
        else
            printError("No response from AI. Retrying...")
        end

        sleep(SLEEP)
        if redstone.getOutput("front") ~= 0 then redstone.setOutput("front", false) end
    end
end

-- user input
local function user_input()
    while true do
        local input = read()
        if input and input:match("%S") then
            update_task(input)
        end
    end
end

-- Start robot behavior and user input in parallel
parallel.waitForAny(robot_behavior, user_input)
