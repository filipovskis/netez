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

        local valid = netez.CheckByType(type, value)

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

local function Pack(...)
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

local function Unpack(tbl)
    if not table.IsEmpty(tbl) then
        local value = table.remove(tbl, 1)

        if value == nilString then
            value = nil
        end

        return value, Unpack(tbl)
    end
end

---Creates a new type for fields
---@param type string
---@param checker function
function netez.CreateType(type, checker)
    netez.types[type] = checker
end

---Checks an any value by type
---@param type string
---@param any any
---@return boolean
function netez.CheckByType(type, any)
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
function netez.Register(id)
    local handler = setmetatable({}, HANDLER)

    handler.id = id
    handler.fields = {}
    handler.delays = {}

    netez.storage[id] = handler

    return handler
end

---Deletes the handler by id
---@param id string
function netez.Delete(id)
    netez.storage[id] = nil
end

function netez.GetHandler(id)
    return netez.storage[id]
end

do
    local Send

    local function Start(id, ...)
        assert(id)

        local Packed = Pack(...)
        local data = pon.encode(Packed)
        local length = #data

        net.Start(netString)

        net.WriteString(id)
        net.WriteUInt(length, 16)
        net.WriteData(data, length)
    end

    if SERVER then
        Send = function(ply)
            if ply then
                net.Send(ply)
            else
                net.Broadcast()
            end
        end

        function netez.Send(ply, id, ...)
            Start(id, ...)
            Send(ply)
        end
    else
        Send = net.SendToServer

        function netez.Send(id, ...)
            Start(id, ...)
            Send()
        end
    end
end

-- ANCHOR Networking

net.Receive("netez:Send", function(len, ply)
    local id = net.ReadString()
    local length = net.ReadUInt(16)
    local data = net.ReadData(length)

    local handler = netez.GetHandler(id)

    if handler then
        local allowed = handler:CheckPlayer(ply)

        if allowed then
            local decodedData = pon.decode(data)
            local isDataValid = handler:CheckArguments(decodedData)

            if isDataValid then
                if SERVER then
                    handler(ply, Unpack(decodedData))
                else
                    handler(Unpack(decodedData))
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

local function IsPlayer(any)
    return getmetatable(any) == PLAYER
end

local function IsVector(any)
    return getmetatable(any) == VECTOR
end

local function IsAngle(any)
    return getmetatable(any) == ANGLE
end

netez.CreateType("player", IsPlayer)
netez.CreateType("vector", IsVector)
netez.CreateType("angle", IsAngle)
netez.CreateType("string", isstring)
netez.CreateType("table", istable)
netez.CreateType("entity", isentity)
netez.CreateType("bool", isbool)
netez.CreateType("int", isnumber)
netez.CreateType("uint", function(any)
    return (isnumber(any) and any >= 0)
end)

netez.CreateType("any", function(any)
    return true
end)
