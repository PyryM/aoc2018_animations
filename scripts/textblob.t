-- textblob.t
--
-- a text display implemented on top of tilemap

local class = require("class")
local m = {}

local TextBlob = class("TextBlob")
m.TextBlob = TextBlob

function TextBlob:init(options)
  self.tilemap = options.tilemap
  if self.tilemap.tilemap then
    self.tilemap = self.tilemap.tilemap
  end
  self.target_tex = options.tex or self.tilemap.index_tex
  self.font_cols = options.font_cols or 32
  self.font_rows = options.font_rows or 4
  self.char_offset = options.char_offset or 0
end

function TextBlob:resolve_char(c)
  if type(c) == 'table' then
    return unpack(c)
  end

  if type(c) == 'string' then
    c = c:byte(1)
    c = c + self.char_offset
  end
  local cc0 = c % self.font_cols
  local cc1 = (c - cc0) / self.font_cols
  return cc0, cc1 
end

function TextBlob:assert_valid_pos(x, y)
  local width, height = self.target_tex.width, self.target_tex.height
  if x < 0 or x >= width or y < 0 or y >= height then
    truss.error(string.format("Invalid location: %d %d", x, y))
  end
end

function TextBlob:fill(x, y, w, h, clearchar, fgcolor, bgcolor, cb)
  local buffer = self.target_tex.cdata
  local cc0, cc1 = self:resolve_char(clearchar)
  fgcolor = fgcolor or 255
  bgcolor = bgcolor or 0

  local stride = self.target_tex.width
  local x_end = math.min(self.target_tex.width, x + w)
  local y_end = math.min(self.target_tex.height, y + h)
  for row = y, y_end - 1 do
    for col = x, x_end - 1 do
      local pos = 4 * ((row * stride) + col)
      buffer[pos] = cc0
      buffer[pos+1] = cc1
      buffer[pos+2] = bgcolor
      buffer[pos+3] = fgcolor
      self.dirty = true
    end
    if cb then cb(row) end
  end
  return self
end

function TextBlob:clear(clearchar, fgcolor, bgcolor, cb)
  clearchar = clearchar or 0
  self:fill(0, 0, self.target_tex.width, self.target_tex.height, 
            clearchar, fgcolor, bgcolor, cb)
  return self
end

function TextBlob:put_char(c, x, y, fg, bg)
  self:assert_valid_pos(x, y)
  local cc0, cc1 = self:resolve_char(c)
  local pos = 4 * (y * self.target_tex.width + x)
  local buffer = self.target_tex.cdata
  buffer[pos+0], buffer[pos+1] = cc0, cc1
  buffer[pos+2], buffer[pos+3] = bg, fg
end

function TextBlob:put_codepoints(points, x, y, fg, bg)
  local nchars = #points
  local width = self.target_tex.width
  local height = self.target_tex.height
  self:assert_valid_pos(x, y)
  local buffer = self.target_tex.cdata
  fg = fg or 255
  bg = bg or 0
  for idx = 1, nchars do
    if x >= width then break end
    local pos = 4*(y * width + x)
    local cc0, cc1 = self:resolve_char(points[idx])
    buffer[pos+0] = cc0
    buffer[pos+1] = cc1
    buffer[pos+2] = bg
    buffer[pos+3] = fg
    x = x + 1
  end
  self.dirty = true
  return x
end

function TextBlob:put_text(text, x, y, fg, bg)
  local nchars = #text
  local width = self.target_tex.width
  local height = self.target_tex.height
  self:assert_valid_pos(x, y)
  local buffer = self.target_tex.cdata
  fg = fg or 255
  bg = bg or 0
  local char_offset = self.char_offset or 0
  for idx = 1, nchars do
    if x >= width then break end
    local pos = 4*(y * width + x)
    local c = math.max(0, text:byte(idx) + char_offset)
    local cc0 = c % self.font_cols
    local cc1 = (c - cc0) / self.font_cols
    buffer[pos+0] = cc0
    buffer[pos+1] = cc1
    buffer[pos+2] = bg
    buffer[pos+3] = fg
    x = x + 1
  end
  self.dirty = true
  return x
end

function TextBlob:scroll_region(x, y, w, h, nlines)
  self:assert_valid_pos(x, y)
  self:assert_valid_pos(x+w-1, y+h-1)
  nlines = nlines or 1
  local width = self.target_tex.width
  local height = self.target_tex.height
  local buffer = self.target_tex.cdata
  for row = y, (y+h-nlines-1) do
    local destpos = 4*(row*width + x)
    local srcpos = destpos + 4*width*nlines
    for col = x, (x+w-1) do
      buffer[destpos] = buffer[srcpos]
      buffer[destpos+1] = buffer[srcpos+1]
      buffer[destpos+2] = buffer[srcpos+2]
      buffer[destpos+3] = buffer[srcpos+3]
      destpos = destpos + 4
      srcpos = srcpos + 4
    end
  end
end

function TextBlob:update()
  if self.dirty and self.target_tex then
    self.target_tex:update()
    self.dirty = false
  end
end

return m