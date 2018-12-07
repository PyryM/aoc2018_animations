-- day6.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local flat = require("material/flat.t")
local pbr = require("material/pbr.t")
local math = require("math")
local orbitcam = require("gui/orbitcam.t")
local ecs = require("ecs")

local width, height = 512, 512

local function PyramidGeo(s)
  local position = {
    math.Vector(0, 0, 0),
    math.Vector(s, 0, -s),
    math.Vector(0, s, -s),
    math.Vector(-s, 0, -s),
    math.Vector(0, -s, -s)
  }
  local indices = {
    {1, 2, 0}, 
    {2, 3, 0},
    {3, 4, 0},
    {4, 1, 0}
  }
  local data = {
    indices = indices,
    attributes = {position = position}
  }
  return geometry.to_basic_geo(data, "pyramid", {})
end

local function pyramid_mover(target, n, z)
  local z0 = target.position.elem.z
  local dz = (z - z0) / n
  target:update_matrix()
  for f = 1, n do
    target.position.elem.z = z0 + f*dz
    target:update_matrix()
    async.await_frames(1)
  end
end

function set_lights(threeness)
  local p = myapp.pipeline
  local Vector = math.Vector
  p.globals.u_lightDir:set_multiple({
      Vector( 0.0,  1.0,  0.0),
      Vector(-1.0,  1.0,  0.0),
      Vector( 0.0, 1.0,  1.0),
      Vector( 0.0, 1.0, -1.0)})
  local a = threeness
  p.globals.u_lightRgb:set_multiple({
      Vector(1.0, 1.0, 1.0),
      Vector(0.5*a, 0.5*a, 0.5*a),
      Vector(0.8*a, 0.6*a, 0.1*a),
      Vector(0.2*a, 0.2*a, 0.5*a)})
end

function init()
  myapp = app.App{
    width = width, height = height, title = "day6", msaa = true,
    clear_color = 0x000000ff, stats = false
  }

  myapp.camera:make_orthographic(-1.0, 1.0, -1.0, 1.0, 0.01, 10.0)
  myapp.camera.position:set(0.0, 2.0, 0.0)
  myapp.camera:update_matrix()
  myapp.camera:add_component(orbitcam.OrbitControl{
    min_rad = 1, max_rad = 4
  })

  local stuffroot = myapp.scene:create_child(ecs.Entity3d, "stuffroot")
  stuffroot.quaternion:euler({x = -math.pi/2, y = 0, z = 0})
  stuffroot:update_matrix()

  local plane_geo = require("geometry").plane_geo{
    width = 40.0, height = 40.0, segments = 5
  }
  local plane_mat = flat.FlatMaterial{color = {0.1, 0.1, 0.1, 1}}
  local plane = stuffroot:create_child(graphics.Mesh, "plane", plane_geo, plane_mat)

  local pyramid_geo = PyramidGeo(2)
  math.randomseed(os.time())

  async.run(function()
    local pyramids = {}
    local promises = {}
    set_lights(0.0)
    myapp.camera.orbit_control:set(math.pi/2, -math.pi/2.0, 2.0)

    for i = 1, 50 do
      local x = (math.random() - 0.5) * 1.4
      local y = (math.random() - 0.5) * 1.4
      local rcolor = {math.random(), math.random(), math.random(), 1}
      --local pyramid_mat = flat.FlatMaterial{color = rcolor}
      local pyramid_mat = pbr.FacetedPBRMaterial{diffuse = rcolor, tint = {0.001, 0.001, 0.001}, roughness = 0.7}
      local pyramid = stuffroot:create_child(graphics.Mesh, "pyramid", pyramid_geo, pyramid_mat)
      pyramid.position:set(x, y, 0.0)
      pyramid:update_matrix()
      pyramids[i] = pyramid
      promises[i] = async.run(pyramid_mover, pyramid, 200, 0.5)
    end
    async.await(async.all(promises))
    for f = 1, 120 do
      myapp.camera.orbit_control:move_phi(0.7)
      myapp.camera.orbit_control:move_theta(0.2)
      set_lights(0.0 + 0.2 * f / 120)
      async.await_frames(1)
    end
    for f = 1, 120 do
      myapp.camera.orbit_control:move_theta(0.2)
      async.await_frames(1)
    end
    promises = {}
    for idx, pyramid in ipairs(pyramids) do
      promises[idx] = async.run(pyramid_mover, pyramid, 150, 0.0)
    end
    while true do
      myapp.camera.orbit_control:move_theta(0.2)
      async.await_frames(1)
    end
  end)

  attrib_label = myapp.scene:create_child(require("textlabel.t").TextLabel, "attrib", {
    x = width - 4, y = height - 4, color = {0.2, 0.2, 0.2, 1.0}, text = "AoC Day 6 [mtknn]", fontsize = 24,
    align = "right", shadow = {0.0, 0.0, 0.0, 1.0}
  })
end

local writing_frames = true
local f = 0

function update()
  myapp:update()
  if writing_frames then
    local fn = string.format("frames/frame_%04d.png", f)
    gfx.save_screenshot(fn)
  end
  f = f + 1
end
