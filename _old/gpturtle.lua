local RESPONSE_LENGTH = 10
local ACTIONS_MAX = 10

-- ACTION / COMMAND pairs
local valid_actions = {
    ["MOVE_FORWARD"] = function() print("    >> MOVE_FORWARD") end,
    ["MOVE_UP"] = function() print("    >> MOVE_UP") end,
    ["MOVE_DOWN"] = function() print("    >> MOVE_DOWN") end,
    ["TURN_LEFT"] = function() print("    >> TURN_LEFT") end,
    ["TURN_RIGHT"] = function() print("    >> TURN_RIGHT") end,
    ["DIG"] = function() printError("    >> DIG") end,
    ["ATTACK"] = function() printError("    >> ATTACK") end,
    ["POOP_PANTS"] = function() print("    >> POOP_PANTS") end
}

-- helper for comma separated list of actions used in prompt
local valid_actions_list = table.concat((function()
    local keys = {}
    for key in pairs(valid_actions) do
        keys[#keys + 1] = key
    end
    return keys
end)(), ", ")

-- API
local API_KEY = "AIzaSyB7cDpZgSY_rOSEr16sJWT14DeF2UcJ2us"
local URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=" .. API_KEY

-- PROMPT
local PREFIX = [[
You are controlling a robot inside Minecraft.
At each request, the input is a string formatted as:

WORLD: front, right, back, left, top, bottom

A list of 6 elements representing what's around the robot.
At each new request, this list is updated.

TASK: do something, robot!
A natural language sentence that describes the robot's goal.

Your job is to give a reply formatted as:
SAY: a comment to the task given. Stay in character and don't go over ]] .. RESPONSE_LENGTH .. [[ words.
ACTIONS: a series of actions separated by commas (e.g., MOVE_FORWARD, DIG, TURN_LEFT) to complete the TASK given the information you have in WORLD.

The available actions are: ]] .. valid_actions_list .. [[

IMPORTANT RULES:
Ensure the actions logically address the TASK.
Your response must depend on WORLD.
Do not format your response as code or use backticks or newlines. Respond in plain text ONLY.
Do not include explanations or anything else other than the response.

EXAMPLE:

your request is:

WORLD: iron_ore, diamond_block, air, lava, air, air
TASK: dig some diamond please!

For your response you should consider WORLD and you should choose a sequence of actions that completes TASK.
So this means your reply should be something like:

SAY: Ok bossman! I found some diamond, here I come
ACTIONS: TURN_RIGHT, DIG

And absolutely NOTHING ELSE.

Begin:
]]

-- Parse and validate actions
local function parse_and_validate_actions(actions_string)
    local actions = {}
    for action in actions_string:gmatch("([^,%s]+)") do
        if valid_actions[action] then
            actions[#actions + 1] = action
        else
            return nil, "Invalid action: " .. action
        end
    end
    return actions
end

-- Execute actions
local function execute_actions(actions)
    for _, action in ipairs(actions) do
        valid_actions[action]() -- Run the associated function
    end
end

local conversation_history = PREFIX

-- Add message to conversation history
local function add_to_history(role, message)
    conversation_history = conversation_history .. "\n" .. role .. ": " .. message
end

-- Create request body
local function create_request_body()
    return textutils.serializeJSON({contents = {{parts = {{text = conversation_history}}}}})
end

-- Process AI response
local function process_response(response)
    if response then
        local response_data = textutils.unserializeJSON(response.readAll())
        return response_data and response_data.candidates and response_data.candidates[1] and response_data.candidates[1].content.parts[1].text
    end
    return nil
end

-- Validate and retry AI response
local function validate_and_retry(input)
    local request_body = create_request_body()
    for _ = 1, 3 do -- Retry up to 3 times
        local response = http.post(URL, request_body, {["Content-Type"] = "application/json"})
        local assistant_reply = process_response(response)
        if assistant_reply then
            assistant_reply = assistant_reply:match("^%s*(.-)%s*$") -- Trim whitespace
            local say_match, actions_match = assistant_reply:match("SAY:%s*(.-)%s*ACTIONS:%s*(.+)")
            if say_match and actions_match then
                local actions, error_msg = parse_and_validate_actions(actions_match)
                if actions and #actions <= ACTIONS_MAX then
                    return say_match, actions
                end
                printError(error_msg or "GOD is yapping too much")
            else
                printError("GOD is speaking in tongues")
            end
        end
    end
    return nil, {}
end

term.clear()

while true do
    write("YOU > ")
    local user_input = read()

    if user_input:lower() == "exit" then
        print("Godbye!")
        break
    end

    add_to_history("User", user_input)
    local say_response, actions = validate_and_retry(user_input)

    if say_response then
        print("GOD > " .. say_response)
        execute_actions(actions)
        add_to_history("Assistant", "SAY: " .. say_response .. " ACTIONS: " .. table.concat(actions, ", "))
    else
        printError("GOD does not understand your prayers")
    end
end
