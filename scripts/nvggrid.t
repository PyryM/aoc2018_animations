local graphics = require("graphics")
local ecs = require("ecs")
local m = {}

local NVGGridComp = graphics.NanoVGComponent:extend("NVGGridComp")
m.NVGGridComp = NVGGridComp

function NVGGridComp:init(options)
  NVGGridComp.super.init(self)
  self.fontsize = options.fontsize or 12
  self.color = options.color or {1, 1, 1, 1}
  self.z_order = options.z_order or 0.0
  self.bounds = {x0 = 0, x1 = 100, y0 = 0, y1 = 100}
end

function NVGGridComp:set_bounds(bounds)
  self.bounds = bounds
end

function NVGGridComp:get_pixel_pos(ux, uy, w, h)
  w = w or self.width
  h = h or self.height
  local rx = (ux - self.bounds.x0) / (self.bounds.x1 - self.bounds.x0)
  local ry = (uy - self.bounds.y0) / (self.bounds.y1 - self.bounds.y0)
  return rx * w, ry * h
end

local function calc_deltas(u0, u1, u_spacing, pixel_size)
  local du = u_spacing
  if u0 > u1 then
    du = -u_spacing
  end
  local u = math.floor(u0 / u_spacing) * u_spacing
  local p = pixel_size * ((u - u0) / (u1 - u0))
  local dp = du * (pixel_size / (u1 - u0))
  return u, du, p, dp
end

function NVGGridComp:_draw_grid(ctx, spacing)
  local u, du, px, dx = calc_deltas(self.bounds.x0, self.bounds.x1, 
                                     spacing, ctx.width)
  if dx < 0 then truss.error("Negative dx? " .. dx) end
  while px < ctx.width do
    ctx:MoveTo(px, 0)
    ctx:LineTo(px, ctx.height)
    u = u + du
    px = px + dx
  end

  local v, dv, py, dy = calc_deltas(self.bounds.y0, self.bounds.y1, 
                                     spacing, ctx.height)
  if dy < 0 then truss.error("Negative dy? " .. dy) end
  while py < ctx.height do
    ctx:MoveTo(0, py)
    ctx:LineTo(ctx.width, py)
    v = v + dv
    py = py + dy
  end
end

function NVGGridComp:nvg_draw(ctx)
  ctx:load_font("font/FiraMono-Regular.ttf", "sans")
  local saturated_color = ctx:RGBAf(unpack(self.color))
  local transparent_color = ctx:TransRGBA(saturated_color, 0)

  local unit_width = self.bounds.x1 - self.bounds.x0
  local unit_height = self.bounds.y1 - self.bounds.y0
  local max_unit_size = math.max(math.abs(unit_width), math.abs(unit_height))

  -- figure out largest power of ten that still fits in the window
  local major_grid_size = 1
  local major_grid_power = 0
  while major_grid_size < max_unit_size do
    major_grid_size = major_grid_size * 10
    major_grid_power = major_grid_power + 1
  end
  major_grid_size = major_grid_size / 10
  major_grid_power = major_grid_power - 1

  -- (0.1, 1.0)
  local sub_alpha = major_grid_size / max_unit_size
  sub_alpha = 1.0 - ((sub_alpha - 0.1) / 0.9)
  local minor_color = ctx:LerpRGBA(saturated_color, transparent_color, sub_alpha)

  -- draw gridlines
  ctx:BeginPath()
  self:_draw_grid(ctx, major_grid_size / 10.0)
  ctx:StrokeColor(minor_color)
  ctx:StrokeWidth(3)
  ctx:Stroke()

  ctx:BeginPath()
  self:_draw_grid(ctx, major_grid_size)
  ctx:StrokeColor(saturated_color)
  ctx:StrokeWidth(1 + sub_alpha*2)
  ctx:Stroke()
end

m.NVGGrid = ecs.promote("NVGGrid", NVGGridComp)

return m