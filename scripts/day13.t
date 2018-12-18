-- day13.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local tilemap = require("tilemap.t")
local async = require("async")
local class = require("class")
local orbitcam = require("gui/orbitcam.t")
local sutils = require("utils/stringutils.t")
local traceapp = require("traceapp.t")
local pbr = require("material/pbr.t")
local sprite = require("sprite.t")
local colors = require("colors.t")
local math = require("math")
local ecs = require("ecs")

local ROWS, COLS = 150, 150
local writing_frames = false

local Cart = class("Cart")

local TrackMap = class("TrackMap")
function TrackMap:init(options)
  self.tilemap = options.tilemap
end

function TrackMap:get_carts()
  return self.carts
end

function TrackMap:get_tile(tx, ty)
  if tx < 0 or ty < 0 or 
    tx >= self.data_width or ty >= self.data_height then
    return 0
  end
  return self.data[ty*self.data_height + tx]
end

function TrackMap:tick_carts()
  local order = {}
  for idx, cart in ipairs(self.carts) do
    order[idx] = {cart:position_index(), cart}
  end
  table.sort(order, function(a, b) return a[1] < b[1] end)
  local live = {}
  for _, cart in ipairs(order) do
    if cart[2]:tick() then
      table.insert(live, cart[2])
    end
  end
  self.carts = live
  if #live == 1 then
    print("Final cart: ", live[1].x, live[1].y)
    truss.error("Done.")
  end
end

function TrackMap:set_input(input)
  self.carts = {}
  self.occupancy = {}
  self.data_width, self.data_height = 150, 150
  self.data_stride = self.data_width
  self.data = terralib.new(uint8[(self.data_height+1) * self.data_stride])
  local data, dw, dh = self.data, self.data_width, self.data_height

  local lines = sutils.split_lines(input)
  local tiles = {
    [' '] = 0,
    ['+'] = 3,
    ['|'] = 2,
    ['-'] = 1,
    ['/'] = 20,
    ['\\'] = 20,
    ['v'] = 2,
    ['^'] = 2,
    ['<'] = 1,
    ['>'] = 1
  }
  local cart_chars = {
    ['<'] = 0,
    ['^'] = 1,
    ['>'] = 2,
    ['v'] = 3
  }
  for y, line in ipairs(lines) do
    if (y-1) >= dh then break end
    for x = 1, #line do
      local c = line:sub(x, x)
      if cart_chars[c] then
        table.insert(self.carts, Cart{
          map = self, occupancy = self.occupancy,
          direction = cart_chars[c], x = x-1, y = y-1
        })
      end
      data[(y-1)*dw + (x-1)] = tiles[c] or 7
    end
  end

  -- local function get_tile(tx, ty)
  --   if tx < 0 or ty < 0 or tx >= dw or ty >= dh then
  --     return 0
  --   end
  --   return data[ty*dh + tx]
  -- end

  -- fix curves
  local neighbors = {{1, -1, 0, 1}, {2, 1, 0, 1}, {4, 0, -1, 2}, {8, 0, 1, 2}}
  local curves = {[5] = 4, [6] = 5, [9] = 7, [10] = 6}

  for y = 0, dh do
    for x = 0, dw do
      if self:get_tile(x, y) == 20 then
        local curveidx = 0
        for _, n in ipairs(neighbors) do
          local ii, dx, dy, conn = unpack(n)
          local nt = self:get_tile(x + dx, y + dy)
          if nt == 3 or nt == conn then
            curveidx = curveidx + ii
          end
        end
        data[y*dw + x] = curves[curveidx] or 0
      end
    end
  end

  return self.carts
end

function TrackMap:load_input(fn)
  return self:set_input(truss.load_string_from_file(fn))
end

function TrackMap:rasterize()
  local tm = self.tilemap
  if tm.tilemap then
    tm = tm.tilemap
  end
  local target_tex = tm.index_tex
  local buffer = target_tex.cdata
  local w, h = target_tex.width, target_tex.height
  local maxchars = w*h

  local pos = 0
  for y = 0, h-1 do
    for x = 0, w-1 do
      local dval = 0
      if y < self.data_height and x < self.data_width then
        local dpos = y*self.data_stride + x
        dval = self.data[dpos]
      end
      buffer[pos] = dval % 4
      buffer[pos+1] = math.floor(dval / 4)
      buffer[pos+2] = 0
      buffer[pos+3] = 0
      pos = pos + 4
    end
  end
  target_tex:update()
end

local next_cart = 1
function Cart:init(options)
  self.intersection_index = 0
  self.occupancy = options.occupancy
  self.direction = options.direction
  self.map = options.map
  self.x = options.x
  self.y = options.y
  self.idx = next_cart
  next_cart = next_cart + 1
end

function Cart:position_index()
  return self.y * 1000 + self.x
end

local DIRECTIONS = {{-1,0}, {0,-1}, {1,0}, {0,1}}
local CART_DIRS = {-1, 0, 1}
local CURVES = {
  [4] = {[2] = {1,-1}, [3] = {0,1}},
  [5] = {[3] = {2,-1}, [0] = {1,1}},
  [6] = {[1] = {2, 1}, [0] = {3,-1}},
  [7] = {[1] = {0,-1}, [2] = {3,1}}
}
local STRAIGHTS = {
  [1] = true, [2] = true
}
local INTERSECTION = 3

local function apply_curve(direction, curve)
  return unpack(CURVES[curve][direction])
end

function Cart:tick()
  if self.dead then return false end

  -- Each time a cart has the option to turn (by arriving at any intersection), 
  -- it turns left the first time, goes straight the second time, turns right 
  -- the third time, and then repeats those directions starting again with
  -- left the fourth time, straight the fifth time, and so on.
  self.prev_x = self.x
  self.prev_y = self.y
  self.prev_direction = self.direction
  self.delta_direction = 0

  local occupancy_index = self:position_index()
  self.occupancy[occupancy_index] = nil
  local tiletype = self.map:get_tile(self.x, self.y)
  if tiletype == INTERSECTION then
    local ddir = CART_DIRS[self.intersection_index + 1]
    self.delta_direction = ddir
    self.direction = ((self.direction + ddir) + 4) % 4
    self.intersection_index = (self.intersection_index + 1) % (#CART_DIRS)
  elseif CURVES[tiletype] then
    self.direction, self.delta_direction = apply_curve(self.direction, tiletype)
  elseif not STRAIGHTS[tiletype] then
    truss.error("Cart hit unexpected tiletype: " .. tiletype)
  end
  local dx, dy = unpack(DIRECTIONS[self.direction+1])
  self.x = self.x + dx
  self.y = self.y + dy
  if self.occupancy[occupancy_index] then
    print("Collision: ", self.idx, self.x, self.y)
    self.dead = true
    self.occupancy[occupancy_index].dead = true
    self.occupancy[occupancy_index] = nil
  else
    self.occupancy[occupancy_index] = self
  end
  return not self.dead
end

local function get_world_pos(tile_x, tile_y)
  fx, fy = (tile_x+0.5) / COLS, (tile_y+0.5) / ROWS
  return fx * 2.0 - 1.0, 0.002, fy * 2.0 - 1.0
end

local function get_world_euler(tile_direction)
  return {
    x = -math.pi/2.0, 
    y = -0.5*(tile_direction-1)*math.pi, 
    z = 0
  }
end

function Cart:animate(nframes)
  local entity = self.entity
  if self.dead then 
    if not self.flickered then
      self.flickered = true
      async.run(function()
        for f = 1, 10 do
          entity.visible = (f % 2) == 0
          async.await_frames(1)
        end
        entity.visible = false
      end)
    end
    return
  end

  if (nframes or 0) < 1 then
    entity.position:set(get_world_pos(self.x, self.y))
    entity.quaternion:euler(get_world_euler(self.direction), 'ZYX')
    entity:update_matrix()
    return true
  end

  return async.run(function()
    local prev = math.Vector(self.prev_x, self.prev_y, self.prev_direction)
    local next = math.Vector(self.x, self.y, self.prev_direction + self.delta_direction)
    local cur = math.Vector()
    if self.delta_direction ~= 0 then
      for f = 1, nframes/2 do
        cur:lincomb(next, prev, 2*f/nframes)
        entity.quaternion:euler(get_world_euler(cur.elem.z), 'ZYX')
        entity:update_matrix()
        async.await_frames(1)
      end
      nframes = nframes / 2
    end
    for f = 1, nframes do
      cur:lincomb(next, prev, f/nframes)
      entity.position:set(get_world_pos(cur.elem.x, cur.elem.y))
      entity:update_matrix()
      if self.follower then
        self.follower.position:copy(entity.position)
        self.follower:update_matrix()
      end
      async.await_frames(1)
    end
  end)
end

function init()
  local width, height = 1024, 1024
  myapp = traceapp.TraceApp{
    width = width, height = height, title = "day13", msaa = true,
    clear_color = 0xccccccff, stats = false
  }
  myapp.camera:add_component(orbitcam.OrbitControl{
    min_rad = 0.09, max_rad = 4
  })
  myapp.camera.orbit_control:set(math.pi/4.0, -math.pi/2.0 + 0.6, 0.8)

  local camroot = myapp.scene:create_child(ecs.Entity3d, "camroot")
  camroot.position:set(0.4, 0.0, 0.4)
  camroot:update_matrix()
  myapp.camera:set_parent(camroot)

  tile_tex = gfx.Texture("textures/day13_tiles.png", {--min = 'point', mag = 'point', 
                                                  u = 'clamp', v = 'clamp'})
  colormap_tex = gfx.Texture("textures/cga.png", {min = 'point', mag = 'point', 
                                                  u = 'clamp', v = 'clamp'})

  tiles = myapp.scene:create_child(tilemap.Tilemap, "tilemap", {
    rows = ROWS, cols = COLS,
    colormap = colormap_tex, charmap = tile_tex,
    font_cols = 4, font_rows = 2, font_offset = 0, margin = 0.03,
    width = 2.0, height = 2.0, program = {"vs_tilemap", "fs_tilemap_color"}
  })
  tiles.quaternion:euler{x = -math.pi/2, y = 0, z = 0}
  tiles.position:set(-1, 0.0, 1)
  tiles:update_matrix()
  tiles.tilemap.tags.lightpass = true

  local debugmat = pbr.FacetedPBRMaterial{
    diffuse = {0.5, 0.5, 0.5, 1.0},
    tint = {0.001, 0.001, 0.001, 1.0},
    roughness = 0.7
  }

  local planegeo = geometry.plane_geo{width = 10.0, height = 10.0}
  local lightmat = myapp:get_trace_material()
  print(lightmat)
  lightplane = myapp.scene:create_child(graphics.Mesh, "lightplane", planegeo, lightmat)
  lightplane.quaternion:euler{x = -math.pi/2.0, y = 0, z = 0}
  lightplane.position:set(0, -0.005, 0)
  lightplane:update_matrix()

  attrib_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "attrib", {
    x = width - 5, y = height - 4, color = colors.to_float(colors.corn), text = "AoC 13 [mtknn]", fontsize = 48,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })

  trackmap = TrackMap{tilemap = tiles}
  local carts = trackmap:load_input("text/day13_input.txt")
  trackmap:rasterize()

  local cartex = gfx.Texture("textures/day13_cart.png")

  for idx, cart in ipairs(carts) do
    print(idx, cart.x, cart.y)
    local carsprite = myapp.scene:create_child(ecs.Entity3d, "cart")
    local color = colors.to_float(colors.corn)
    for i = 1, 1 do
      local layer = carsprite:create_child(sprite.Sprite, "layer", {
        color = color,
        texture = cartex, sprite_width = 256, sprite_height = 256, width = 256, height = 256
      })
      layer.sprite.tags.lightpass = true
    end
    carsprite.scale:set(0.03, 0.03, 0.03)
    carsprite.position:set(0.0, 0.002 + math.random()*0.001, 0.0)
    carsprite.quaternion:euler({x = -math.pi/2.0, y = 0.5, z = 0}, 'ZYX')
    carsprite:update_matrix()
    cart.entity = carsprite
    cart:animate()
  end

  local watch_cart = carts[9]
  watch_cart.follower = camroot

  async.run(function()
    while true do
      trackmap:tick_carts()
      for _, cart in ipairs(carts) do
        cart:animate(10)
      end
      async.await_frames(11)
    end
  end):next(print, print)
end

local f = 0

function update()
  myapp:update()
  if writing_frames then
    local fn = string.format("frames/frame_%04d.png", f)
    gfx.save_screenshot(fn)
  end
  f = f + 1
end
