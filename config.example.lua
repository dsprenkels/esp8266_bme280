local base64 = require "base64"

-- Print debug messages on the serial console (this is safe in production)
DEBUG = true

-- Credentials for the wifi network
SSID = "MyHomeWiFi"
PASSWORD = "secretpassword01"

-- The delay between info beacons in milliseconds
INTERVAL_TIME_MS = 5000

-- The udp port number to broadcast to
PORT = 21772

-- The node identifier
IDENTIFIER = "bedroom"

-- The PSK for HMAC-SHA256 message authentication codes
--
-- Generate a base64 encoded preshared key using the following command:
-- $ head -c32 /dev/urandom | base64
PRESHARED_KEY = base64.decode("")
