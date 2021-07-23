# NetEz
NetEz is the net wrapper for Garry's Mod, which simplify networking proccess

# Examples
### Sending notification to a player from serverside
```lua
if CLIENT then
  netez.register("Notification")
  :AddField("string")
  :AddOptionalField("uint")
  :AddField("uint")
  :SetCallback(function(text, type, length)
    type = type or 0
    
    notification.AddLegacy(text, type, length)
  end)
end

if SERVER then
  local PLAYER = FindMetaTable("Player")
  
  function PLAYER:Notify(text, type, length)
    netez.send(self, "Notification", text, type, length)
  end
  
  hook.Add("PlayerSpawn", "Notification", function(ply)
    ply:Notify("You have been spawned!", nil, 3)
  end)
end
```
### The most basic direct message system with delay, so a "bad person" cannot spam
```lua
if SERVER then
    local function findPlayerByName(name)
        for _, ply in ipairs(player.GetAll()) do
            if ply:Name() == name then
                return ply
            end
        end
    end

    netez.register("DirectMessage")
    :AddField("string")
    :AddField("string")
    :SetDelay(3)
    :SetCallback(function(ply, name, text)
        local target = findPlayerByName(name)
        if target then
            target:ChatPrint(ply:Name() .. " sent you a message: " .. text)
            ply:ChatPrint("Message was delivered!")
        end
    end)
end

if CLIENT then
    concommand.Add("dm", function(ply, cmd, args)
        netez.send("DirectMessage", args[1], args[2])
    end)
end
```
