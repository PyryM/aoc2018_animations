-- day1.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local flat = require("material/flat.t")
local ecs = require("ecs")

local width, height = 512, 512
local SCALE = 32

local COLORS = {
  {100, 100, 100}
}
COLORS[10] = {255, 255, 255}
local _base_colors = {
  {100, 100, 100}, {150, 150, 150}, {200, 200, 200}
}

local function fade_color(c, alpha)
  return {c[1]*alpha, c[2]*alpha, c[3]*alpha}
end

for i = 0, 127 do
  local alpha = 0.2 + 0.8 * (i/127)
  local blue = fade_color({20, 255, 255}, 1.0 - alpha)
  local orange = fade_color({255, 200, 20}, 1.0 - alpha)
  local purple = fade_color({255, 20, 200}, 1.0 - alpha)
  local green = fade_color({20, 255, 20}, 1.0 - alpha)

  COLORS[128*0 + i + 11] = blue 
  COLORS[128*1 + i + 11] = purple
  COLORS[128*2 + i + 11] = orange
  COLORS[128*3 + i + 11] = green
end

local BorderComp = graphics.NanoVGComponent:extend("BorderComp")
function BorderComp:init(options)
  BorderComp.super.init(self)
  self.plot = options.plot
end

function BorderComp:nvg_draw(ctx)
  ctx:load_font("font/FiraMono-Regular.ttf", "sans")
  ctx:FontFace("sans")
  ctx:FontSize(18)

  local scale2 = SCALE * 2

  local plot_pixel_size = (1.0 / scale2) * ctx.width

  local w = (self.plot.plot_width / scale2) * ctx.width
  local h = (self.plot.plot_height / scale2) * ctx.height
  local x = 0.5 + math.floor((ctx.width - w) / 2)
  local y = 0.5 + math.floor((ctx.height - h) / 2)

  ctx:StrokeColor(ctx:RGBA(255, 255, 255, 255))
  ctx:FillColor(ctx:RGBA(255, 255, 255, 255))
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
  local botval = self.plot.plot_width * math.floor((self.plot.plot_height - 1) / 2)
  local topval = -self.plot.plot_width * math.floor((self.plot.plot_height - 1) / 2)
  ctx:Text(x - 7, y + plot_pixel_size/2,       tostring(topval), nil)
  ctx:Text(x - 7, y + h/2, '0', nil)
  ctx:Text(x - 7, y + h - plot_pixel_size/2,   tostring(botval), nil)

  ctx:BeginPath()
  ctx:Rect(x, y, w, h)
  ctx:Stroke()
  ctx:BeginPath()
  ctx:Rect(x - 2, y - 2, w + 4, h + 4)
  ctx:Stroke()

  ctx:TextAlign(ctx.ALIGN_LEFT + ctx.ALIGN_TOP)
  ctx:Text(x + w + 5, y + h - 35, string.format("Cycle: %d", self.plot.cycle_count), nil)
  local point_color = COLORS[self.plot.cur_color] or {255, 0, 0}
  ctx:FillColor(ctx:RGB(unpack(point_color)))
  ctx:Text(x + w + 5, y + h - 15, string.format("Position: %d", self.plot.last_pos), nil)

  local ox = x + (w/2) - (self.plot.offset_chars/2)*10
  ctx:FillColor(ctx:RGB(255, 255, 255))
  ctx:Text(ox, y+h+20, "[", nil)
  ox = ox + 20
  for idx, offset in ipairs(self.plot.offsets) do
    local ostr = tostring(offset) .. " "
    if offset >= 0 then ostr = "+" .. ostr end
    local colorv = 11 + ((idx % 4) * 128)
    if idx ~= self.plot.offset_idx then
      colorv = colorv + 60
    end
    ctx:FillColor(ctx:RGB(unpack(COLORS[colorv])))
    ctx:Text(ox, y + h + 20, ostr, nil)
    ox = ox + ctx:TextBounds(ox, y + h + 20, ostr, nil, nil)
  end
  ctx:FillColor(ctx:RGB(255, 255, 255))
  ctx:Text(ox+5, y+h+20, "]", nil)

  if self.plot.hit_pos then
    local hitx = self.plot.hit_pos
    local hity = math.floor(self.plot.hit_pos / self.plot.plot_width)
    hitx = (((hitx % self.plot.plot_width) + 0.5) / scale2) * ctx.width
    hitx = hitx + x
    hity = ((hity) / scale2) * ctx.height
    hity = hity + y + h/2
    ctx:StrokeColor(ctx:RGB(255, 0, 0))
    ctx:FillColor(ctx:RGB(255, 255, 255))
    ctx:BeginPath()
    ctx:Circle(hitx, hity, 3)
    ctx:Fill()
    ctx:BeginPath()
    ctx:MoveTo(hitx, y + h - 15)
    ctx:LineTo(hitx - 3, y + h - 5)
    ctx:LineTo(hitx + 3, y + h - 5)
    ctx:LineTo(hitx, y + h - 15)
    ctx:Fill()
    ctx:TextAlign(ctx.ALIGN_CENTER + ctx.ALIGN_TOP)
    ctx:Text(hitx, y + h + 3, tostring(self.plot.hit_pos), nil)
  end
end
local Border = ecs.promote("TextBox", BorderComp)

local map_tex = nil
local plot = {
  hitsize = 200000,
  hitlist = terralib.new(uint16[200000]),
  hitzero = 100000,
  plot_width = 500,
  plot_height = 500,
  cycle_count = 0,
  total_iterations = 0,
  cur_color = 0,
  last_pos = 0,
  offsets = {1, 1, 1},
  offset_idx = 1
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
  local ndelays = 0
  local colorv = 0
  --local cycle_color_offset = (plot.cycle_count % 4) * 128
  for idx, offset in ipairs(offsets) do
    --colorv = cycle_color_offset + (math.floor(idx/4) % 128)
    colorv = plot.cycle_count*10 + ((idx % 4) * 128)
    local had_hit = hit(pos, colorv + 1)
    plot.last_pos = pos
    plot.cur_color = colorv + 11
    plot.total_iterations = plot.total_iterations + 1
    plot.offset_idx = idx
    plot.offsets = offsets
    if had_hit then
      collision_pos = pos
      break
    end
    pos = pos + offset
    if inner_delay and inner_delay > 0 then
      if inner_delay >= 1 then
        async.await_frames(inner_delay)
        ndelays = ndelays + 1
      elseif idx % math.ceil(1.0 / inner_delay) == 0 then
      --elseif math.random() < inner_delay then
        async.await_frames(1)
        ndelays = ndelays + 1
      end
    end
  end
  if ndelays == 0 then
    async.await_frames(1)
  end
  return pos, collision_pos
end

local function launch_script()
  --local offsets = require("day1input.lua")
  local offsets = {-61, 108, 45, -75} --, -4}
  plot.offset_chars = #("[-61 +108 +45 -75]")
  plot.offset_sum = 17

  local pos, hit = 0, nil
  resize_plot(10, 51)
  for cycle = 1, 145 do
    plot.cycle_count = cycle - 1
    --local delay = (1.0 / 4.0) / math.min(cycle, 50)
    if cycle == 3 then
      local startw = plot.plot_width
      for i = startw, 17 do
        resize_plot(i, 51)
        async.await_frames(5)
      end
    end

    local delay = 15
    if cycle > 142 then
      delay = delay + (cycle - 142)*0.05
    end
    --if cycle == 1 then delay = 0.25 end
    pos, hit = do_cycle(offsets, pos, delay)
    if hit then
      print("HIT: " .. hit)
      plot.hit_pos = hit
      break
    end
  end
  -- async.await_frames(60)

end

function init()
  myapp = app.App{
    width = width, height = height, title = "day1", msaa = true,
    clear_color = 0x000000ff, stats = false
  }

  myapp.camera:make_orthographic(-SCALE, SCALE, -SCALE, SCALE, 0.1, 30.0)
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

  local attrib_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "attrib", {
    x = width - 5, y = height - 4, color = {0.5, 0.5, 0.5, 1.0}, text = "AoC Day 1 [mtknn]", fontsize = 12,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })
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
            color = COLORS[v+11] 
            if not color then truss.error("EH? " .. v+9) end
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

--avconv -r 30 -f image2 -i frame_%04d.png -c:v libx264 -preset veryslow -crf 18 -pix_fmt yuv420p ../day1_p1.mp4