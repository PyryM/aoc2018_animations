-- day1.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local flat = require("material/flat.t")
local ecs = require("ecs")

local width, height = 512, 512

local BorderComp = graphics.NanoVGComponent:extend("BorderComp")
function BorderComp:init(options)
  BorderComp.super.init(self)
  self.plot = options.plot
end

function BorderComp:nvg_draw(ctx)
  ctx:load_font("font/FiraMono-Regular.ttf", "sans")
  ctx:FontFace("sans")
  ctx:FontSize(18)

  local w = (self.plot.plot_width / 512) * ctx.width
  local h = (self.plot.plot_height / 512) * ctx.height
  local x = 0.5 + math.floor((ctx.width - w) / 2)
  local y = 0.5 + math.floor((ctx.height - h) / 2)

  ctx:StrokeColor(ctx:RGBA(255, 255, 255, 255))
  ctx:StrokeWidth(1.0)

  local axis_pad = 14
  ctx:BeginPath()
  ctx:MoveTo(x, y - 7)
  ctx:LineTo(x, y - axis_pad)
  ctx:LineTo(x + w/2 - 20, y - axis_pad)
  ctx:MoveTo(x + w/2 + 20, y - axis_pad)
  ctx:LineTo(x + w, y - axis_pad)
  ctx:LineTo(x + w, y - 7)
  ctx:Stroke()

  ctx:TextAlign(ctx.ALIGN_MIDDLE + ctx.ALIGN_CENTER)
  ctx:Text(x + w/2, y - axis_pad, tostring(self.plot.plot_width), nil)

  ctx:TextAlign(ctx.ALIGN_RIGHT + ctx.ALIGN_MIDDLE)
  local botval = self.plot.plot_width * math.floor(self.plot.plot_height / 2)
  local topval = -botval
  ctx:Text(x - 7, y,       tostring(topval), nil)
  ctx:Text(x - 7, y + h/2, '0', nil)
  ctx:Text(x - 7, y + h,   tostring(botval), nil)

  ctx:BeginPath()
  ctx:Rect(x, y, w, h)
  ctx:Stroke()
  ctx:BeginPath()
  ctx:Rect(x - 2, y - 2, w + 4, h + 4)
  ctx:Stroke()

  if self.plot.hit_pos then
    local hitx = self.plot.hit_pos
    local hity = math.floor(self.plot.hit_pos / self.plot.plot_width)
    hitx = ((hitx % self.plot.plot_width) / 512) * ctx.width
    hitx = hitx + x
    hity = (hity / 512) * ctx.height
    hity = hity + y + h/2
    ctx:StrokeColor(ctx:RGB(255, 0, 0))
    ctx:FillColor(ctx:RGB(255, 0, 0))
    ctx:BeginPath()
    ctx:Circle(hitx, hity, 3)
    ctx:Fill()
    ctx:BeginPath()
    ctx:MoveTo(hitx, y + h + 10)
    ctx:LineTo(hitx - 10, y + h + 20)
    ctx:LineTo(hitx + 10, y + h + 20)
    ctx:LineTo(hitx, y + h + 10)
    ctx:Stroke()
    ctx:TextAlign(ctx.ALIGN_MIDDLE + ctx.ALIGN_CENTER)
    ctx:Text(hitx, y + h + 30, tostring(self.plot.hit_pos), nil)
  end
end
local Border = ecs.promote("TextBox", BorderComp)

local map_tex = nil
local plot = {
  hitsize = 200000,
  hitlist = terralib.new(uint8[200000]),
  hitzero = 100000,
  plot_width = 500,
  plot_height = 500
}
for idx = 0, plot.hitsize-1 do
  plot.hitlist[idx] = 0
end

local function resize_plot(w, h)
  plot.plot_width = w
  plot.plot_height = h
  plot.plot_entity.position:set(
    (512 - w) / 2, -(512 - h) / 2, 0
  )
  plot.plot_entity:update_matrix()
end

local function hit(num, cycle)
  local pos = num + plot.hitzero
  if pos >= 0 and pos < plot.hitsize then
    if plot.hitlist[pos] > 0 then return true end
    plot.hitlist[pos] = cycle or 1
  end
  return false
end

local function do_cycle(offsets, pos, inner_delay)
  local collision_pos = nil
  for idx, offset in ipairs(offsets) do
    local colorv = idx % 300
    if hit(pos, colorv + 1) then
      collision_pos = pos
      break
    end
    pos = pos + offset
    if inner_delay and inner_delay > 0 then
      async.await_frames(inner_delay)
    end
  end
  return pos, collision_pos
end

local function launch_script()
  local offsets = require("day1input.lua")
  local pos, hit = 0, nil
  resize_plot(350, 420)
  for cycle = 1, 50 do
    local delay = 0
    if cycle == 1 then delay = 1 end
    pos = do_cycle(offsets, pos, delay)
    async.await_frames(3)
  end
  for cycle = 51, 144 do
    pos, hit = do_cycle(offsets, pos, 0)
    if hit then
      print("HIT: " .. hit)
      plot.hit_pos = hit
      break
    end
    local delay_frames = 3
    if cycle > 130 then
      delay_frames = (cycle - 130)*3
    end
    async.await_frames(delay_frames)
  end
  async.await_frames(60)
  local startw = plot.plot_width
  for i = startw, 500 do
    resize_plot(i, 420)
    async.await_frames(2)
  end
end

function init()
  myapp = app.App{
    width = width, height = height, title = "day1", msaa = true,
    clear_color = 0x000000ff, stats = false
  }

  myapp.camera:make_orthographic(-256, 256, -256, 256, 0.1, 30.0)
  myapp.camera.position:set(0.0, 0.0, 1.0)
  myapp.camera:update_matrix()

  local map_geo = require("geometry").plane_geo{
    width = 512.0, height = 512.0, segments = 1
  }

  map_tex = gfx.Texture2d{
    width = 512, height = 512, 
    dynamic = true, allocate = true,
    format = gfx.TEX_RGBA8, flags = {min = 'point', mag = 'point'}
  }
  map_tex:commit()
  local map_mat = flat.FlatMaterial{texture = map_tex}
  local map = myapp.scene:create_child(graphics.Mesh, "fabric", map_geo, map_mat)
  map.position:set(6, 0, 0)
  map:update_matrix()
  plot.plot_entity = map

  async.run(launch_script)

  attrib_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "attrib", {
    x = 1020, y = 1020, color = {0.2, 0.2, 0.2, 1.0}, text = "AoC Day 3 [mtknn]", fontsize = 24,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })

  local border = myapp.scene:create_child(Border, "border", {
    plot = plot
  })
end

local COLORS = {
  {100, 100, 100},
}
COLORS[10] = {255, 255, 255}
local _base_colors = {
  {100, 100, 100}, {150, 150, 150}, {200, 200, 200}
}
for i = 1, 500 do
  local alpha = i/150
  --if i % 2 == 0 then alpha = 1.0 - alpha end
  alpha = 1.0 - alpha
  alpha = 0.5 + 0.5*alpha
  -- COLORS[i+10] = {0,
  --                  math.floor(255*alpha), --math.floor(255*(1.0-alpha)),
  --                  math.floor(255*alpha)}
  COLORS[i+10] = _base_colors[(i % 3)+1]
  --{0, math.random(128,255), 0}
end

function update_map()
  local cdata = map_tex.cdata
  local nhits = plot.hitsize
  local hits = plot.hitlist
  local hitzero = plot.hitzero
  local pw = plot.plot_width
  local ph = plot.plot_height

  local plotzero = math.floor(ph / 2) * pw
  local total_offset = hitzero - plotzero

  local dpos = 0
  local BG = {0, 0, 0}
  for row = 0, map_tex.width-1 do
    for col = 0, map_tex.height-1 do
      local color = BG
      if row < ph and col < pw then
        local srcpos = (row * pw + col) + total_offset
        if srcpos >= 0 and srcpos < nhits then
          local v = hits[srcpos]
          if v > 0 then
            color = COLORS[v+9] 
            --if not color then truss.error("EH? " .. v+10) end
          end
        end 
      end
      cdata[dpos+0] = color[1]
      cdata[dpos+1] = color[2]
      cdata[dpos+2] = color[3]
      cdata[dpos+3] = 255
      dpos = dpos + 4
    end
  end
  map_tex:update()
end

local writing_frames = false
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
