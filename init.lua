-- Load credentials, 'SSID' and 'PASSWORD' declared and initialised in there
local app = require "application"
require "config"

-- Define WiFi station event callbacks
wifi_connect_event = function(T)
    if DEBUG then
        print("[d] Connection to AP ("..T.SSID..") established!")
        print("[d] Waiting for IP address...")
    end
end

wifi_got_ip_event = function(T)
    if DEBUG then
        print("[d] Wifi connection is ready! IP address is: "..T.IP)
        print("[d] Waiting one second before starting program")
        tmr.create():alarm(1000, tmr.ALARM_SINGLE, app.run)
        return
    end
    app.run()
end

-- We are rebooting constantly, so run the GC less often
node.egc.setmode(node.egc.ON_ALLOC_FAILURE)

-- Register WiFi Station event callbacks
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, wifi_connect_event)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifi_got_ip_event)

if DEBUG then
    print("[d] Connecting to WiFi access point...")
end
wifi.setmode(wifi.STATION)
wifi.sta.config({ssid=SSID, pwd=PASSWORD})

if ALWAYS_RESET_AFTER_SECONDS ~= nil then
    -- If the program takes too long to run, just restart
    tmr.create():alarm(1000*ALWAYS_RESET_AFTER_SECONDS, tmr.ALARM_SINGLE, function()
        print(ALWAYS_RESET_AFTER_SECONDS .. " timeout reached, forcing restart")
        node.restart()
    end)
end
