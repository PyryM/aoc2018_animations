-- tilemap.t
--
-- render a map of tiles

local class = require("class")
local gfx = require("gfx")
local ecs = require("ecs")
local graphics = require("graphics")
local Vector = require("math").Vector
local m = {}

function m.grid_tile_data(opts)
  local position, texcoord0, texcoord1 = {}, {}, {}
  local indices = {}

  local function add_tile(x, y, w, h, data_u, data_v)
    local startidx = #position
    table.insert(position, Vector(x, y))
    table.insert(position, Vector(x+w, y))
    table.insert(position, Vector(x+w, y+h))
    table.insert(position, Vector(x, y+h))
    table.insert(texcoord1, Vector(0,1))
    table.insert(texcoord1, Vector(1,1))
    table.insert(texcoord1, Vector(1,0))
    table.insert(texcoord1, Vector(0,0))
    table.insert(texcoord0, Vector(data_u, data_v))
    table.insert(texcoord0, Vector(data_u, data_v))
    table.insert(texcoord0, Vector(data_u, data_v))
    table.insert(texcoord0, Vector(data_u, data_v))
    table.insert(indices, {startidx, startidx+1, startidx+2})
    table.insert(indices, {startidx+2, startidx+3, startidx})
  end

  local tilew, tileh = opts.tilew, opts.tileh
  if not (tilew and tileh) then
    tilew = opts.width / opts.cols
    tileh = opts.height / opts.rows
  end 
  local x0 = opts.x0 or 0
  local y0 = opts.y0 or (opts.rows * tileh)
  for row = 0, opts.rows - 1 do
    for col = 0, opts.cols - 1 do
      local x = x0 + col*tilew
      local y = y0 - (row+1)*tileh
      add_tile(x, y, tilew, tileh, col, row)
    end
  end

  return {
    indices = indices, attributes = {
      position = position, texcoord0 = texcoord0, texcoord1 = texcoord1
    }
  }
end

local TilemapComponent = graphics.RenderComponent:extend("TilemapComponent")
m.TilemapComponent = TilemapComponent

function TilemapComponent:init(options)
  local opts = options or {}
  self.mount_name = "tilemap"
  self.font_cols = options.font_cols
  self.font_rows = options.font_rows
  self.font_offset = options.font_offset
  self.geo = self:_create_geo(opts)
  self.mat = self:_create_material(opts)
  self.tags = gfx.tagset{compiled = true}
  self.tags:extend(options.tags or {})
  self.drawcall = gfx.Drawcall(self.geo, self.mat)
end

function TilemapComponent:_create_geo(opts)
  if opts.geo then return opts.geo end
  local vinfo = opts.vertexinfo or gfx.create_basic_vertex_type{
    "position", "texcoord0", "texcoord1"
  }
  local data = opts.geo_data or m.grid_tile_data(opts)
  local geo = gfx.StaticGeometry():from_data(data, vinfo)
  return geo
end

local TilemapMaterial = gfx.define_base_material{
  name = "TilemapMaterial",
  uniforms = {
    s_texIndex = {kind = 'tex', sampler = 0},
    s_texColormap = {kind = 'tex', sampler = 1},
    s_texCharmap = {kind = 'tex', sampler = 2},
    u_tileParams = 'vec', u_baseColor = 'vec'
  },
  state = {cull = false},
  program = {"vs_tilemap", "fs_tilemap"}
}

function TilemapComponent:_create_material(opts)
  local mat = opts.material
  if not mat then
    mat = TilemapMaterial()
    self.index_tex = opts.index_tex 
    if not self.index_tex then
      self.index_tex = gfx.Texture2d{width = opts.cols, height = opts.rows, 
                                    dynamic = true, allocate = true,
                                    format = gfx.TEX_RGBA8}
      self.index_tex:commit()
    end
    mat.uniforms.s_texIndex:set(self.index_tex)
    mat.uniforms.s_texColormap:set(opts.colormap)
    mat.uniforms.s_texCharmap:set(opts.charmap)
    mat.uniforms.u_baseColor:set(1.0, 1.0, 1.0, 1.0)
    mat.uniforms.u_tileParams:set(1.0 / (self.font_cols or 32.0), 
                                  1.0 / (self.font_rows or 4.0))
  end

  return mat
end

m.Tilemap = ecs.promote("Tilemap", TilemapComponent)

return m