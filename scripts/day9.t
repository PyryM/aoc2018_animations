-- day9.t
local class = require("class")

local struct Ring_t {
  prevs: &uint32;
  nexts: &uint32;
  vals: &int64;
  capacity: uint32;
  cursor: uint32;
  next_slot: uint32;
  n_items: uint32;
  scores: &int64;
  n_players: uint32;
  cur_player: uint32;
}

terra Ring_t:reset(initial_val: int64)
  self.prevs[0] = 0
  self.nexts[0] = 0
  self.vals[0] = initial_val
  self.cursor = 0
  self.next_slot = 1
  self.n_items = 1
  for i = 0, self.n_players do
    self.scores[i] = 0
  end
  self.cur_player = 0
end

terra Ring_t:move_left(n: int32)
  for _ = 0, n do
    self.cursor = self.prevs[self.cursor]
  end
end

terra Ring_t:move_right(n: int32)
  for _ = 0, n do
    self.cursor = self.nexts[self.cursor]
  end
end

terra Ring_t:insert(val: int64)
  var slotidx = self.next_slot
  self.next_slot = self.next_slot + 1
  self.vals[slotidx] = val
  var after_cursor = self.nexts[self.cursor]
  self.nexts[self.cursor] = slotidx
  self.prevs[after_cursor] = slotidx
  self.nexts[slotidx] = after_cursor
  self.prevs[slotidx] = self.cursor
  self.cursor = slotidx
  self.n_items = self.n_items + 1
end

terra Ring_t:delete(): int64
  -- don't worry about what happens if the list is at one item
  var v = self.vals[self.cursor]
  var cur_prev = self.prevs[self.cursor]
  var cur_next = self.nexts[self.cursor]
  self.nexts[cur_prev] = cur_next
  self.prevs[cur_next] = cur_prev
  self.cursor = cur_next
  self.n_items = self.n_items - 1
  return v
end

terra Ring_t:do_turn(marble_id: int64)
  var cur_player = self.cur_player
  if marble_id % 23 == 0 then
    self.scores[cur_player] = self.scores[cur_player] + marble_id
    self:move_left(7)
    self.scores[cur_player] = self.scores[cur_player] + self:delete()
  else
    self:move_right(1)
    self:insert(marble_id)
  end
  self.cur_player = (cur_player + 1) % self.n_players
end

terra Ring_t:run_everything(max_marble: int64)
  self.cur_player = 0
  for idx = 1, (max_marble + 1) do
    self:do_turn(idx)
  end
end

local Ring = class("Ring")
function Ring:init(capacity, initial_val, n_players)
  self.prevs = terralib.new(uint32[capacity])
  self.nexts = terralib.new(uint32[capacity])
  self.vals = terralib.new(int64[capacity])
  self.scores = terralib.new(int64[n_players])
  self.n_players = n_players

  self.state = terralib.new(Ring_t)
  self.state.prevs = self.prevs
  self.state.nexts = self.nexts
  self.state.vals = self.vals
  self.state.capacity = capacity
  self.state.scores = self.scores
  self.state.n_players = n_players
  
  self.state:reset(initial_val or 0)
end

function Ring:dump()
  local parts = {}
  local pos = self.state.cursor
  for i = 1, self.state.n_items do
    parts[i] = tostring(tonumber(self.state.vals[pos]))
    pos = self.state.nexts[pos]
  end
  return table.concat(parts, " ")
end

function init()
  print("Starting?")
  local np = 452
  local lastm = 70784*100
  local ring = Ring(lastm+1, 0, np)
  print("Made ring?")
  -- for marble = 1, 25 do
  --   ring.state:do_turn(marble)
  --   print(ring:dump())
  -- end
  local t0 = truss.tic()
  ring.state:run_everything(lastm)
  print("Took " .. truss.toc(t0) .. "s")
  --print(ring:dump())
  local maxv = 0
  for p = 0, ring.state.n_players - 1 do
    --print(p+1, ring.state.scores[p])
    if ring.state.scores[p] > maxv then
      maxv = ring.state.scores[p]
    end
  end
  print("Maxv: ", maxv)
  truss.quit()
end

function update()
end