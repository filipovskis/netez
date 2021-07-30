# NetEz
NetEz is the net wrapper for Garry's Mod, which simplify networking proccess

Requires [pON](https://github.com/SuperiorServers/dash/blob/master/lua/dash/thirdparty/pon/pon.lua) to work

# Examples
### Sending notification to a player from serverside
```lua
if CLIENT then
  netez.Register("Notification")
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
    netez.Send(self, "Notification", text, type, length)
  end
  
  hook.Add("PlayerSpawn", "Notification", function(ply)
    ply:Notify("You have been spawned!", nil, 3)
  end)
end
```
