-- planet/sprite.t
--
-- a basic texture-atlassed sprite

local graphics = require("graphics")
local gfx = require("gfx")
local ecs = require("ecs")
local m = {}

local SpriteMaterial = gfx.define_base_material{
  name = "SpriteMaterial",
  uniforms = {
    u_baseColor = 'vec',
    u_uvParams = 'vec',
    s_texAlbedo = {kind = 'tex', sampler = 0}
  },
  program = {"vs_sprite", "fs_sprite"},
  state = {cull = false}
}
function SpriteMaterial:init(options)
  self:_init()
  self.uniforms.s_texAlbedo:set(options.texture)
  self.uniforms.u_baseColor:set(options.color or {1, 1, 1, 1})
end
m.SpriteMaterial = SpriteMaterial

local SpriteComponent = graphics.MeshComponent:extend("SpriteComponent")
m.SpriteComponent = SpriteComponent

local sprite_geo = nil
function SpriteComponent:init(options)
  if not sprite_geo then
    sprite_geo = require("geometry").plane_geo{
      width = 1.0, height = 1.0, segments = 1
    }
  end
  self.mat = SpriteMaterial(options)
  SpriteComponent.super.init(self, sprite_geo, self.mat)
  self.mount_name = "sprite"
  -- determine sprite uvs
  self._du = options.sprite_width / options.width
  self._dv = options.sprite_height / options.height
  self:set_sprite(options.sprite_index or {0, 0})
end

function SpriteComponent:set_sprite(index)
  self._sprite_index = {index[1], index[2]}
  self.mat.uniforms.u_uvParams:set({
    self._du, self._dv,
    self._du * index[1], 1.0 - (self._dv * (index[2] + 1) )
  })
  return self
end

m.Sprite = ecs.promote("Sprite", SpriteComponent)

local Glitcher = ecs.UpdateComponent:extend("Glitcher")
m.Glitcher = Glitcher

function Glitcher:init()
  Glitcher.super.init(self)
  self.mount_name = "glitcher"
end

function Glitcher:update()
  self.glitch_frames = (self.glitch_frames or 0) - 1
  if self.glitch_frames <= 0 then
    self.ent.quaternion:euler{
      x = math.random()*6.2, y = math.random()*6.2, z = math.random()*6.2
    }
    self.ent:update_matrix()
    self.glitch_frames = math.random(5, 20)
  end
end

return m