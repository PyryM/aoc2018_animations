-- day13_tilegen.t
--
-- this just generates the tile textures for day13

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local flat = require("material/flat.t")
local colors = require("colors.t")
local ecs = require("ecs")

local tile_mode = false
local width, height = 1024, 512
if not tile_mode then width, height = 256, 256 end

local TileGenComp = graphics.NanoVGComponent:extend("TileGenComp")
function TileGenComp:init(options)
  TileGenComp.super.init(self)
  self.inner_color = options.inner_color
  self.border_color = options.border_color
  self.border_width = options.border_width * (height/2)
  self.track_width = options.track_width * (height/2)
end

function TileGenComp:draw_curve_inner(ctx, cx, cy)
  ctx:BeginPath()
  ctx:Circle(cx, cy, height/4)
  ctx:StrokeColor(ctx:RGBA(unpack(self.inner_color)))
  ctx:StrokeWidth(self.track_width)
  ctx:Stroke()
end

function TileGenComp:draw_curve_borders(ctx, draw_outer, cx, cy)
  ctx:BeginPath()
  if draw_outer then
    ctx:Circle(cx, cy, height/4 + self.track_width/2)
  end
  ctx:Circle(cx, cy, height/4 - self.track_width/2)
  ctx:StrokeColor(ctx:RGBA(unpack(self.border_color)))
  ctx:StrokeWidth(self.border_width)
  ctx:Stroke()
end

function TileGenComp:nvg_draw(ctx)
  if tile_mode then self:draw_tiles(ctx) else self:draw_sprites(ctx) end
end

function TileGenComp:draw_sprites(ctx)
  local w, h = ctx.width, ctx.height
  local function denorm_point(p)
    return w*0.5*(p[1]+1), h*0.5*(p[2]+1)
  end

  ctx:BeginPath()
  ctx:MoveTo(denorm_point{0.0, 0.9})
  ctx:LineTo(denorm_point{0.0, 0.9})
  
  ctx:FillColor(ctx:RGBA(unpack(self.border_color)))
  ctx:Fill()
  ctx:StrokeColor(ctx:RGBA(unpack(self.inner_color)))
  ctx:StrokeWidth(w*0.2)
  ctx:Stroke()
end

function TileGenComp:draw_tiles(ctx)
  local w, h = ctx.width, ctx.height
  local corners = {{0, 0}, {w/4, 0}, {w/4, h/2}, {0, h/2}}
  for i, corner in ipairs(corners) do
    ctx:Save()
    ctx:Translate((i-1)*w/4, h/2)
    ctx:Scissor(0, 0, w/4, h/2)
    self:draw_curve_inner(ctx, unpack(corner))
    self:draw_curve_borders(ctx, true, unpack(corner))
    ctx:Restore()
  end

  ctx:Save()
  ctx:Translate(w/4, 0)
  ctx:Scissor(0, 0, w/4, h/2)
  ctx:BeginPath()
  ctx:MoveTo(0, h/4)
  ctx:LineTo(w/4, h/4)
  ctx:StrokeColor(ctx:RGBA(unpack(self.inner_color)))
  ctx:StrokeWidth(self.track_width)
  ctx:Stroke()
  ctx:BeginPath()
  ctx:MoveTo(0, h/4 + self.track_width/2)
  ctx:LineTo(w/4, h/4 + self.track_width/2)
  ctx:MoveTo(0, h/4 - self.track_width/2)
  ctx:LineTo(w/4, h/4 - self.track_width/2)
  ctx:StrokeColor(ctx:RGBA(unpack(self.border_color)))
  ctx:StrokeWidth(self.border_width)
  ctx:Stroke()
  ctx:Restore()

  ctx:Save()
  ctx:Translate(2*w/4, 0)
  ctx:Scissor(0, 0, w/4, h/2)
  ctx:BeginPath()
  ctx:MoveTo(w/8, 0)
  ctx:LineTo(w/8, h/2)
  ctx:StrokeColor(ctx:RGBA(unpack(self.inner_color)))
  ctx:StrokeWidth(self.track_width)
  ctx:Stroke()
  ctx:BeginPath()
  ctx:MoveTo(w/8 + self.track_width/2, 0)
  ctx:LineTo(w/8 + self.track_width/2, h/2)
  ctx:MoveTo(w/8 - self.track_width/2, 0)
  ctx:LineTo(w/8 - self.track_width/2, h/2)
  ctx:StrokeColor(ctx:RGBA(unpack(self.border_color)))
  ctx:StrokeWidth(self.border_width)
  ctx:Stroke()
  ctx:Restore()

  ctx:Save()
  ctx:Translate(3 * w/4, 0)
  ctx:Scissor(0, 0, w/4, h/2)
  for i, corner in ipairs(corners) do
    self:draw_curve_inner(ctx, unpack(corner))
  end
  ctx:BeginPath()
  ctx:MoveTo(w/8, 0)
  ctx:LineTo(w/8, h/2)
  ctx:MoveTo(0, h/4)
  ctx:LineTo(w/4, h/4)
  ctx:StrokeColor(ctx:RGBA(unpack(self.inner_color)))
  ctx:StrokeWidth(self.track_width)
  ctx:Stroke()
  for i, corner in ipairs(corners) do
    self:draw_curve_borders(ctx, false, unpack(corner))
  end
  ctx:Restore()
end
local TileGen = ecs.promote("TileGen", TileGenComp)

function init()
  myapp = app.App{
    width = width, height = height, title = "day13_tilegen", msaa = true,
    clear_color = 0x00000000, stats = false
  }

  myapp.camera:make_orthographic(-0.5, 0.5, -0.5, 0.5, 0.1, 30.0)
  myapp.camera.position:set(0.0, 0.0, 1.0)
  myapp.camera:update_matrix()

  tilegen = myapp.scene:create_child(TileGen, "tilegen", {
    border_color = colors.rose,
    inner_color = colors.graphite,
    border_width = 0.2, track_width = 0.5
  })
end

local saved = false
function update()
  myapp:update()
  if not saved then
    saved = true
    local fn = (tile_mode and "textures/day13_tiles.png") 
                or "textures/day13_sprite.png"
    gfx.save_screenshot(fn)
  end
end