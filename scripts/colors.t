-- colors.t
--
-- named colors + manipulation functions

local math = require("math")
local m = {}

function m.to_float(c)
  local ret = {}
  for i, v in ipairs(c) do ret[i] = v / 255.0 end
  return ret
end

local function parse_color(hex_color)
  local ret = {}
  for i = 0, 2 do
    ret[3-i] = bit.band(bit.rshift(hex_color, i*8), 0xFF)
  end
  ret[4] = 255
  return ret
end
m.parse_hex_color = parse_color

m.rose = parse_color(0xFF1D76) --{0xFF, 0x1D, 0x76, 255}
m.graphite = parse_color(0x26170C) --{0x26, 0x17, 0x0C, 255}
m.barberry = parse_color(0xD4D10E)
m.purple = parse_color(0x7F17AD)
m.green = parse_color(0x1B9C02)
m.black_rock = parse_color(0x170937)
m.corn = parse_color(0xEDC40C)
m.plum = parse_color(0x8C256F)

m.brights = {m.rose, m.barberry, m.purple, m.green, m.corn, m.plum}
function m.random_color()
  return m.brights[math.random(1, #m.brights)]
end

return m