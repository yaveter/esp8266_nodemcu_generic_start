-- OPTIONAL SETTINGS
-- I2C IO indexes (not GPIO numbers! Look up into GPIO map!)
SDA = 4 -- sda pin, GPIO2
SCL = 5 -- scl pin, GPIO14

-- LED + Button multiplexer GPIO
LBGI=6  -- GPIO 12

function run_setup()
    wifi.setmode(wifi.SOFTAP)
    cfg={}
	-- Set your own AP prefix. SHM = Smart Home Module.
    cfg.ssid="SHM"..node.chipid()
    wifi.ap.config(cfg)

    print("Opening WiFi credentials portal")
    dofile ("dns-liar.lc")
    dofile ("server.lc")
end

function read_wifi_credentials()
    if file.open("netconfig.lc", "r") then
        dofile('netconfig.lc')
        file.close()
    end

	-- set DNS to second slot if configured.
	if wifi_dns ~= nil and wifi_dns ~= '' then net.dns.setdnsserver(wifi_dns, 1) end
	
    if wifi_ssid ~= nil and wifi_ssid ~= "" and wifi_password ~= nil then
        return wifi_ssid, wifi_password, wifi_ip, wifi_nm, wifi_gw, wifi_desc
    end
    return nil, nil, nil, nil, nil, nil
end

function try_connecting(wifi_ssid, wifi_password, wifi_ip, wifi_nm, wifi_gw)
    wifi.setmode(wifi.STATION)
    wifi.sta.config(wifi_ssid, wifi_password)
    wifi.sta.connect()
    wifi.sta.autoconnect(1)
    -- Set IP if no DHCP required
    if wifi_ip ~= "" then wifi.sta.setip({ip=wifi_ip, netmask=wifi_nm, gateway=wifi_gw}) end

    tmr.alarm(0, 2000, 1, function()
        if wifi.sta.status() ~= 5 then
          print("Connecting to AP...")
        else
          tmr.stop(1)
          tmr.stop(0)
          print("Connected as: " .. wifi.sta.getip())
          collectgarbage()
		  tmr.unregister(0)
          -- TODO: Add your functionality here to do AFTER connection established.
		  --
		  tmr.unregister(1)
        end
    end)

    tmr.alarm(1, 20000, 0, function()
        -- Sleep if sensor (save power until WiFi gets back), 
        -- else run configuration mode
        if wifi.sta.status() ~= 5 then
            tmr.stop(0)
            tmr.unregister(0)
            print("Failed to connect to \"" .. wifi_ssid .. "\".")
            if uclass == nil or uclass == "sensor" then 
                print("Sleep 5 min + retry...")
                print("Press the button 5 seconds on the next boot to enter WiFi configuration captive mode.")
                -- No sense to run setup if the settings present. Sleep and retry.
                node.dsleep(5 * 60 * 1000 * 1000, 0)   -- 5 min sleep            
            else
                run_setup()
            end
        end
    end)
end

-------------------------
------  MAIN  -----------
-------------------------
if file.open("ut.lc", "r") then dofile("ut.lc")
else print "Unit type is not set." end

dofile("button_setup.lc")  -- uses timer #5
wifi.sta.disconnect()
wifi_ssid, wifi_password, wifi_ip, wifi_nm, wifi_gw, wifi_desc = read_wifi_credentials()
-- TODO: Add your functionality here to do BEFORE connection established.
--
if wifi_ssid ~= nil and wifi_password ~= nil then
    print("Retrieved stored WiFi credentials")
    print("---------------------------------")
    print("wifi_ssid     : " .. wifi_ssid)
    print("wifi_password : " .. wifi_password)
    print("wifi_ip : " .. wifi_ip)
    print("wifi_nm : " .. wifi_nm)
    print("wifi_gw : " .. wifi_gw)
    print("wifi_dns : " .. (wifi_dns or ""))
    print("wifi_repo : " .. (wifi_repo or ""))
    print("wifi_desc : " .. (wifi_desc or ""))
    try_connecting(wifi_ssid, wifi_password, wifi_ip, wifi_nm, wifi_gw)
else
    run_setup()
end
