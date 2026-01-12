--!nocheck

--// DEPENDENCIES \\--
local net = require('@lune/net')
local serde = require('@lune/serde')

--// MODULE \\--
local Robloxu = {}

--// STATIC VARIABLES \\--
local ROBLOX_API_BASE = "https://apis.roblox.com"
local ROBLOX_THUMBNAIL_BASE = "https://thumbnails.roblox.com"

--// MAIN FUNCTIONS \\--
function Robloxu._NetRequest(request_url: string, method: string, body: any, headers: {[string]: string}?): any?
    local packet = {
        url = request_url,
        method = string.upper(method),
        headers = {
            ["Content-Type"] = 'application/json',
        }
    }

    if headers ~= nil then
        for k, v in headers do
            packet.headers[k] = v
        end
    end

    if body ~= nil then
        local encoded_body

        if type(body) == 'table' then
            encoded_body = serde.encode('json', body)
            packet.headers["Content-Type"] = 'application/json'
        else
            encoded_body = body
        end
        
        packet.body = encoded_body
    end

    local response = net.request(packet)
    return serde.decode('json', response.body)
end

function Robloxu._RequestThumbnailAPI(endpoint: string, method: string, body: any, headers: {[string]: string}?): any?
    local url_request = ROBLOX_THUMBNAIL_BASE..endpoint
    return Robloxu._NetRequest(url_request, method, body, headers)
end

function Robloxu._RequestRobloxAPI(endpoint: string, method: string, body: any, headers: {[string]: string}?): any?
    local url_request = ROBLOX_API_BASE..endpoint
    return Robloxu._NetRequest(url_request, method, body, headers)
end

---// WRAPPERS \\
function Robloxu.GetUniverseId(placeId: string): string?
    local response_body: {[string]: string}? = Robloxu._RequestRobloxAPI("/universes/v1/places/"..placeId.."/universe", "GET")
    if response_body ~= nil then
        return response_body.universeId
    end

    return nil
end

function Robloxu.GetGameIconImageLink(universeId: string): string?
    local response_body: {[string]: string}? = Robloxu._RequestThumbnailAPI(`/v1/games/icons?universeIds={universeId}&size=150x150&format=Png&isCircular=false`, "GET")
    if response_body ~= nil then
        return response_body.data[1].imageUrl
    end

    return nil
end

return Robloxu