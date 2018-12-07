-- day5

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local tilemap = require("tilemap.t")
local textblob = require("textblob.t")
local async = require("async")
local class = require("class")

local ROWS, COLS = 50, 100
local writing_frames = true

local Reactor = class("Reactor")
function Reactor:init(options)
  self.tilemap = options.tilemap
  --self.blob = textblob.TextBlob{tilemap = self.tilemap}
  self.embers = {}
end

function Reactor:prep_hot_cold()
  self.cold_end = 0
  self.hot_end = 1
  self.finished = false
end

function Reactor:hot_cold_iter()
  if self.hot_end >= self.n_indices then 
    print("Finished")
    self.finished = true
    return
  end
  if self.cold_end >= 0 and 
  math.abs(self.raw_chars[self.cold_end] - self.raw_chars[self.hot_end]) == 32 then
    self.burn_list[self.cold_end] = 1
    self.burn_list[self.hot_end] = 1
    self.hot_end = self.hot_end + 1
    self.cold_end = self.prev_indices[self.cold_end]
    self.prev_indices[self.hot_end] = self.cold_end
  else
    self.cold_end = self.hot_end
    self.hot_end = self.hot_end + 1
  end
  self.embers = {}
  self.embers[self.hot_end] = 2
  self.embers[self.cold_end] = 1
end

-- def hot_cold(units):
--     insize = len(units)
--     ubytes = bytes(units, encoding='ascii')
--     alive = np.ones(insize).astype(np.uint32)
--     prev_links = np.arange(0, insize+1).astype(np.int32) - 1
--     cold_end = 0
--     hot_end = 1
--     while hot_end < insize:
--         if cold_end >= 0 and abs(ubytes[cold_end] - ubytes[hot_end]) == 32:
--             alive[cold_end] = 0
--             alive[hot_end] = 0
--             hot_end += 1
--             cold_end = prev_links[cold_end]
--             prev_links[hot_end] = cold_end
--         else:
--             cold_end = hot_end
--             hot_end += 1
--     return np.sum(alive)

function Reactor:set_input(input)
  print(#input)
  self.input = input
  self.raw_chars = terralib.new(uint8[#input+1])
  self.next_indices = terralib.new(int32[#input+1])
  self.prev_indices = terralib.new(int32[#input+1])
  self.burn_list = terralib.new(int32[#input+1])
  for i = 0, #input do
    self.next_indices[i] = i + 1
    self.prev_indices[i] = i - 1
    self.burn_list[i] = 0
    self.raw_chars[i] = input:byte(i+1) or 0
  end
  self.n_indices = #input
end

local function burn_resetter(data, p0, n, speed)
  for i = 0, (n-1) do
    if math.random() < 0.5 then
      async.await_frames(1)
    end
    data[p0 + i] = 0
  end
end

function Reactor:animate_reset()
  print("Animating reset")
  self.next_indices = terralib.new(int32[self.n_indices+1])
  self.prev_indices = terralib.new(int32[self.n_indices+1])
  for i = 0, self.n_indices do
    self.next_indices[i] = i + 1
    self.prev_indices[i] = i - 1
  end
  local resetters = {}
  for i = 0, ROWS-1 do
    resetters[i+1] = async.run(burn_resetter, self.burn_list, i*COLS, COLS)
  end
  return async.all(resetters)
end

function Reactor:load_input(fn)
  self:set_input(truss.load_string_from_file(fn))
end

function Reactor:_burn(pos, burnval)
  local n_indices = self.n_indices
  if pos < 0 or pos >= n_indices then return false end
  if self.burn_list[pos] > 0 then return false end
  self.burn_list[pos] = burnval or 1
  local prev_idx = self.prev_indices[pos]
  local next_idx = self.next_indices[pos]
  if prev_idx < -1 then return end
  if next_idx < -1 then return end
  if prev_idx >= 0 and prev_idx < n_indices then
    self.next_indices[prev_idx] = next_idx
    self.embers[prev_idx] = 1
  end
  if next_idx >= 0 and next_idx < n_indices then
    self.prev_indices[next_idx] = prev_idx
    self.embers[next_idx] = 1
  end
end

function Reactor:rasterize(skip)
  local tm = self.tilemap
  if tm.tilemap then
    tm = tm.tilemap
  end
  local target_tex = tm.index_tex
  local buffer = target_tex.cdata
  local w, h = target_tex.width, target_tex.height
  local maxchars = w*h

  local pos = 0
  local ipos = 0
  local nwritten = 0
  if skip then
    while ipos < self.n_indices do
      if self.burn_list[ipos] == 0 then break end
      ipos = self.next_indices[ipos]
    end
  end
  local font_cols = tm.font_cols or 32
  local font_offset = tm.font_offset or 0
  while ipos >= 0 and ipos < self.n_indices and nwritten < maxchars do
    local c = self.raw_chars[ipos] + font_offset
    local fg, bg = 245, 5
    if self.burn_list[ipos] > 0 then
      fg = 135
    elseif self.embers[ipos] then
      if self.embers[ipos] == 1 then
        fg, bg = 5, 185
      else
        fg, bg = 5, 195
      end
    end
    buffer[pos] = c % font_cols
    buffer[pos+1] = c / font_cols
    buffer[pos+2] = bg
    buffer[pos+3] = fg
    pos = pos + 4
    nwritten = nwritten + 1
    if skip then
      ipos = self.next_indices[ipos]
    else
      ipos = ipos + 1
    end
  end
  while nwritten < maxchars do
    buffer[pos] = 0
    buffer[pos+1] = 0
    buffer[pos+2] = 0
    buffer[pos+3] = 0
    pos = pos + 4
    nwritten = nwritten + 1
  end
  target_tex:update()
end


function Reactor:_try_burn(p0, p1)
  if p0 < 0 or p1 < 0 or p0 >= self.n_indices or p1 >= self.n_indices then 
    return false
  end
  if self.burn_list[p0] >= 1 or self.burn_list[p1] >= 1 then 
    return false 
  end
  local c0, c1 = self.raw_chars[p0], self.raw_chars[p1]
  if math.abs(c1 - c0) == 32 then
    self:_burn(p0)
    self:_burn(p1)
    return true
  end
end

function Reactor:burn()
  local embers = self.embers
  self.embers = {}
  for pos, _ in pairs(embers) do
    if self.burn_list[pos] < 1 then
      local prev_idx = self.prev_indices[pos]
      local next_idx = self.next_indices[pos]
      if not self:_try_burn(prev_idx, pos) then
        self:_try_burn(pos, next_idx)
      end
    end
  end
end

function Reactor:ember_count()
  local c = 0
  for pos, _ in pairs(self.embers) do
    c = c + 1
  end
  return c
end

function Reactor:initial_find_embers()
  self.embers = {}
  for idx = 0, #self.input-2 do
    local c0, c1 = self.raw_chars[idx], self.raw_chars[idx+1]
    if math.abs(c1 - c0) == 32 then
      self.embers[idx] = true
    end
  end
end

function Reactor:find_ember()
  local pos = 0
  while pos >= 0 and pos < self.n_indices do
    local pnext = self.next_indices[pos]
    if self:_try_burn(pos, pnext) then
      return
    end
    pos = pnext
  end
end

function Reactor:update()
  --self.blob:update()
  self.target_tex:update()
end

function init()
  local mult = 1
  local width, height = 8*COLS*mult, 16*ROWS*mult
  myapp = app.App{
    width = width, height = height, title = "day5", msaa = true,
    clear_color = 0x000000ff, stats = false
  }

  local function scale_camera_to(cursize, tarsize, nframes)
    local min_size = cursize
    local d_size = (tarsize - min_size) / nframes
    for f = 1, nframes do
      local alpha = f*d_size + min_size
      myapp.camera:make_orthographic(0.0, alpha, 1.0 - alpha, 1.0, 0.1, 30.0)
      async.await_frames(1)
    end
  end

  myapp.camera:make_orthographic(0.0, 1.0, 0.0, 1.0, 0.1, 30.0)
  -- async.run(function()
  --   scale_camera_to(1/8, 1/8, 1)
  --   async.await_frames(120)
  --   scale_camera_to(1/8, 1/4, 60)
  --   async.await_frames(120)
  --   scale_camera_to(1/4, 1, 60)
  -- end)

  --font_tex = gfx.Texture("textures/tinyfont_tiny.png", {min = 'point', mag = 'point'})
  font_tex = gfx.Texture("textures/vga_font.png", {min = 'point', mag = 'point'})
  colormap_tex = gfx.Texture("textures/cga.png", {min = 'point', mag = 'point', 
                                                  u = 'clamp', v = 'clamp'})

  tiles = myapp.scene:create_child(tilemap.Tilemap, "tilemap", {
    rows = ROWS, cols = COLS,
    colormap = colormap_tex, charmap = font_tex,
    font_cols = 64, font_rows = 32, font_offset = -32,
    width = 1.0, height = 1.0
  })
  tiles.position:set(0.0, 0.0, -1.0)
  tiles:update_matrix()

  -- attrib_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "attrib", {
  --   x = width - 5, y = height - 4, color = {0.0, 1.0, 0.0, 1.0}, text = "AoC Day 5 [mtknn]", fontsize = 24,
  --   align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  -- })

  reactor = Reactor{tilemap = tiles}
  reactor:load_input("day5snow.txt")
  --reactor:load_input("day5_input.txt")

  local function mainmajig()
    local f = 0
    local speed = 0.1
    local accel_max = 20
    local accel = accel_max
    reactor:prep_hot_cold()
    while true do
      if reactor.finished then return end
      f = f + 1
      accel = accel - 1
      if accel < 0 and speed < 10 then
        accel = accel_max
        speed = speed + 0.3
      end
      --local ec = reactor:ember_count()
      --print(ec)
      --if ec <= 0 then
      --  reactor:find_ember()
      --end
      --reactor:burn()
      reactor:hot_cold_iter()
      if speed <= 1 or f % math.floor(speed) == 0 then
        async.await_frames(math.max(1, math.ceil(1.0 / speed)))
      end
    end
  end

  async.run(function()
    --reactor:initial_find_embers()
    --reactor:find_ember()
    while true do
      mainmajig()
      async.await_frames(60)
      async.await(reactor:animate_reset())
      writing_frames = false
    end
  end).next(print, print)

  --blob = textblob.TextBlob{tilemap = tiles}
end


local f = 0

function update()
  -- async.update()
  -- console:update()
  -- blob:update()
  reactor:rasterize(false)
  myapp:update()
  if writing_frames then
    local fn = string.format("frames/frame_%04d.png", f)
    gfx.save_screenshot(fn)
  end
  f = f + 1
end
