-- [[ CONFIG ]]
local RESPONSE_LENGTH = 10
local ACTIONS_MAX = 10
local SLEEP = 5
local DEFAULT_TASK = "Poop everywhere! do some great pooping and let everyone know how great you are at pooping"
local API_KEY = "AIzaSyB7cDpZgSY_rOSEr16sJWT14DeF2UcJ2us"
local URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=" .. API_KEY


-- [[ HELPERS ]]
-- inspect world around robot
local function get_world_state()
    local world_state = {}
    local has_block, data = turtle.inspect()
    table.insert(world_state, has_block and data.name or "nothing")
    local has_block_up, data_up = turtle.inspectUp()
    table.insert(world_state, has_block_up and data_up.name or "nothing")
    local has_block_down, data_down = turtle.inspectDown()
    table.insert(world_state, has_block_down and data_down.name or "nothing")
    return "WORLD: " .. table.concat(world_state, ", ")
end

-- get inventory state
local function get_inventory_state()
    local inventory = {}
    for slot = 1, 16 do
        local item_detail = turtle.getItemDetail(slot, true)
        table.insert(inventory, item_detail and item_detail.displayName or "nothing")
    end
    return "INVENTORY: " .. table.concat(inventory, ", ")
end


-- play SAY message via TTS
local function play_tts(message)
    local url = "https://music.madefor.cc/tts?text=" .. textutils.urlEncode(message) .. "&voice=en-gb-scotland"
    local response, err = http.get { url = url, binary = true }
    if not response then
        printError("TTS Error: " .. (err or "Unknown error"))
        return
    end

    local speaker = peripheral.find("speaker")
    if not speaker then
        printError("No speaker peripheral found!")
        return
    end

    local decoder = require("cc.audio.dfpwm").make_decoder()
    while true do
        local chunk = response.read(16 * 1024)
        if not chunk then break end

        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
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

local function create_request_body(conversation_history)
    return textutils.serializeJSON({contents = {{parts = {{text = conversation_history}}}}})
end

-- turn response json into string
local function process_response(response)
    if response then
        local response_data = textutils.unserializeJSON(response.readAll())
        return response_data and response_data.candidates and response_data.candidates[1] and response_data.candidates[1].content.parts[1].text
    end
    return nil
end


-- [[ ROBOT LOGIC ]]
-- ACTION / COMMAND pairs
local VALID_ACTIONS = {
    ["IDLE"] = function() play_random_sound("data/sounds") end,
    ["MOVE_FORWARD"] = function() print("> MOVE_FORWARD"); turtle.forward() end,
    ["MOVE_BACK"] = function() print("> MOVE_BACK"); turtle.back() end,
    ["MOVE_UP"] = function() print("> MOVE_UP"); turtle.up() end,
    ["MOVE_DOWN"] = function() print("> MOVE_DOWN"); turtle.down() end,
    ["TURN_LEFT"] = function() print("> TURN_LEFT"); turtle.turnLeft() end,
    ["TURN_RIGHT"] = function() print("> TURN_RIGHT"); turtle.turnRight() end,
    ["DIG"] = function() print("> DIG"); turtle.dig() end,
    ["DIG_UP"] = function() print("> DIG_UP"); turtle.digUp() end,
    ["DIG_DOWN"] = function() print("> DIG_DOWN"); turtle.digDown() end,
    ["PLACE"] = function() print("> PLACE"); turtle.place() end,
    ["PLACE_UP"] = function() print("> PLACE_UP"); turtle.placeUp() end,
    ["PLACE_DOWN"] = function() print("> PLACE_DOWN"); turtle.placeDown() end,
    ["DROP"] = function() print("> DROP"); turtle.drop() end,
    ["PICK"] = function() print("> PICK"); turtle.suck() end,
    ["ATTACK"] = function() print("> ATTACK"); turtle.attack() end,
    ["POOP_PANTS"] = function() print("> POOP_PANTS"); play_tts("prrrrrrrrrrrrrrrrrrrrooottttt!!!") end,
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
            actions[#actions + 1] = action
        else
            return nil, "Invalid action: " .. action
        end
    end
    return actions
end

-- run commands associated with actions
local function execute_actions(actions)
    for _, action in ipairs(actions) do
        VALID_ACTIONS[action]() -- Run the associated function
    end
end

-- PROMPT
local PREFIX = [[
You are controlling a robot inside Minecraft.
At each request, the input is a string formatted as:

WORLD: front, up, down
INVENTORY: slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9, slot10, slot11, slot12, slot13, slot14, slot15, slot16
TASK: do something, robot!

here is an explanation:

WORLD: A list of 3 elements representing the blocks in front, above, and under the robot.
At each new request, this list is updated.
INVENTORY: The content of the 16 slots of the robot's inventory
TASK: A natural language sentence that describes the robot's goal.
It could happen that you have no TASK. If so, just decide one by yourself.

Your job is to give a reply formatted as:
SAY: a comment to the task given. Stay in character and don't go over ]] .. RESPONSE_LENGTH .. [[ words.
ACTIONS: a series of actions separated by commas (e.g., MOVE_FORWARD, DIG, TURN_LEFT) to complete the TASK given the information you have in WORLD.

The available actions are: ]] .. valid_actions_list .. [[

important rules:
Ensure the actions logically address the TASK.
Your response must depend on WORLD.
Do not format your response as code or use backticks or newlines. Respond in plain text ONLY.
Do not include explanations or anything else other than the response.

here is an example, your request is:

WORLD: minecraft:iron_ore, minecraft:diamond_block, nothing
INVENTORY: pickaxe, acacia_slab, cobblestone, poop, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, egg, nothing
TASK: give me some diamond please!

For your response you should consider WORLD and you should choose up to ]] .. ACTIONS_MAX .. [[ actions that complete TASK.
So this means your reply should be something like:

SAY: Ok bossman! there's some big ass diamond block here. Do you also want an egg? i have a few.
ACTIONS: DIG_UP, SLOT_NEXT, SLOT_NEXT, SLOT_NEXT, SLOT_NEXT, DROP

And absolutely NOTHING ELSE.

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
        local response = http.post(URL, request_body, {["Content-Type"] = "application/json"})
        local assistant_reply = process_response(response)

        if assistant_reply then
            local say_match, actions_match = assistant_reply:match("SAY:%s*(.-)%s*ACTIONS:%s*(.+)")
            if say_match and actions_match then
                local actions = parse_and_validate_actions(actions_match) or {"IDLE"}
                play_tts(say_match)
                print("> SAY: " .. say_match)
                execute_actions(actions)
                conversation_history = conversation_history .. "\nAssistant: SAY: " .. say_match .. " ACTIONS: " .. actions_match
            end
        else
            printError("Failed to get a response. Retrying...")
        end

        sleep(SLEEP)
    end
end

-- robot - user input
local function user_input()
    while true do
        local user_input = read()
        if user_input:lower() == "exit" then
            print("Goodbye!")
            os.exit()
        elseif user_input:match("%S") then -- non-empty input
            DEFAULT_TASK = user_input -- update DEFAULT_TASK
        end
    end
end

-- start async
parallel.waitForAny(robot_behavior, user_input)
