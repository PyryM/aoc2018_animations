-- day10.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local ecs = require("ecs")

local width, height = 512, 512
local grid, stars, tlabel = nil, nil, nil

local StarsComp = graphics.NanoVGComponent:extend("StarsComp")
function StarsComp:init(options)
  StarsComp.super.init(self)
  self.color = options.color or {1, 1, 1, 1}
  self.z_order = options.z_order or 0.0
  self.grid = options.grid
  self.t = 0
  self.stars = {}
end

function StarsComp:set_stars(stars)
  self.stars = stars
end

function StarsComp:set_time(t)
  self.t = t
end

function StarsComp:get_bounds(t)
  t = t or self.t
  local minx, miny = 100000, 100000
  local maxx, maxy = -100000, -100000
  for _, star in ipairs(self.stars) do
    local ux = star.x + star.vx * t
    local uy = star.y + star.vy * t
    if ux > maxx then maxx = ux end
    if uy > maxy then maxy = uy end
    if ux < minx then minx = ux end
    if uy < miny then miny = uy end
  end

  local cx = (minx + maxx) / 2
  local cy = (miny + maxy) / 2
  local ss = math.max(maxx - minx, maxy - miny) * 1.1
  ss = math.max(ss, 100)
  return {x0 = cx - ss/2, x1 = cx + ss/2, y0 = cy - ss/2, y1 = cy + ss/2}
end

function StarsComp:nvg_draw(ctx)
  local saturated_color = ctx:RGBAf(unpack(self.color))
  local transparent_color = ctx:TransRGBA(saturated_color, 0)

  for _, star in ipairs(self.stars) do
    local ux = star.x + star.vx * self.t
    local uy = star.y + star.vy * self.t
    local px, py = self.grid:get_pixel_pos(ux, uy, ctx.width, ctx.height)
    ctx:BeginPath()
    ctx:Circle(px, py, 3.0)
    ctx:FillColor(saturated_color)
    ctx:Fill()
  end
end
Stars = ecs.promote("Stars", StarsComp)

function grid_zoomer()
  local input = require("day10_input.lua")
  print("yayaya?")
  stars:set_stars(input)
  print("bleh?")

  local t = 0
  while true do
    local dt = 10905 - t
    if dt > 100 then
      t = math.floor(t + (dt / 100.0))
    elseif dt < 10.0 then
      t = t + 0.1
    else
      t = t + 1
    end
    t = math.min(10905, t)
    stars:set_time(t)
    grid:set_bounds(stars:get_bounds())
    tlabel:set_text(string.format("%0.2f", t))
    async.await_frames(1)
    if t >= 10905 then break end
  end
  async.await_frames(60)
  local dt = 0.2
  for _ = 1, 120 do
    t = t + dt
    dt = dt + 0.05
    stars:set_time(t)
    tlabel:set_text(string.format("%0.2f", t))
    async.await_frames(1)
  end
end

function init()
  myapp = app.App{
    width = width, height = height, title = "day10", msaa = true,
    clear_color = 0x000000ff, stats = false
  }

  myapp.camera:make_orthographic(-0.5, 0.5, -0.5, 0.5, 0.1, 30.0)
  myapp.camera.position:set(0.0, 0.0, 1.0)
  myapp.camera:update_matrix()

  grid = myapp.scene:create_child(require("nvggrid.t").NVGGrid, "grid", {
    color = {0.2, 0.2, 0.2, 1.0}, z_order = 0.5
  })

  stars = myapp.scene:create_child(Stars, "stars", {
    grid = grid
  })

  tlabel = myapp.scene:create_child(require("textlabel.t").TextLabel, "time", {
    x = width - 4, y = 24, color = {1.0, 1.0, 1.0, 1.0}, text = "0", fontsize = 24,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })

  attrib_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "attrib", {
    x = width - 4, y = height - 4, color = {1.0, 1.0, 1.0, 1.0}, text = "AoC Day 10 [mtknn]", fontsize = 12,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })

  async.run(grid_zoomer)
end

local writing_frames = false
local f = 0

function update()
  myapp:update()
  if writing_frames then
    local fn = string.format("frames/frame_%04d.png", f)
    gfx.save_screenshot(fn)
  end
  f = f + 1
end
