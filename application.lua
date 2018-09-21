local base64 = require "base64"
local config = require "config"

-- BEACON PACKET STRUCTURE
--
-- struct packet {
--      struct signed {
--          version  u8
--          name     char[16]
--          ctr      u64
--          errors   u8
--          temp     i32
--          pres     i32
--          humi     i32
--      }
--      mac      u8[32]
-- }
--
-- version: The protocol version. MUST be 0x01.
--
-- name     The identifier of the sending node, this SHOULD be a ascii encoded
--          string with the name/description of the node. This string must be
--          padded with zero bytes.
--          examples: "bedroom\0\0\0\0\0\0\0\0\0"/"feynman\0\0\0\0\0\0\0\0\0"
--
-- ctr:     A 64-bit sequence number. The receiver MUST keep a counter which
--          contains the last counter value it has seen from this identifier.
--          If an HMAC-authenticated packet contains a counter with a value
--          less than the saved counter, the reciever MUST silently drop the
--          beacon packet.
--
-- errors:  Bitfield containing errors that are relevant to the receiver.
--          Bit 0:  Bad temperature, should be read as <nil>
--          Bit 1:  Bad pressure, should be read as <nil>
--          Bit 2:  Bad humidity, should be read as <nil>
--
-- temp:    Floating point temperature value in Celsius multiplied by 100.
--
-- pres:    Pressure value in Pascal multiplied by 1000.
--
-- humi:    Humidity value in percent multiplied by 1000.
--
-- mac:     A 32-bit HMAC signature over the `signed` struct using the
--          node's pre-shared key. The receiver MUST NOT read any values of
--          the packet before verifying this value, with the exception of the
--          `id` value, which can be used to identify the key that has been
--          used.

-- UDP socket for broadcast messages
local appUDPSocket

-- Pad a string with zero bytes
local pad = function(s, n)
    assert(type(s) == "string", "s must be a string")
    assert(type(n) == "number", "n must be a number")
    local slen = string.len(s)
    if slen >= n then
        return string.sub(s, 1, n)
    else
        local c = "\0"
        return s .. string.rep("\0", n - slen)
    end
end

-- Return the current nonce/ctr value, add one to it and save it
local bump_nonce = function()
    local filename = "data/nonce.bin"
    local binfmt = "<!1I8"

    -- Open nonce file out of flash memory
    local fd = file.open(filename, "r")
    local nonce
    if fd then
        local nonce_bytes = fd:read(8)
        if nonce_bytes == nil then
            nonce = 0
        else
            nonce = struct.unpack(binfmt, nonce_bytes)
        end
        fd:close()
    else
        nonce = 0
    end

    -- Bump the nonce
    local new_nonce = nonce + 1
    local fd = file.open(filename, "w")
    fd.write(struct.pack(binfmt, new_nonce))
    fd.close()

    return nonce
end

-- Pack a beacon packet for the listeners on this network
local make_packet = function(T, P, H)
    local errors = 0
    if T == nil then
        errors = bit.set(errors, 1)
        T = 0
    end
    if P == nil then
        errors = bit.set(errors, 2)
        P = 0
    end
    if H == nil then
        errors = bit.set(errors, 3)
        H = 0
    end

    local version = 0x01
    local name = pad(IDENTIFIER, 16)
    local ctr = bump_nonce()
    local signed = struct.pack(">!1Bc16I8Bi4i4i4", version, name, ctr, errors, T, P, H)
    local mac = crypto.hmac("sha256", signed, PRESHARED_KEY)
    return signed .. mac
end

-- Report the current temperature value over the network
local loop = function()
    bme280.startreadout(30, function()

        local T, P, H = bme280.read()
        print("[d] Reported by BME280:")
        print("[d]     temperature = " .. T)
        print("[d]     pressure = " .. P)
        print("[d]     humidity = " .. H)

        local broadcast = wifi.sta.getbroadcast()
        if broadcast == nil then
            if no_wifi_total_milliseconds >= 60000 then
                print("[!] ERROR: no broadcast IP address present for a minute, restarting")
                node.restart()
            end
            no_wifi_total_milliseconds = no_wifi_total_milliseconds + INTERVAL_TIME_MS
        else
            no_wifi_total_milliseconds = 0
        end
        local packet = make_packet(T, P, H)
        if DEBUG then
            print("[d] Sending packet to address " .. broadcast .. ": '" .. crypto.toHex(packet) .. "'")
        end
        appUDPSocket:send(PORT, broadcast, packet)

    end)
end

-- Run once at startup
local setup = function()
    no_wifi_total_milliseconds = 0

    -- Initialize the communcation with the BME280
    i2c.setup(0, 2, 1, i2c.SLOW)
    bme280.setup(3, 3, 3, 0x1, 7, 5)

    -- Create the UDP socket for the lifetime of the process
    appUDPSocket = net.createUDPSocket()
end

-- Main application entrypoint (after starting wifi)
local run = function()
    setup()
    tmr.create():alarm(INTERVAL_TIME_MS, tmr.ALARM_AUTO, loop)

    -- -- Give the device some time to finish sending the packet and then go to sleep
    -- tmr.create():alarm(5, tmr.ALARM_SINGLE, function()
    --     -- Go into deep sleep for a couple of seconds
    --     local sleep_seconds = INTERVAL_TIME_MS
    --     if sleep_seconds == nil then
    --         -- One minute seems like a fair default
    --         sleep_seconds = 60e6
    --     end
    --
    --     if DEBUG then
    --         print("[d] Going into deep sleep for " .. sleep_seconds/1e6 .. " seconds")
    --     end
    --
    --     node.dsleep(sleep_seconds)
    -- end)
end

return { run = run }
