--- Love2D UDP Game Server
-- @see README

local udpPort = 12345
local contentWidth = 960
local contentHeight = 480

local json = require "json"
local socket = require "socket"
local udp = socket.udp()
udp:settimeout(0)
udp:setsockname("*", udpPort )
local world = {}
local data, msg_or_ip, port_or_nil
local entity, cmd, parms

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end


function log( state, entity, ipaddr, port, worldsize )
    if not logHead then
        logHead = "date,time,state,entity,ipaddr,port,worldsize"
        print( logHead )
    end
    local ts = os.date( "%x,%X")
    print( string.format( "%s,%s,%d,%s,%d,%d", ts, state, entity, ipaddr, port, worldsize ) )
end

log( "started", 0, "0.0.0.0", udpPort, 0 )

-- Server wakes up every 0.1 sec, updates game state based on incoming data, sends update to clients
while true do
    repeat
        data, msg_or_ip, port_or_nil = udp:receivefrom()
        if data then
            entity, cmd, parms = data:match("^(%S*) (%S*) (.*)")
--            print( "received command: " .. cmd )
            if cmd == "move" then
                local x, y = parms:match("^(%-?[%d.e]*) (%-?[%d.e]*)$")
                if x and y then
                    local ent = world[entity] 
                    if ( ent == nil ) then
                        local port = port_or_nil or 0
                        log( "connected", entity, msg_or_ip, port, tablelength(world) + 1 )
                        ent = {x = 0, y = 0}
                    end
                    x, y = ent.x + tonumber(x), ent.y + tonumber(y)
                    if x >= 0 and x <= contentWidth and y >= 0 and y <= contentHeight then
                        local collision = false
                        for k, v in pairs(world) do
                            if k ~= entity then
                                local p1x, p1y = math.max(x, v.x), math.max(y, v.y)
                                local p2x, p2y = math.min(x + 32, v.x + 32), math.min(y + 32, v.y + 32)
                                if p2x - p1x >= 0 and p2y - p1y >= 0 then
                                    collision = true
                                    break
                                end
                            end
                        end
                        if not collision then
                            world[entity] = {x = x, y = y, ip = msg_or_ip, port = port_or_nil}
                        end
                    end
                end
            elseif cmd == "quit" then
                world[entity] = nil
                local port = port_or_nil or 0
                log( "disconnected", entity, msg_or_ip, port, tablelength(world) )
            else 
                -- cmd is unrecognized, refuse and do nothing
                local port = port_or_nil or 0
                log( "commandrefused", entity, msg_or_ip, port, tablelength(world) )
            end
        elseif msg_or_ip ~= "timeout" then 
            local port = port_or_nil or 0
            log( "networkerror", "", msg_or_ip, port, tablelength(world) )
        end
    until not data
    
    -- Global push of world state, limited by fog of war
    for k, v in pairs(world) do
        local payload = {}
        for k1, v1 in pairs(world) do
            -- If in vision range, add to world state update
            if math.sqrt((v.x + 16 - v1.x)^2 + (v.y + 16 - v1.y)^2) < (32 * 4) then
                payload[k1] = {x = v1.x, y = v1.y}
            end
        end
        udp:sendto(json.encode(payload), v.ip, v.port)
    end
    socket.sleep(0.1)
end
