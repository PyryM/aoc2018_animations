-- traceapp.t
--

local class = require("class")
local graphics = require("graphics")
local math = require("math")
local gfx = require("gfx")
local app = require("app/app.t")
local pbr = require("material/pbr.t")
local m = {}

local TraceApp = app.App:extend("TraceApp")
m.TraceApp = TraceApp

function TraceApp:init(options)
  self.light_resolution = options.light_resolution or 2048
  TraceApp.super.init(self, options)

  self.light_cam = self.ECS.scene:create_child(graphics.Camera, "lightcam", {
    tag = "lightcam"
  })
  self.light_cam:make_orthographic(-1.0, 1.0, -1.0, 1.0, 0.01, 10.0)
  self.light_cam.quaternion:euler{x = -math.pi/2.0, y = 0.0, z = 0.0}
  self.light_cam.position:set(0.0, 1.0, 0.0)
  self.light_cam:update_matrix()
end

function TraceApp:init_pipeline()
  local Vector = math.Vector
  local p = graphics.Pipeline({verbose = true})

  self.noisemap = gfx.Texture("textures/noise.png")
  self.light_target = gfx.ColorDepthTarget{
    height = self.light_resolution,
    width  = self.light_resolution
  }

  p:add_stage(graphics.Stage{
    name = "light",
    clear = {color = 0x00000000, depth = 1.0},
    globals = p.globals,
    render_target = self.light_target,
    filter = function(tags)
      return tags.is_camera or tags.lightpass
    end,
    render_ops = {graphics.DrawOp(), graphics.CameraControlOp("lightcam")}
  })

  p:add_stage(graphics.Stage{
    name = "forward",
    clear = {color = 0xaaaaaaff, depth = 1.0},
    globals = p.globals,
    render_ops = {graphics.DrawOp(), graphics.CameraControlOp()}
  })
  p.globals.u_lightDir:set_multiple({
      Vector( 1.0,  1.0,  0.0),
      Vector(-1.0,  1.0,  0.0),
      Vector( 0.0, -1.0,  1.0),
      Vector( 0.0, -1.0, -1.0)})
  p.globals.u_lightRgb:set_multiple({
      Vector(0.8, 0.8, 0.8),
      Vector(1.0, 1.0, 1.0),
      Vector(0.1, 0.1, 0.1),
      Vector(0.1, 0.1, 0.1)})
  self.nvg_stage = p:add_stage(graphics.NanoVGStage{
    name = "nanovg",
    clear = false
  })

  self.pipeline = p
  self.ECS.systems.render:set_pipeline(p)
end

m.TraceMaterial = gfx.define_base_material{
  name = "TraceMaterial",
  uniforms = {
    s_lightMap = {kind = 'tex', sampler = 0},
    s_noiseMap = {kind = 'tex', sampler = 1},
    u_lightHeight = 'vec', -- x: light height
    u_mapScale = 'vec',    -- uv = world.xz * mapScale.xy + mapScale.zw
    u_time = 'vec',
    u_ambient = 'vec'
  },
  state = {},
  program = {"vs_raytrace_plane", "fs_raytrace_plane"},
}

function TraceApp:get_trace_material()
  local ret = m.TraceMaterial()
  ret.uniforms.s_lightMap:set(self.light_target)
  ret.uniforms.s_noiseMap:set(self.noisemap)
  ret.uniforms.u_lightHeight:set(0.005)
  ret.uniforms.u_mapScale:set(0.5, 0.5, 0.5, 0.5)
  ret.uniforms.u_ambient:set(0.5, 0.5, 0.5, 1.0)
  return ret
end

return m