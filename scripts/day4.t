-- day4.t

local app = require("app/app.t")
local geometry = require("geometry")
local gfx = require("gfx")
local graphics = require("graphics")
local async = require("async")
local flat = require("material/flat.t")
local ecs = require("ecs")

local width, height = 1280, 720
local f = 0

local CalendarComp = graphics.NanoVGComponent:extend("CalendarComp")
function CalendarComp:init(options)
  CalendarComp.super.init(self)
  self.fontsize = options.fontsize or 12
  self:clear_months()
end

function CalendarComp:clear_months()
  self.months = {}
  for i = 1, 12 do
    self.months[i] = {}
    for j = 1, 31 do
      local minutes = {}
      for mm = 0, 60 do minutes[mm] = 0 end
      self.months[i][j] = {guard = -1, minutes = minutes}
    end
  end
end

function CalendarComp:draw_month(month, ctx, x, y, w, h)
  local dy = math.floor(h / 32)
  ctx:Text(x, y, string.format("%02d", month), nil)
  local dm = (w - 60) / 60
  
  for day = 1, 31 do
    local cy = y + dy*day
    ctx:Text(x, cy, string.format("%02d", day), nil)
    local gtext = "____"
    if self.months[month][day].guard >= 0 then
      gtext = string.format("%04d", self.months[month][day].guard)
    end
    ctx:Text(x+18, cy, gtext, nil)
    cy = cy + dy/2

    ctx:BeginPath()
    ctx:MoveTo(x + 50, cy)
    ctx:LineTo(x + w - 10, cy)
    ctx:StrokeColor(ctx:RGBA(100,100,100,255))
    ctx:StrokeWidth(1.0)
    ctx:Stroke()

    ctx:BeginPath()
    for minute = 0, 59 do
      local delta = self.months[month][day].minutes[minute] / 4.0
      if delta > 0 then
        delta = delta * dy/2
        ctx:MoveTo(x + 50 + minute*dm, cy)
        ctx:LineTo(x + 50 + minute*dm, cy - delta)
      end
    end
    ctx:StrokeColor(ctx:RGBA(255,255,255,255))
    ctx:StrokeWidth(4.5)
    ctx:Stroke()

    ctx:BeginPath()
    for minute = 0, 59 do
      local delta = self.months[month][day].minutes[minute] / 4.0
      if delta < 0 then
        delta = delta * dy/2
        ctx:MoveTo(x + 50 + minute*dm, cy)
        ctx:LineTo(x + 50 + minute*dm, cy - delta)
      end
    end
    ctx:StrokeColor(ctx:RGBA(255,50,50,255))
    ctx:StrokeWidth(4.5)
    ctx:Stroke()

    -- ctx:BeginPath()
    -- for minute = 0, 59 do
    --   local delta = math.cos(minute + f*0.1)*4
    --   if delta >= 0 then
    --     ctx:MoveTo(x + 14 + minute*dm, cy)
    --     ctx:LineTo(x + 14 + minute*dm, cy + delta)
    --   end
    -- end
    -- ctx:StrokeWidth(3.0)
    -- ctx:StrokeColor(ctx:RGBA(255,255,50,255))
    -- ctx:Stroke()
  end
end

function CalendarComp:async_twiddle(month, day, minute, val, speed)
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

function CalendarComp:async_set_guard(month, day, idx, nrollover)
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

function CalendarComp:nvg_draw(ctx)
  ctx:load_font("font/FiraMono-Regular.ttf", "sans")
  ctx:FontFace("sans")
  ctx:FillColor(ctx:RGBA(255, 255, 255, 255))
  ctx:TextAlign(ctx.ALIGN_LEFT + ctx.ALIGN_TOP)
  ctx:FontSize(self.fontsize)
  local month = 2
  local dx = ctx.width/6.5
  local dy = ctx.height/2
  for row = 0, 1 do
    for col = 0, 4 do
      self:draw_month(month, ctx, col * dx + 10, row * dy, dx, dy)
      month = month + 1
    end
  end
end
local Calendar = ecs.promote("Calendar", CalendarComp)

local function run_input(inputname, desc)
  calendar:clear_months()
  local inputs = require(inputname)
  async.await_frames(30)

  local speed = 2
  local accel_max = 10
  local accel = accel_max

  for input_idx, input in ipairs(inputs) do
    accel = accel - 1
    if accel <= 0 and speed < 10 then
      accel = accel_max
      speed = speed + 1
    end
    --{'[1518-02-28 00:00] Guard #1987 begins shift', 2, 28, 0, 0, 'guard', 1987}
    local rawline = input[1]
    local month = input[2]
    local day = input[3]
    local hour = input[4]
    local minute = input[5]
    local action = input[6]
    local val = input[7]
    textbox:push_line(rawline)
    if action == 'set' then
      if false and speed < 4 then
        async.await(calendar:async_twiddle(month, day, minute, -val, speed))
      else
        calendar:async_twiddle(month, day, minute, -val, 1)
      end
      if input_idx % 2 == 0 then
        async.await_frames(1)
      end
      --async.await_frames(1)
    elseif action == 'guard' then
      local rollover = 0
      if hour == 23 then
        day = day + 1
        if day > 31 then
          day = 1
          month = month + 1
        end
        rollover = 4
      end
      async.await(calendar:async_set_guard(month, day, val, rollover))
    end
  end
end

local function twiddletest()
  run_input("day4_input_sorted.lua", "(sorted logs)")
  --async.await_frames(60)
  --run_input("day4_input_sorted.lua", "(unsorted logs)")
  textbox:push_line("AoC Day 4 / mtknn")
  textbox:push_line("(sorted input)")
end

function init()
  myapp = app.App{
    width = width, height = height, title = "day4", msaa = true,
    clear_color = 0x000000ff, stats = false
  }

  myapp.camera:make_orthographic(-0.5, 0.5, -0.5, 0.5, 0.1, 30.0)
  myapp.camera.position:set(0.0, 0.0, 1.0)
  myapp.camera:update_matrix()

  calendar = myapp.scene:create_child(Calendar, "calendar", {
    fontsize = 12
  })

  textbox = myapp.scene:create_child(require("textbox.t").TextBox, "textbox", {
    x = 1280 * (5/6.5) + 15, y = 10
  })

  async.run(twiddletest)
end

local writing_frames = true

function update()
  myapp:update()
  if writing_frames then
    local fn = string.format("frames/frame_%04d.png", f)
    gfx.save_screenshot(fn)
  end
  f = f + 1
end
