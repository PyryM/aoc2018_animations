local graphics = require("graphics")
local ecs = require("ecs")
local m = {}

local TextLabelComp = graphics.NanoVGComponent:extend("TextLabelComp")
m.TextLabelComp = TextLabelComp

function TextLabelComp:init(options)
  TextLabelComp.super.init(self)
  self.text = options.text or "?"
  self.fontsize = options.fontsize or 12
  self.color = options.color or {1, 1, 1, 1}
  self.x = options.x or 50
  self.y = options.y or 50
  self.align = options.align
  self.shadow = options.shadow
  self.z_order = options.z_order or -1.0
end

function TextLabelComp:set_text(newtext)
  self.text = newtext
end

local function shadow_text(ctx, x, y, text, fg, bg)
  ctx:FontBlur(6.0)
  ctx:FillColor(bg or ctx:RGBA(0, 0, 0, 255))
  ctx:Text(x, y, text, nil)
  ctx:Text(x, y, text, nil)
  ctx:Text(x, y, text, nil)
  ctx:Text(x, y, text, nil)
  ctx:Text(x, y, text, nil)
  ctx:FontBlur(0.0)
  ctx:FillColor(fg or ctx:RGBA(255, 255, 255, 255))
  ctx:Text(x, y, text, nil)
end

function TextLabelComp:nvg_draw(ctx)
  ctx:load_font("font/FiraMono-Regular.ttf", "sans")
  local color = ctx:RGBAf(unpack(self.color))
  ctx:FontFace("sans")
  ctx:TextAlign((self.align == "right" and ctx.ALIGN_RIGHT) or ctx.ALIGN_LEFT)
  ctx:FontSize(self.fontsize)
  if self.shadow then
    local shadowcol = ctx:RGBAf(unpack(self.shadow))
    shadow_text(ctx, self.x, self.y, self.text, color, shadowcol)
  else
    ctx:FillColor(color)
    ctx:Text(self.x, self.y, self.text, nil)
  end
end

m.TextLabel = ecs.promote("TextLabel", TextLabelComp)

return m