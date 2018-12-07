local graphics = require("graphics")
local ecs = require("ecs")
local m = {}

local TextBoxComp = graphics.NanoVGComponent:extend("TextBoxComp")
m.TextBoxComp = TextBoxComp

function TextBoxComp:init(options)
  TextBoxComp.super.init(self)
  self.fontsize = options.fontsize or 12
  self.lineheight = options.lineheight or (self.fontsize * 1.1)
  self.color = options.color or {1, 1, 1, 1}
  self.x = options.x or 50
  self.y = options.y or 10
  self.height = options.height or 700
  self.align = options.align
  self.shadow = options.shadow
  self.linecount = options.linecount or math.ceil(self.height / self.lineheight)
  self.linepos = 0
  self.lines = {"--- Begin Day 4 Input ---"}
end

function TextBoxComp:push_line(newline)
  table.insert(self.lines, newline)
  if #self.lines > self.linecount then
    self.linepos = self.linepos + 1
  end
end

function TextBoxComp:nvg_draw(ctx)
  ctx:load_font("font/FiraMono-Regular.ttf", "sans")
  local color = ctx:RGBAf(unpack(self.color))
  ctx:FontFace("sans")
  ctx:TextAlign((self.align == "right" and ctx.ALIGN_RIGHT) or ctx.ALIGN_LEFT)
  ctx:FontSize(self.fontsize)
  
  local nlines = self.linecount

  ctx:FillColor(color)
  local y = self.y
  for i = 1, nlines do
    if not self.lines[self.linepos+i] then break end
    ctx:Text(self.x, y, self.lines[self.linepos+i], nil)
    y = y + self.lineheight
  end
end

m.TextBox = ecs.promote("TextBox", TextBoxComp)

return m