--[[

NetEz (Easy network library)

Author: tochonement
Email: tochonement@gmail.com

Credits:
- thelastpenguin for pON

23.07.2021

--]]

if not pon then
    error("NetEz requires pon to work!")
end

netez = netez or {}
netez.storage = netez.storage or {}
netez.types = netez.types or {}

local pon = pon
local netez = netez
local nilString = "NIL"
local netString = "netez:Send"

if SERVER then
    util.AddNetworkString(netString)
end

-- ANCHOR Handler meta table

local HANDLER = {}
HANDLER.__index = HANDLER

function HANDLER:__call(...)
    if self.callback then
        self.callback(...)
    end
end

function HANDLER:AddField(type)
    table.insert(self.fields, {
        type = type
    })

    return self
end

function HANDLER:AddOptionalField(type)
    table.insert(self.fields, {
        type = type,
        optional = true
    })

    return self
end

function HANDLER:SetDelay(delay)
    self.delay = delay

    return self
end

function HANDLER:SetCallback(func)
    self.callback = func

    return self
end

function HANDLER:GetFields()
    return self.fields
end

function HANDLER:CheckArguments(tbl)
    local fields = self:GetFields()

    for i, field in ipairs(fields) do
        local type = field.type
        local optional = field.optional
        local value = tbl[i]
        local isEmpty = value == nilString

        if not optional and isEmpty then
            print("No argument for required field #" .. i)
            return false
        end

        local valid = netez.checkByType(type, value)

        if valid ~= true and not optional and not isEmpty then
            print("Argument #" .. i .. " is invalid")
            return false
        end
    end

    return true
end

function HANDLER:CheckPlayer(ply)
    local endDelayTime = self.delays[ply]

    if endDelayTime and endDelayTime >= CurTime() then
        return false
    end

    return true
end

function HANDLER:OnSuccess(ply)
    local delay = self.delay

    if delay then
        self.delays[ply] = CurTime() + delay
    end
end

-- ANCHOR Functions

local function pack(...)
    local result = {}
    local count = select("#", ...)

    for i = 1, count do
        local value = select(i, ...)

        if value == nil then
            result[i] = nilString
        else
            result[i] = value
        end
    end

    return result
end

local function unpack(tbl)
    if not table.IsEmpty(tbl) then
        local value = table.remove(tbl, 1)

        if value == nilString then
            value = nil
        end

        return value, unpack(tbl)
    end
end

---Creates a new type for fields
---@param type string
---@param checker function
function netez.createType(type, checker)
    netez.types[type] = checker
end

---Checks an any value by type
---@param type string
---@param any any
---@return boolean
function netez.checkByType(type, any)
    local checker = netez.types[type]

    if checker then
        return checker(any)
    else
        return false
    end
end

---Registers a new handler for network message receiving
---@param id string
---@return userdata
function netez.register(id)
    local handler = setmetatable({}, HANDLER)

    handler.id = id
    handler.fields = {}
    handler.delays = {}

    netez.storage[id] = handler

    return handler
end

---Deletes the handler by id
---@param id string
function netez.delete(id)
    netez.storage[id] = nil
end

function netez.getHandler(id)
    return netez.storage[id]
end

do
    local send

    local function start(id, ...)
        assert(id)

        local packed = pack(...)
        local data = pon.encode(packed)
        local length = #data

        net.Start(netString)

        net.WriteString(id)
        net.WriteUInt(length, 16)
        net.WriteData(data, length)
    end

    if SERVER then
        send = function(ply)
            if ply then
                net.Send(ply)
            else
                net.Broadcast()
            end
        end

        function netez.send(ply, id, ...)
            start(id, ...)
            send(ply)
        end
    else
        send = net.SendToServer

        function netez.send(id, ...)
            start(id, ...)
            send()
        end
    end
end

-- ANCHOR Networking

net.Receive("netez:Send", function(len, ply)
    local id = net.ReadString()
    local length = net.ReadUInt(16)
    local data = net.ReadData(length)

    local handler = netez.getHandler(id)

    if handler then
        local allowed = handler:CheckPlayer(ply)

        if allowed then
            local decodedData = pon.decode(data)
            local isDataValid = handler:CheckArguments(decodedData)

            if isDataValid then
                if SERVER then
                    handler(ply, unpack(decodedData))
                else
                    handler(unpack(decodedData))
                end

                handler:OnSuccess(ply)
            end
        end
    end
end)

-- ANCHOR Types

local PLAYER = FindMetaTable("Player")
local VECTOR = FindMetaTable("Vector")
local ANGLE = FindMetaTable("Angle")

local function isPlayer(any)
    return getmetatable(any) == PLAYER
end

local function isVector(any)
    return getmetatable(any) == VECTOR
end

local function isAngle(any)
    return getmetatable(any) == ANGLE
end

netez.createType("player", isPlayer)
netez.createType("vector", isVector)
netez.createType("angle", isAngle)
netez.createType("string", isstring)
netez.createType("table", istable)
netez.createType("entity", isentity)
netez.createType("bool", isbool)
netez.createType("int", isnumber)
netez.createType("uint", function(any)
    return (isnumber(any) and any >= 0)
end)

netez.createType("any", function(any)
    return true
end)

-- ANCHOR Tests

-- Case #1 (Clientside -> Serverside)
--[[
    if SERVER then
        netez.register("UpdateHealth")
        :AddField("uint")
        :SetDelay(3)
        :SetCallback(function(ply, health)
            ply:SetHealth(health)
        end)
    end

    if CLIENT then
        concommand.Add("randomhp", function()
            netez.send("UpdateHealth", math.random(100))
        end)
    end
 ]]

-- Case #2 (Serverside -> Clientside, multiple fields)
--[[
if CLIENT then
    netez.register("Notification")
    :AddOptionalField("uint")
    :AddField("string")
    :AddField("uint")
    :SetCallback(function(type, text, length)
        type = type or 0

        notification.AddLegacy(text, type, length)
    end)
end

if SERVER then
    netez.send(nil, "Notification", nil, "Hello everyone", 5)
end
 ]]