bootstrap = "http://john-kevin.me:8090/"
create_url = bootstrap .. "api/create"
read_url = bootstrap .. "api/read"
write_url = bootstrap .. "api/write"
append_url = bootstrap .. "api/append"
peak_url = bootstrap .. "api/peak"
truncate_url = bootstrap .. "api/truncate"
user = 'a'

running = false

-- Stolen From https://gist.github.com/bortels/1436940
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function enc(data)
  return ((data:gsub('.', function(x)
    local r,b='',x:byte()
    for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
    return r;
  end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c=0
    for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
    return b:sub(c+1,c+1)
  end)..({ '', '==', '=' })[#data%3+1])
end

file_mode = 33206
headers = "Content-Type: application/json\r\n"

local wifi_cfg = {
  ssid = "fyphotspot",
  pwd = "LFYCMBYX",
  auto = true,
  got_ip_cb = wifi_connected
}

function create(name, cb)
  body = {
    name = name,
    user = user,
    mode = mode
  }

  print("Creating File", name, create_url, wifi.sta.getip())
  http.post(create_url, headers, stringify(body), function(code, body)
    print(body)
    cb()
  end)
end

function write(name, str, pos, cb)
  if type(pos) == "function" then
    return write(name, str, 0, pos)
  end
  pos = pos or 0
  body = {
    name = name,
    user = user,
    offset = pos,
    buffer = enc(str)
  }

  print_table(body)

  http.post(write_url, headers, stringify(body), function(code)
      print(code, cb)
      if cb ~= nil then
        cb()
      end
  end)
end

function append(name, str, cb)
  body = {
    name = name,
    user = user,
    buffer = enc(str)
  }

  http.post(append_url, headers, stringify(body), function(code)
    print(code)
    if cb ~= nil then
      cb()
    end
  end)
end

function truncate(name, size, cb)
  if type(size) == "function" then
    return truncate(name, 0, size)
  end

  size = size or 0
  body = {
    name = name,
    user = user,
    size = size
  }

  http.post(truncate_url, headers, stringify(body), function()
    if cb ~= nil then
      cb()
    end
  end)
end

function peak(name, count, cb)
  body = {
    name = name,
    user = user,
    length = count
  }

  http.post(peak_url, headers, stringify(body), function(code, data)
    print(code)
    cb(data)
  end)
end

function stringify(table)
  str = "{"
  i = 0

  print(table)

  for k, v in pairs(table) do
    t = type(v)

    if i > 0 then
      str = str .. ","
    end

    str = str .. "\"" .. k .. "\":"

    i = i + 1

    if t == "string" then
      str = str .. "\"" .. v .. "\""
    else
      str = str .. tostring(v)
    end
  end
  str = str  .. "}"
  return str
end

function print_table(table)
  print(stringify(table))
end

function wifi_connected()
  if running then
    return
  end

  running = true

  print("Wifi Connected")
  create("/Test.txt", function()
    truncate("/Test.txt", function()
      write("/Test.txt", 'Hello', function()
        write("/Test.txt", ' World', 5, function()
          peak('/Test.txt', 6, function(data)
            print('Pre Append', data)
            append('/Test.txt', ' Lorem Ipsum', function ()
--              append('/Test.txt', ' test', function ()
                peak('/Test.txt', 20, function(data)
                  print('Post Append', data)
                  running = false
                end)
--              end)
            end)
          end)
        end)
      end)
    end)
  end)
end

function wifi_disconnected()
  print("Wifi Disconnected")
end

function wifi_connect()
  wifi.setmode(wifi.STATION)
  print("Connecting")
  print(wifi.sta.clearconfig())
  print(wifi.sta.config(wifi_cfg))
  print("Set Config")
  print_table(wifi_cfg)
  wifi.sta.connect(function () 
    print("Connected")

    wifi_connected()
  end)
end

function wifi_disconnect()
  wifi.sta.disconnect(wifi_disconnected)
end
--sleep(1000)
wifi_connect()
