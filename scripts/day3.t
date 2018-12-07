-- day3.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local flat = require("material/flat.t")

local width, height = 1024, 1024
local map_tex = nil
local fabric = nil

local function claim_script(bounds)
  local x0, y0, w, h = unpack(bounds)
  x0 = x0 + 11
  y0 = y0 + 11
  local n = 0
  for y = y0, (y0 + h - 1) do
    for x = x0, (x0 + w - 1) do
      local pos = y*1024 + x
      fabric[pos] = fabric[pos] + 1
      if n % 8 == 0 then
        async.await_frames(1)
      end
      n = n + 1
    end
  end
end

local function fill(bounds, val)
  local x0, y0, w, h = unpack(bounds)
  x0 = x0 + 11
  y0 = y0 + 11
  local n = 0
  for y = y0, (y0 + h - 1) do
    for x = x0, (x0 + w - 1) do
      local pos = y*1024 + x
      fabric[pos] = val
      if n % 2 == 0 then async.await_frames(1) end
      n = n + 1
    end
  end
end

local function launch_script()
  local claims = require("day3_input.lua")
  local nstarted = 0
  local builders = {}
  for _, claim in ipairs(claims) do
    table.insert(builders, async.run(claim_script, claim))
    if nstarted % 2 == 0 then
      async.await_frames(1)
    end
    nstarted = nstarted + 1
  end
  async.await(async.all(builders))
  print("All done?")
  count_label.frozen = true
  local winner = {826,448,26,27}
  fill(winner, 250)
  -- for i = 1, 240 do
  --   local v = (math.sin(math.pi * 2.0 * i/60) + 1.0) / 2.0
  --   v = 200 + (v * 50)
  --   fill(winner, v)
  --   async.await_frames(1)
  -- end
end

function init()
  myapp = app.App{
    width = width, height = height, title = "day3", msaa = true,
    clear_color = 0xff0000ff, stats = false
  }

  myapp.camera:make_orthographic(-0.5, 0.5, -0.5, 0.5, 0.1, 30.0)
  myapp.camera.position:set(0.0, 0.0, 1.0)
  myapp.camera:update_matrix()

  local map_geo = require("geometry").plane_geo{
    width = 1.0, height = 1.0, segments = 1
  }
  map_tex = gfx.Texture2d{
    width = 1024, height = 1024, 
    dynamic = true, allocate = true,
    format = gfx.TEX_RGBA8
  }
  map_tex:commit()
  local map_mat = flat.FlatMaterial{texture = map_tex}
  local map = myapp.scene:create_child(graphics.Mesh, "fabric", map_geo, map_mat)

  fabric = terralib.new(uint8[1024*1024])
  async.run(launch_script)

  count_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "label", {
    x = 170, y = 54, color = {0.0, 1.0, 0.0, 1.0}, text = "blah", fontsize = 50,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })

  attrib_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "attrib", {
    x = 1020, y = 1020, color = {0.2, 0.2, 0.2, 1.0}, text = "AoC Day 3 [mtknn]", fontsize = 24,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })
end

local COLORS = {
  {0, 0, 0},
  {50, 50, 50},
  {50, 125, 50},
  {50, 150, 50},
  {50, 175, 50},
  {50, 200, 50},
  {50, 225, 50},
  {50, 255, 50}
}
MAX_COLOR = COLORS[#COLORS]
for i = 1, 56 do
  local xx = math.min(255, i * 5)
  COLORS[200 + i] = {255, 255, xx}
end

function update_map()
  local cdata = map_tex.cdata
  local overclaimed = 0
  for p = 0, (1024*1024) do
    local v = fabric[p]
    if v > 1 then overclaimed = overclaimed + 1 end
    local color = COLORS[v+1] or MAX_COLOR
    local i2 = p*4
    cdata[i2+0] = color[1]
    cdata[i2+1] = color[2]
    cdata[i2+2] = color[3]
    cdata[i2+3] = 255
  end
  map_tex:update()
  if not count_label.frozen then
    count_label:set_text(string.format("%06d", overclaimed))
  end
end

local writing_frames = true
local f = 0

function update()
  update_map()
  myapp:update()
  if writing_frames then
    local fn = string.format("frames/frame_%04d.png", f)
    gfx.save_screenshot(fn)
  end
  f = f + 1
end
