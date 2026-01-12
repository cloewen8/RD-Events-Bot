--!nocheck

--// DEPENDENCIES \\
local process = require('@lune/process')

local discordu = require('./Libraries/Discordu')
local robloxu = require('./Libraries/Robloxu')

local intents_module = discordu.intents
local embeds = discordu.embeds
local messages = discordu.messages

local types = discordu.types

--// BOT VARIABLES \\
local bot_intents = intents_module.default()
bot_intents.message_content = true

--// ENV \\
local load_env = require("./Libraries/LoadENV")
load_env(".env")

load_env = nil

local env = process.env

--// STATIC VARIABLES \\
local GUILD_IDS = {"1443673571401404540"}
local TOKEN = env.TOKEN

local SUBMISSION_EMBED_TEMPLATE: types.embed_args = {
    title = "Submission by {user}",
    description = "Community submission from {user_mention} on {timestamp}",

    image = {
        url = "",
    },
}

local UP_ARROW = {name="⬆️"}
local DOWN_ARROW = {name="⬇️"}

local GAME_LINK_BASE = "https://www.roblox.com/games/"
local DEFAULT_IMAGE = "https://i.ibb.co/1JsyypNV/image.png"

local SUBMISSIONS_CHANNEL = "1456727991118987325"
local TRANSCRIPTS_CHANNEL = "1460081557770338448"

local ROLES_WITH_REMOVE_PERMISSION = {"1460075118859522089"}

--// DYNAMIC VARIABLES \\--
local templates: {[string]: {embed: types.embed, message: string}} = {}

--// BOT
local bot = discordu.Bot(TOKEN, bot_intents)
bot_intents = nil -- memory saving :3

--// MAIN FUNCTIONS \\

--/// SUBMISSION FUNCTIONS
local function get_place_id_from_link(link: string): string?
    local split_table = string.split(link, GAME_LINK_BASE)
    if split_table ~= nil then
        split_table = string.split(split_table[2], "/")
        local id = split_table[1]

        return tonumber(id) ~= nil and id or nil
    end
    return
end

local function clone_submission_template(): typeof(SUBMISSION_EMBED_TEMPLATE)
    return {
        title = SUBMISSION_EMBED_TEMPLATE.title,
        description = SUBMISSION_EMBED_TEMPLATE.description,
        image = {
            url = SUBMISSION_EMBED_TEMPLATE.image.url,
        },
    }
end

local function is_valid_game_link(link: string): boolean
    local start_index = string.find(link, GAME_LINK_BASE)
    return start_index == 1
end

local function get_game_image_link_from_game_link(link: string): string
    local place_id = get_place_id_from_link(link)

    if place_id ~= nil then
        local universe_id = robloxu.GetUniverseId(place_id)

        if universe_id ~= nil then
            local image_link = robloxu.GetGameIconImageLink(universe_id)
            return image_link or DEFAULT_IMAGE
        end
    end

    return DEFAULT_IMAGE
end

local function get_discord_timestamp(given_time: string?): string
    given_time = given_time or tostring(os.time())
    return `<t:{given_time}:f>`
end

local function create_submission_embed(user: types.user, provided_link: string): types.Embed
    if is_valid_game_link(provided_link) ~= true then
        return nil
    end
    local image_link = get_game_image_link_from_game_link(provided_link)

    local new_submission = clone_submission_template()
    new_submission.title = string.gsub(new_submission.title, "{user}", user.username)

    local new_description = string.gsub(new_submission.description, "{user_mention}", `<@{user.id}>`)
    new_submission.description = `{string.gsub(new_description, "{timestamp}", get_discord_timestamp())}\n**Link:** {provided_link}`
    new_submission.image.url = image_link

    return embeds.Embed(new_submission)
end

local function submission_created(user: user, provided_link: string): types.Embed?
    if templates[user.id] ~= nil then
        return nil
    end

    return create_submission_embed(user, provided_link)
end

--// CONNECTIONS \\
bot:on_ready(function(ready_packet)
    print(`Logged in as {bot.user.username}!`)
end)

--// RUN
bot:Run()

--// CONSTRUCTORS \\
bot:slash_command({name = "submit", description = "Creates a community submission!", options = {
    {
        type = 3,

        name = "link",
        description = "The link you want to submit.",
    }
}}, function(interaction)
    interaction:send({content = "Processed."}, false, true)
end)

bot:delete_slash_command("submit")

bot:slash_command({name = "submit", description = "Creates a community submission!", options = {
    {
        type = 3,

        name = "link",
        description = "The link you want to submit.",

        required = true
    },
}}, function(interaction)
    local user = interaction.member.user

    local options = interaction.data.options
    local link

    for _, option in options do
        if option.name == "link" then
            link = option.value
        end
    end

    local embed = submission_created(user, link)
    if embed ~= nil then
        local message = bot:send_message(messages.append_button({embeds = {embed}}, {text = "Remove", style = "Primary", id = "remove_submission"..user.id, emoji = {name = "🗑️"}}), SUBMISSIONS_CHANNEL)
        interaction:send({content = "Sucessfully submitted."}, false, true)

        bot:add_reaction(message, UP_ARROW)
        bot:add_reaction(message, DOWN_ARROW)

        bot:listen_for_button("remove_submission"..user.id, function(button_interaction)  
            local moderator_roles = button_interaction.member.roles
            local can_remove = false

            for _, role in moderator_roles do
                if table.find(ROLES_WITH_REMOVE_PERMISSION, role) then
                    can_remove = true
                    break
                end
            end

            if can_remove == false then
                button_interaction:send({content = "You do not have the required role(s) to remove this post."}, false, true)
                return
            end

            button_interaction:send({content = "Approved!"}, false, true)
            
            local favor = "N/A"
            if message then
                local up_reactions = #bot:get_reactions(message, UP_ARROW)
                local down_reactions = #bot:get_reactions(message, DOWN_ARROW)

                favor = tostring(up_reactions/down_reactions)
            end

            local user_post = templates[user.id]
            messages.delete_message(bot, SUBMISSIONS_CHANNEL, user_post.message)

            local user_embed = user_post.embed
            bot:send_message({content=`**Favor:** {favor}`, embeds=user_embed ~= nil and {user_embed} or nil}, TRANSCRIPTS_CHANNEL)

            templates[user.id] = nil
            bot:DisconnectListener("remove_submission"..user.id)
        end)

        templates[user.id] = {embed=embed, message=message.id}
    else
        interaction:send({content = "Failed to send interaction. You may have one currently active, or you may have an invalid link."}, false, true)
    end
end, GUILD_IDS)