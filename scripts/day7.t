-- day4.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local flat = require("material/flat.t")
local ecs = require("ecs")

local width, height = 512, 512
local f = 0

local TimelineComp = graphics.NanoVGComponent:extend("TimelineComp")
function TimelineComp:init(options)
  TimelineComp.super.init(self)
  self.n_cols = options.cols
  self.max_steps = options.max_steps or 1040
  self.width = options.width or 300
  self.height = options.height or 1024
  self.cur_step = 0
  self.columns = {}
  for i = 1, self.n_cols do
    self.columns[i] = {events = {}}
  end
end

function TimelineComp:step()
  self.cur_step = self.cur_step + 1
end

function TimelineComp:push_event(col, name, color, start_step, end_step)
  local evt = {
    color = color or {255, 255, 255, 255}, name = name,
    start_step = start_step, end_step = end_step or 4000
  }
  table.insert(self.columns[col].events, evt)
  return evt
end

function TimelineComp:draw_col(ctx, col, x, y, w, h)
  local column = self.columns[col]

  local dy_df = h / self.max_steps
  for _, evt in ipairs(self.columns[col].events) do
    if evt.start_step >= self.cur_step then
      break
    end
    local evt_top = y + (dy_df * evt.start_step)
    local end_step = math.min(evt.end_step or 4000, self.cur_step)
    local evt_height = dy_df * (end_step - evt.start_step)
    ctx:BeginPath()
    ctx:Rect(x, evt_top, w, evt_height)
    ctx:FillColor(ctx:RGBA(unpack(evt.color)))
    ctx:Fill()
    ctx:Scissor(x, evt_top, w, evt_height)
    ctx:FillColor(ctx:RGBA(unpack(evt.text_color or {0, 0, 0, 255})))
    ctx:Text(x + w/2, evt_top + evt_height, evt.name, nil)
    ctx:ResetScissor()
  end
end

function TimelineComp:nvg_draw(ctx)
  ctx:load_font("font/FiraMono-Regular.ttf", "sans")
  ctx:FontFace("sans")
  ctx:TextAlign(ctx.ALIGN_CENTER + ctx.ALIGN_BOTTOM)
  ctx:FontSize(self.fontsize or 30)

  local x = 10
  local dx = self.width / self.n_cols
  for idx = 1, self.n_cols do
    self:draw_col(ctx, idx, x, 10, dx, self.height)
    x = x + dx
  end

  local y = 10 + (self.height / self.max_steps) * self.cur_step
  ctx:BeginPath()
  ctx:MoveTo(10, y)
  ctx:LineTo(10 + self.width, y)
  ctx:StrokeWidth(3.0)
  ctx:StrokeColor(ctx:RGBA(255, 255, 255, 255))
  ctx:Stroke()

  ctx:FontSize(24)
  ctx:TextAlign(ctx.ALIGN_LEFT + ctx.ALIGN_MIDDLE)
  ctx:FillColor(ctx:RGBA(255, 255, 255, 255))
  ctx:Text(10 + self.width, y, tostring(self.cur_step), nil)
end

function TimelineComp:async_twiddle(month, day, minute, val, speed)
  speed = speed or 2
  local data = self.months[month][day].minutes
  return async.run(function()
    for t = minute, 59 do
      data[t] = data[t] + val
      if t % speed == 0 then
        async.await_frames(1)
      end
    end
  end)
end

function TimelineComp:async_set_guard(month, day, idx, nrollover)
  return async.run(function()
    self.months[month][day].guard = idx
    for i = 1, nrollover do
      if (i - 1) % 2 == 0 then async.await_frames(1) end
      day = day + 1
      if day > 31 then
        day = 1
        month = month + 1
      end
      if self.months[month][day].guard >= 0 then 
        return 
      end
      self.months[month][day].guard = idx
    end
  end)
end

local Timeline = ecs.promote("Timeline", TimelineComp)

local function twiddletest()
  print("queueing events")
  for c = 1, 5 do
    local t = math.random(0, 100)
    for _ = 1, 10 do
      local dt = math.random(61, 61+26)
      if math.random() < 0.5 then
        timeline:push_event(c, 'X', {255,255,255,255}, t, t+dt)
      end
      t = t + dt
    end
  end
  print("done?")

  for f = 1, 1024 do
    timeline:step()
    async.await_frames(1)
  end
end

function init()
  myapp = app.App{
    width = width, height = height, title = "day7", msaa = true,
    clear_color = 0x000000ff, stats = false
  }

  myapp.camera:make_orthographic(-0.5, 0.5, -0.5, 0.5, 0.1, 30.0)
  myapp.camera.position:set(0.0, 0.0, 1.0)
  myapp.camera:update_matrix()

  timeline = myapp.scene:create_child(Timeline, "timeline", {
    width = width / 4,
    height = height * 0.9,
    cols = 5
  })

  -- graph = myapp.scene:create_child(Graph, 'graph', {
  --   -- eh?
  -- })

  async.run(twiddletest)
end

local writing_frames = false

function update()
  myapp:update()
  if writing_frames then
    local fn = string.format("frames/frame_%04d.png", f)
    gfx.save_screenshot(fn)
  end
  f = f + 1
end
