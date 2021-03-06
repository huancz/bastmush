-- $Id$
--[[

item details
 - fields
     serial (key)
     keywords
     cname
     name
     type
     level
     worth
     weight
     wearable
     material
     score
     flags
     foundat
     clanitem

    SELECT * FROM itemdetails WHERE serial NOT IN(SELECT serial FROM items)

--]]

require 'tprint'
require 'verify'
require 'pluginhelper'
require 'sqlitedb'
require 'aardutils'
require 'tablefuncs'
require 'copytable'

EQdb = Sqlitedb:subclass()

tableids = {
  levels = 'level_id',
  stats = 'stat_id',
  quests = 'quest_id',
  campaigns = 'cp_id',
  gquests = 'gq_id',
  mobkills = 'mk_id',
  skills = 'sn',
}

--addleveltrainblessing
function EQdb:initialize(args)
  super(self, args)   -- notice call to superclass's constructor
  self.dbname = "\\eq.db"
  self.version = 3
  self.versionfuncs[2] = self.updatenamecolumn
  self.versionfuncs[3] = self.addleadsto
  self:checkversion()
end

function EQdb:turnonpragmas()
  -- PRAGMA foreign_keys = ON;
  self.db:exec("PRAGMA foreign_keys=1;")
  -- PRAGMA journal_mode=WAL
  self.db:exec("PRAGMA journal_mode=DELETE;")
  self.db:exec("PRAGMA synchronous=0;")
end

function EQdb:checkitemstable()
  if not self:checkfortable('items') then
    if self:open('checkitemstable') then
      self.db:exec([[CREATE TABLE items(
        serial INTEGER NOT NULL,
        shortflags TEXT,
        level NUMBER,
        cname TEXT,
        name TEXT,
        type NUMBER,
        containerid TEXT NOT NULL,
        wearslot INTEGER,
        place INTEGER,
        UNIQUE(serial),
        PRIMARY KEY(serial, containerid));
      )]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_containerid ON items(containerid);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_name ON items (name);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_level ON items(level);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_place ON items(place);]])
    end
    self:close('checkitemstable')
  end
end

function EQdb:checkidentifiertable()
  if not self:checkfortable('identifier') then
    if self:open('checkidentifiertable') then
      self.db:exec([[CREATE TABLE identifier(
        serial INTEGER NOT NULL,
        identifier TEXT,
        UNIQUE(identifier),
        PRIMARY KEY(serial, identifier));
      )]])
    end
    self:close('checkidentifiertable')
  end
end

function EQdb:checknotetable()
  if not self:checkfortable('note') then
    if self:open('checknotetable') then
      local retval = self.db:exec([[CREATE TABLE note(
        nid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        note TEXT,
        fromident INTEGER default 0);
      )]])
    end
    self:close('checknotetable')
  end
end

function EQdb:checkitemdetailstable()
  if self:open('checkitemdetailstable') then
    if not self:checkfortable('itemdetails') then
      self.db:exec([[
        CREATE TABLE itemdetails(
          serial INTEGER NOT NULL,
          keywords TEXT,
          cname TEXT,
          name TEXT,
          level NUMBER default 0,
          type NUMBER default 0,
          worth NUMBER default 0,
          weight NUMBER default 0,
          wearable TEXT,
          material NUMBER default 0,
          score NUMBER default 0,
          flags TEXT,
          foundat TEXT,
          fromclan TEXT,
          owner TEXT,
          leadsto TEXT,
          UNIQUE(serial),
          PRIMARY KEY(serial));)]])
    end
    if not self:checkfortable('resistmod') then
      self.db:exec([[
        CREATE TABLE resistmod(
        rid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        type TEXT,
        amount NUMBER default 0,
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('statmod') then
      self.db:exec([[
        CREATE TABLE statmod(
        sid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        type TEXT,
        amount NUMBER default 0,
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('affectmod') then
      self.db:exec([[
        CREATE TABLE affectmod(
        aid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        type TEXT,
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('weapon') then
      self.db:exec([[
        CREATE TABLE weapon(
        wid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        wtype TEXT,
        damtype TEXT,
        special TEXT,
        inflicts TEXT,
        avedam NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('container') then
      self.db:exec([[
        CREATE TABLE container(
        cid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        itemweightpercent NUMBER,
        heaviestitem NUMBER,
        capacity NUMBER,
        holding NUMBER,
        itemsinside NUMBER,
        totalweight NUMBER,
        itemburden NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('skillmod') then
      self.db:exec([[
        CREATE TABLE skillmod(
        skid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        skillnum NUMBER,
        amount NUMBER default 0,
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('spells') then
      self.db:exec([[
        CREATE TABLE spells(
        spid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        uses NUMBER,
        level NUMBER,
        sn1 NUMBER,
        sn2 NUMBER,
        sn3 NUMBER,
        sn4 NUMBER,
        u1 NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('food') then
      self.db:exec([[
        CREATE TABLE food(
        fid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        percent NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('drink') then
      self.db:exec([[
        CREATE TABLE drink(
        did INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        servings NUMBER,
        liquid NUMBER,
        liquidmax NUMBER,
        liquidleft NUMBER,
        thirstpercent NUMBER,
        hungerpercent NUMBER,
        u1 NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('furniture') then
      self.db:exec([[
        CREATE TABLE furniture(
        fuid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        hpregen NUMBER,
        manaregen NUMBER,
        u1 NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('light') then
      self.db:exec([[
        CREATE TABLE light(
        lid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        duration NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    if not self:checkfortable('portal') then
      self.db:exec([[
        CREATE TABLE portal(
        portid INTEGER NOT NULL PRIMARY KEY,
        serial INTEGER NOT NULL,
        uses NUMBER,
        UNIQUE(serial),
        FOREIGN KEY(serial) REFERENCES itemdetails(serial));
      )]])
    end
    self:close('checkitemdetailstable')
  end
end

function EQdb:countitems()
  local count = 0
  self:checkitemstable()
  if self:open('countitems') then
    for a in self.db:rows("SELECT COUNT(*) FROM items") do
      count = a[1]
    end
    self:close('countitems')
  end
  return count
end

function EQdb:getitemdetails(serial)
  timer_start('EQdb:getitemdetails')
  local titem = nil
  self:checkitemdetailstable()
  self:checkidentifiertable()
  self:checknotetable()
  if self:open('getitemdetails') then
    for a in self.db:nrows("SELECT * FROM itemdetails WHERE serial = " .. fixsql(tostring(serial))) do
      titem = a
    end
    if titem then
      for a in self.db:nrows("SELECT * FROM identifier WHERE serial = " .. fixsql(tostring(serial))) do
        if not titem['identifier'] then
          titem['identifier'] = {}
        end
        table.insert(titem['identifier'], a['identifier'])
      end
      for a in self.db:nrows("SELECT * FROM resistmod WHERE serial = " .. fixsql(tostring(serial))) do
        if not titem['resistmod'] then
          titem['resistmod'] = {}
        end
        titem['resistmod'][a.type] = a.amount
      end
      for a in self.db:nrows("SELECT * FROM affectmod WHERE serial = " .. fixsql(tostring(serial))) do
        if not titem['affectmod'] then
          titem['affectmod'] = {}
        end
        table.insert(titem['affectmod'], a.type)
      end
      for a in self.db:nrows("SELECT * FROM spells WHERE serial = " .. fixsql(tostring(serial))) do
        titem['spells'] = a
      end
      for a in self.db:nrows("SELECT * FROM statmod WHERE serial = " .. fixsql(tostring(serial))) do
        if not titem['statmod'] then
          titem['statmod'] = {}
        end
        titem['statmod'][a.type] = a.amount
      end
      for a in self.db:nrows("SELECT * FROM note WHERE serial = " .. fixsql(tostring(serial))) do
        if not titem['note'] then
          titem['note'] = {}
        end
        titem['note'][a.nid] = a.note
      end
      for a in self.db:nrows("SELECT * FROM skillmod WHERE serial = " .. fixsql(tostring(serial))) do
        if not titem['skillmod'] then
          titem['skillmod'] = {}
        end
        titem['skillmod'][a.skillnum] = a.amount
      end
      if tonumber(titem.type) == 1  then
        for a in self.db:nrows("SELECT * FROM light WHERE serial = " .. fixsql(tostring(serial))) do
          titem['light'] = a
        end
      end
      if tonumber(titem.type) == 20  then
        for a in self.db:nrows("SELECT * FROM portal WHERE serial = " .. fixsql(tostring(serial))) do
          titem['portal'] = a
        end
      end
      if tonumber(titem.type) == 5  then
        for a in self.db:nrows("SELECT * FROM weapon WHERE serial = " .. fixsql(tostring(serial))) do
          titem['weapon'] = a
        end
      end
      if tonumber(titem.type) == 9  then
        for a in self.db:nrows("SELECT * FROM furniture WHERE serial = " .. fixsql(tostring(serial))) do
          titem['furniture'] = a
        end
      end
      if tonumber(titem.type) == 11  then
        for a in self.db:nrows("SELECT * FROM container WHERE serial = " .. fixsql(tostring(serial))) do
          titem['container'] = a
        end
        local itemsinside = titem['container']['itemsinside']
        local itemburden = titem['container']['itemburden']
        for a in self.db:rows("SELECT COUNT(*) from items where containerid = " .. fixsql(tostring(serial))) do
          itemsinside = tonumber(a[1])
          itemburden = tonumber(itemsinside) + 1
        end
        titem['container']['itemsinside'] = itemsinside
        titem['container']['itemburden'] = itemburden
      end
      if tonumber(titem.type) == 12  then
        for a in self.db:nrows("SELECT * FROM drink WHERE serial = " .. fixsql(tostring(serial))) do
          titem['drink'] = a
        end
      end
      if tonumber(titem.type) == 14  then
        for a in self.db:nrows("SELECT * FROM food WHERE serial = " .. fixsql(tostring(serial))) do
          titem['food'] = a
        end
      end
    end
    self:close('getitemdetails')
  end
  timer_end('EQdb:getitemdetails')
  --if titem then
  --  tprint(titem)
  --end
  return titem
end

function EQdb:addnote(serial, notes, fromident)
  self:checknotetable()
  if self:open('addnote') then
    if fromident then
      self.db:exec("DELETE from note where fromident = 1 and serial = " .. tostring(serial))
    else
      assert (self.db:exec("BEGIN TRANSACTION"))
    end
    tchanges = self.db:total_changes()
    local stmt = self.db:prepare[[
      INSERT into note VALUES (
        NULL,
        :serial,
        :note,
        :fromident);]]
    for i,v in pairs(notes) do
      local notem = {}
      notem['serial'] = serial
      notem['note'] = v
      if fromident then
        notem['fromident'] = 1
      else
        notem['fromident'] = 0
      end
      stmt:bind_names( notem )
      stmt:step()
      stmt:reset()
    end
    if not fromident then
      assert (self.db:exec("COMMIT"))
    end
    tchanges = self.db:total_changes() - tchanges
    self:close('addnote')
    if tchanges > 0 then
      return true
    end
  end
  return false
end

function EQdb:removenote(notenum)
  timer_start('EQdb:removeidentifier')
  --tprint(item)
  self:checknotetable()
  local tchanges = 0
  if self:open('removenote') then
    tchanges = self.db:total_changes()
    self.db:exec("DELETE FROM note WHERE nid= " .. tostring(notenum) .." and fromident = 0;")
    tchanges = self.db:total_changes() - tchanges
    self:close('removenote')
  end
  timer_end('EQdb:removenote')
  return tchanges
end

function EQdb:adddrink(item)
  timer_start('EQdb:adddrink')
  if item.drink and next(item.drink) then
    local stmt = self.db:prepare[[
      INSERT or REPLACE into drink VALUES (
        NULL,
        :serial,
        :servings,
        :liquid,
        :liquidmax,
        :liquidleft,
        :thirstpercent,
        :hungerpercent,
        :u1);]]
    local drinkm = copytable.deep(item.drink)
    drinkm['serial'] = item.serial
    stmt:bind_names( drinkm )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:adddrink')
end

function EQdb:addlight(item)
  timer_start('EQdb:addlight')
  if item.light and next(item.light) then
    local stmt = self.db:prepare[[
      INSERT or REPLACE into light VALUES (
        NULL,
        :serial,
        :duration);]]
    local lightm = copytable.deep(item.light)
    lightm['serial'] = item.serial
    stmt:bind_names( lightm )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:addlight')
end

function EQdb:addportal(item)
  timer_start('EQdb:addportal')
  if item.portal and next(item.portal) then
    local stmt = self.db:prepare[[
      INSERT or REPLACE into portal VALUES (
        NULL,
        :serial,
        :uses);]]
    local portalm = copytable.deep(item.portal)
    portalm['serial'] = item.serial
    stmt:bind_names( portalm )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:addportal')
end

function EQdb:addfurniture(item)
  timer_start('EQdb:addfurniture')
  if item.furniture and next(item.furniture) then
    local stmt = self.db:prepare[[
      INSERT or REPLACE into furniture VALUES (
        NULL,
        :serial,
        :hpregen,
        :manaregen,
        :u1);]]
    local furniturem = copytable.deep(item.furniture)
    furniturem['serial'] = item.serial
    stmt:bind_names( furniturem )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:addfurniture')
end

function EQdb:addfood(item)
  timer_start('EQdb:addfood')
  if item.food and next(item.food) then
    local stmt = self.db:prepare[[
      INSERT or REPLACE into food VALUES (
        NULL,
        :serial,
        :percent);]]
    local foodm = copytable.deep(item.food)
    foodm['serial'] = item.serial
    stmt:bind_names( foodm )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:addfood')
end

function EQdb:addspells(item)
  timer_start('EQdb:addspell')
  if item.spells and next(item.spells) then
    local stmt = self.db:prepare[[
      INSERT or REPLACE into spells VALUES (
        NULL,
        :serial,
        :uses,
        :level,
        :sn1,
        :sn2,
        :sn3,
        :sn4,
        :u1);]]
    local spellm = copytable.deep(item.spells)
    spellm['serial'] = item.serial
    stmt:bind_names( spellm )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:addspell')
end

function EQdb:addskillmod(item)
  timer_start('EQdb:addskillmod')
  if item.skillmod and next(item.skillmod) then
    self.db:exec("DELETE from skillmod where serial = " .. tostring(item.serial))
    local stmt = self.db:prepare[[
      INSERT into skillmod VALUES (
        NULL,
        :serial,
        :skillnum,
        :value);]]
    for i,v in pairs(item.skillmod) do
      local skillm = {}
      skillm['serial'] = item.serial
      skillm['skillnum'] = i
      skillm['value'] = v
      stmt:bind_names( skillm )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
  end
  timer_end('EQdb:addskillmod')
end

function EQdb:addcontainer(item)
  timer_start('EQdb:addcontainer')
  if item.container and next(item.container) then
    local stmt = self.db:prepare[[
      INSERT OR REPLACE into container VALUES (
        NULL,
        :serial,
        :itemweightpercent,
        :heaviestitem,
        :capacity,
        :holding,
        :itemsinside,
        :totalweight,
        :itemburden);]]
    local containerm = copytable.deep(item.container)
    containerm['serial'] = item.serial
    stmt:bind_names( containerm )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:addcontainer')
end


function EQdb:addweapon(item)
  timer_start('EQdb:addweapon')
  if item.weapon and next(item.weapon) then
    local stmt = self.db:prepare[[
      INSERT or REPLACE into weapon VALUES (
        NULL,
        :serial,
        :wtype,
        :damtype,
        :special,
        :inflicts,
        :avedam);]]
    local weaponm = copytable.deep(item.weapon)
    weaponm['serial'] = item.serial
    stmt:bind_names( weaponm )
    stmt:step()
    stmt:finalize()
  end
  timer_end('EQdb:addweapon')
end

function EQdb:addresists(item)
  timer_start('EQdb:addresists')
  if item.resistmod and next(item.resistmod) then
    self.db:exec("DELETE from resistmod where serial = " .. tostring(item.serial))
    local stmt = self.db:prepare[[
      INSERT into resistmod VALUES (
        NULL,
        :serial,
        :type,
        :amount);]]
    for i,v in pairs(item.resistmod) do
      local resistm = {}
      resistm['serial'] = item.serial
      resistm['type'] = i
      resistm['amount'] = v
      stmt:bind_names( resistm )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
  end
  timer_end('EQdb:addresists')
end

function EQdb:addstats(item)
  timer_start('EQdb:addstats')
  if item.statmod and next(item.statmod) then
    self.db:exec("DELETE from statmod where serial = " .. tostring(item.serial))
    local stmt = self.db:prepare[[
      INSERT into statmod VALUES (
        NULL,
        :serial,
        :type,
        :amount);]]
    for i,v in pairs(item.statmod) do
      local statm = {}
      statm['serial'] = item.serial
      statm['type'] = i
      statm['amount'] = v
      stmt:bind_names( statm )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
  end
  timer_end('EQdb:addstats')
end

function EQdb:additemdetail(item)
  timer_start('EQdb:additemdetail')
  --tprint(item)
  self:checkitemdetailstable()
  if self:open('additemdetail') then
    local titem = self:getitemdetails(tonumber(item.serial))
    local tchanges = self.db:total_changes()
    assert (self.db:exec("BEGIN TRANSACTION"))
    if titem then
      local stmtupd = self.db:prepare[[ UPDATE itemdetails SET
                                                  cname = :cname,
                                                  name = :name,
                                                  level = :level,
                                                  type = :type,
                                                  worth = :worth,
                                                  weight = :weight,
                                                  wearable = :wearable,
                                                  score = :score,
                                                  flags = :flags,
                                                  fromclan = :fromclan,
                                                  owner = :owner
                                                  WHERE serial = :serial;
                                                            ]]

      stmtupd:bind_names( item )
      stmtupd:step()
      stmtupd:reset()
      stmtupd:finalize()
      --local retval self.db:exec(tsql)
    else
      local stmt = self.db:prepare[[ INSERT INTO itemdetails VALUES (
                                           :serial,
                                           :keywords,
                                           :cname,
                                           :name,
                                           :level,
                                           :type,
                                           :worth,
                                           :weight,
                                           :wearable,
                                           :material,
                                           :score,
                                           :flags,
                                           :foundat,
                                           :fromclan,
                                           :owner,
                                           :leadsto); ]]

      stmt:bind_names(item)
      local stepret = stmt:step()
      local resetret = stmt:reset()
      local finalret = stmt:finalize()
    end
    self:addresists(item)
    self:addstats(item)
    self:addspells(item)
    if item.skillmod and next(item.skillmod) then
      self:addskillmod(item)
    end
    if tonumber(item.type) == 1 and item.light ~= nil then
      self:addlight(item)
    end
    if tonumber(item.type) == 20 and item.portal ~= nil then
      self:addportal(item)
    end
    if tonumber(item.type) == 5 then
      self:addweapon(item)
    end
    if tonumber(item.type) == 9 then
      self:addfurniture(item)
    end
    if tonumber(item.type) == 11 then
      self:addcontainer(item)
    end
    if tonumber(item.type) == 12 then
      self:adddrink(item)
    end
    if tonumber(item.type) == 14 then
      self:addfood(item)
    end
    assert (self.db:exec("COMMIT"))
    phelper:mdebug('changes:', self.db:total_changes() - tchanges)
    self:close('additemdetail')
  end
  timer_end('EQdb:additemdetail')
end

function EQdb:addaffectmods(serial, affectmods)
  timer_start('EQdb:addresists')
  if serial and next(affectmods) then
    self.db:exec("DELETE from affectmod where serial = " .. tostring(serial))
    local stmt = self.db:prepare[[
      INSERT into affectmod VALUES (
        NULL,
        :serial,
        :type);]]
    for i,v in pairs(affectmods) do
      local affectm = {}
      affectm['serial'] = serial
      affectm['type'] = trim(v)
      stmt:bind_names( affectm )
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
  end
  timer_end('EQdb:addresists')
end

function EQdb:updateitemident(item)
  self:checkitemdetailstable()
  if self:open('additemdetail') then
    local titem = self:getitemdetails(tonumber(item.id))
    local tchanges = self.db:total_changes()
    if titem then
      -- assert (self.db:exec("BEGIN TRANSACTION"))
      local stmtupd = self.db:prepare[[ UPDATE itemdetails SET
                                                  keywords = :keywords,
                                                  material = :material,
                                                  foundat = :foundat,
                                                  leadsto = :leadsto
                                                  WHERE serial = :id;
                                                            ]]

      stmtupd:bind_names( item )
      stmtupd:step()
      stmtupd:reset()
      stmtupd:finalize()
      if item.affectmods then
        local amods = utils.split(item.affectmods, ',')
        self:addaffectmods(item.id, amods)
      end
      if item.note then
        self:addnote(item.id, item.note, true)
      end
      -- assert (self.db:exec("COMMIT"))
    end
    phelper:mdebug('changes:', self.db:total_changes() - tchanges)
    self:close()
  end
end

function EQdb:additems(items)
  timer_start('EQdb:additems')
  self:checkitemstable()
  for i,v in pairs(items) do
    --print(v.containerid)
    break
  end
  --print('additems')
  if self:open('additems') then
    local tchanges = self.db:total_changes()
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ INSERT INTO items VALUES (
                                           :serial,
                                           :shortflags,
                                           :level,
                                           :cname,
                                           :name,
                                           :type,
                                           :containerid,
                                           :wearslot,
                                           :place) ]]
    for i,v in pairs(items) do
      stmt:bind_names(v)
      local stepret = stmt:step()
      local resetret = stmt:reset()
      --print('additems: stepret', stepret)
      --print('additems: resetret', resetret)
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    phelper:mdebug('rowid:', rowid)
    phelper:mdebug('changes:', self.db:total_changes() - tchanges)
    self:close('additems')
  end
  timer_end('EQdb:additems')
end

function EQdb:clearcontainer(containerid)
  timer_start('EQdb:clearcontainer')
  self:checkitemstable()
  --print('clearing container', containerid)
  if self:open('clearcontainer') then
    --assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec("DELETE from items where containerid = '" .. tostring(containerid) .. "';")
    --assert (self.db:exec("COMMIT"))
    self:close('clearcontainer')
  end
  timer_end('EQdb:clearcontainer')
end

function EQdb:moveitem(item, container)
  timer_start('EQdb:moveitem')
  self:checkitemstable()
  if self:open('moveitem') then
    -- assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec(string.format("UPDATE items SET containerid = '%s', wearslot = %d, place = (SELECT MIN(place) - 1 from items where containerid = '%s') where serial = %d;",
                                     tostring(container), tonumber(item.wearslot),
                                     tostring(container), tonumber(item.serial)))
    -- assert (self.db:exec("COMMIT"))
    self:close('moveitem')
  end
  timer_end('EQdb:moveitem')
end

function EQdb:wearitem(item, wearloc)
  timer_start('EQdb:wearitem')
  self:checkitemstable()
  if self:open('wearitem') then
    -- assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec(string.format("UPDATE items SET containerid = 'Worn', wearslot = %d, place = -2 where serial = %d;",
                                     tonumber(wearloc),  tonumber(item.serial)))
    -- assert (self.db:exec("COMMIT"))
    self:close('wearitem')
  end
  timer_end('EQdb:wearitem')
end

function EQdb:updateitem(item)
  timer_start('EQdb:updateitem')
  self:checkitemstable()
  local tchanges = 0
  if self:open('updateitem') then
    tchanges = self.db:total_changes()
    -- assert (self.db:exec("BEGIN TRANSACTION"))
    self.db:exec(string.format([[UPDATE items SET shortflags = '%s',
                                                  level = %d,
                                                  cname = %s,
                                                  name = %s,
                                                  type = %d,
                                                  containerid = '%s',
                                                  wearslot = %d,
                                                  place = %d
                                                  WHERE serial = %d;]],
                                     tostring(item.shortflags), tonumber(item.level),
                                     fixsql(tostring(item.cname)), fixsql(tostring(item.name)), tonumber(item.type),
                                     tostring(item.containerid), tonumber(item.wearslot),
                                     tonumber(item.place), tonumber(item.serial)))
    -- assert (self.db:exec("COMMIT"))
    --print('rows changed', self.db:total_changes() - tchanges)
    self:close('updateitem')
  end
  timer_end('EQdb:updateitem')
end

function EQdb:getitembyserial(serial)
  --print('getitembyserial', serial)
  timer_start('EQdb:getitembyserial')
  local item = nil
  self:checkitemstable()
  if self:open('getitembyserial') then
    --print('getitembyserial:tonumber', tonumber(serial))
    if tonumber(serial) ~= nil  then
      for a in self.db:nrows(string.format("SELECT * FROM items WHERE serial = %d;", tonumber(serial))) do
        --print('getitembyserial')
        --tprint(a)
        item = a
      end
    end
    self:close('getitembyserial')
  end
  --print('getitembyserial', item)
  timer_end('EQdb:getitembyserial')
  return item
end

function EQdb:getitem(itemident)
  --print('getitem', itemident)
  timer_start('EQdb:getitem')
  local item = self:getitembyserial(itemident)
  if item == nil then
    item = self:getitembyidentifier(itemident)
  end
  --print('getitem', item)
  timer_end('EQdb:getitem')
  return item
end

function EQdb:getitembywearslot(wearslot)
  timer_start('EQdb:getitemsbywearslot')
  local item = {}
  self:checkitemstable()
  if self:open('getitemsbywearslot') then
    for a in self.db:nrows("SELECT * FROM items WHERE wearslot=" .. tostring(wearslot) ..";") do
      item = a
    end
    self:close('getitemsbywearslot')
  end
  timer_end('EQdb:getitemsbywearslot')
  --print('getitemsbywearslot', wearslot)
  --tprint(items)
  return item
end


function EQdb:getcontainercontents(containerid, sortkey, reverse, itype)
  if not sortkey then
    sortkey = 'place'
  end
  timer_start('EQdb:getcontainercontents')
  local sqlstr = "SELECT * FROM items WHERE containerid = '%s' "
  if itype then
    sqlstr = sqlstr .. " AND type = " .. tostring(itype)
  end
  sqlstr = sqlstr .. " ORDER BY ".. tostring(sortkey) .. " "
  if reverse then
    sqlstr = sqlstr .. "DESC"
  end
  sqlstr = sqlstr .. ";"
  local items = {}
  self:checkitemstable()
  if self:open('getcontainercontents') then
    for a in self.db:nrows(string.format(sqlstr, containerid)) do
      table.insert(items, a)
    end
    self:close('getcontainercontents')
  end
  timer_end('EQdb:getcontainercontents')
  return items
end

function EQdb:removeitems(items)
  timer_start('EQdb:removeitems')
  self:checkitemstable()
  if self:open('removeitems') then
    assert (self.db:exec("BEGIN TRANSACTION"))
    local stmt = self.db:prepare[[ DELETE from items where serial = :serial; ]]
    for i,v in pairs(items) do
      stmt:bind_names(v)
      stmt:step()
      stmt:reset()
    end
    stmt:finalize()
    assert (self.db:exec("COMMIT"))
    local rowid = self.db:last_insert_rowid()
    self:close('removeitems')
  end
  timer_end('EQdb:removeitems')
end

function EQdb:getcontainers()
  timer_start('EQdb:getcontainers')
  containers = {}
  self:checkitemstable()
  if self:open('getcontainers') then
    for a in self.db:nrows("SELECT * FROM items WHERE type = 11") do
      table.insert(containers, a)
    end
    self:close('getcontainers')
  end
  timer_end('EQdb:getcontainers')
  return containers
end

-- Identifier stuff
function EQdb:addidentifier(itemsn, identifier)
  timer_start('EQdb:addidentifier')
  --tprint(item)
  self:checkidentifiertable()
  local titem = self:getitembyidentifier(identifier)
  local item = self:getitembyserial(itemsn)
  local tchanges = 0
  if next(item) then
    if self:open('addidentifier') then
      local titem = self:getitemdetails(tonumber(item.serial))
      tchanges = self.db:total_changes()
      -- assert (self.db:exec("BEGIN TRANSACTION"))
      local stmt = self.db:prepare[[
        INSERT or REPLACE into identifier VALUES (
        :serial,
        :identifier);]]
      local identm = copytable.deep(item)
      identm.identifier = identifier
      stmt:bind_names( identm )
      stmt:step()
      stmt:finalize()
      -- assert (self.db:exec("COMMIT"))
      tchanges = self.db:total_changes() - tchanges
      self:close('addidentifier')
    end
  end
  timer_end('EQdb:addidentifier')
  return tchanges
end

function EQdb:getitembyidentifier(identifier)
  timer_start('EQdb:getitembyidentifier')
  --print('getitembyidentifier', identifier)
  self:checkidentifiertable()
  local item = nil
  if self:open('getitembyidentifier') then
    for a in self.db:nrows("SELECT * FROM identifier WHERE identifier=" .. fixsql(tostring(identifier)) ..";") do
      item = a
    end
    self:close('getitembyidentifier')
  end
  if item then
    return self:getitembyserial(item.serial)
  end
  timer_end('EQdb:getitembyidentifier')
  --print(item)
  return item
end

function EQdb:removeidentifier(identifier)
  timer_start('EQdb:removeidentifier')
  --tprint(item)
  self:checkidentifiertable()
  local tchanges = 0
  if self:open('removeidentifier') then
    tchanges = self.db:total_changes()
    self.db:exec("DELETE FROM identifier WHERE identifier='" .. tostring(identifier) .."';")
    tchanges = self.db:total_changes() - tchanges
    self:close('removeidentifier')
  end
  timer_end('EQdb:removeidentifier')
  return tchanges
end

function EQdb:getidentifiers(wearslot)
  timer_start('EQdb:getidentifiers')
  local items = {}
  self:checkitemstable()
  if self:open('getidentifiers') then
    for a in self.db:nrows("SELECT identifier.identifier as identifier, items.cname as cname, items.name as name, items.serial as serial FROM items,identifier WHERE identifier.serial=items.serial ORDER BY serial;") do
      if items[a.serial] then
        table.insert(items[a.serial]['identifier'], a.identifier)
      else
        items[a.serial] = a
        items[a.serial]['identifier'] = {a.identifier}
      end
    end
    self:close('getidentifiers')
  end
  timer_end('EQdb:getidentifiers')
  return items
end

function EQdb:cleandb()
  local tablesql = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
  self:close('cleandb', true)
  if self:open('cleandb') then
    for a in self.db:rows(tablesql) do
      if a[1] ~= 'items' and a[1] ~= 'sqlite_sequence' and a[1] ~= 'version' and a[1] ~= 'identifier' then
        local delsql = 'DELETE FROM ' .. tostring(a[1]) .. ' WHERE serial NOT IN(SELECT serial FROM items);'
        local tchanges = self.db:total_changes()
        print('cleaning table', a[1])
        local retval = self.db:exec(delsql)
        print('deleted', self.db:total_changes() - tchanges, 'rows from table:', a[1])
      end
    end
    self.db:exec('VACUUM;')
  end
end

--- version updates
function EQdb:updatenamecolumn()
  if self:checkfortable('items') then
    if self:open('updatenamecolumn') then
      local olditems = {}
      for a in self.db:nrows("SELECT * FROM items") do
        table.insert(olditems, a)
      end
      self:close('updatenamecolumn', true)
      self:open('updatenamecolumn2')
      self.db:exec([[DROP TABLE IF EXISTS items;]])
      self:close('updatenamecolumn2', true)
      self:open('updatenamecolumn3')
      local retval = self.db:exec([[CREATE TABLE items(
          serial INTEGER NOT NULL,
          shortflags TEXT,
          level NUMBER,
          cname TEXT,
          name TEXT,
          type NUMBER,
          containerid TEXT NOT NULL,
          wearslot INTEGER,
          place INTEGER,
          UNIQUE(serial),
          PRIMARY KEY(serial, containerid));
        )]])
      assert (self.db:exec("BEGIN TRANSACTION"))
      local stmt = self.db:prepare[[ INSERT INTO items VALUES (:serial, :shortflags, :level,
                                                            :cname, :name, :type, :containerid,
                                                            :wearslot, :place) ]]

      for i,v in ipairs(olditems) do
        v.cname = v.name
        v.name = v.plainname
        stmt:bind_names(v)
        stmt:step()
        stmt:reset()
      end
      stmt:finalize()
      assert (self.db:exec("COMMIT"))
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_containerid ON items(containerid);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_name ON items (name);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_level ON items(level);]])
      self.db:exec([[CREATE INDEX IF NOT EXISTS xref_items_place ON items(place);]])
      self.db:exec("PRAGMA foreign_keys=1;")

      self:close('updatenamecolumn3')
    end
  end
  if self:checkfortable('itemdetails') then
    if self:open('updatenamecolumn') then
      local olditems = {}
      for a in self.db:nrows("SELECT * FROM itemdetails") do
        table.insert(olditems, a)
      end
      self:close('updatenamecolumn', true)
      self:open('updatenamecolumn2')
      local retval = self.db:exec([[ALTER TABLE itemdetails RENAME TO itemdetails_bak;]])
      self:close('updatenamecolumn2', true)
      if retval == 0 then
        self:open('updatenamecolumn3')
        local retval =  self.db:exec([[
        CREATE TABLE itemdetails(
          serial INTEGER NOT NULL,
          keywords TEXT,
          cname TEXT,
          name TEXT,
          level NUMBER default 0,
          type NUMBER default 0,
          worth NUMBER default 0,
          weight NUMBER default 0,
          wearable TEXT,
          material NUMBER default 0,
          score NUMBER default 0,
          flags TEXT,
          foundat TEXT,
          fromclan TEXT,
          owner TEXT,
          UNIQUE(serial),
          PRIMARY KEY(serial));)]])
        local stmt = self.db:prepare[[ INSERT INTO itemdetails VALUES (:serial, :keywords,
                                                              :cname, :name, :level, :type, :worth,
                                                              :weight, :wearable, :material,
                                                              :score, :flags, :foundat, :fromclan,
                                                              :owner) ]]

        for i,v in ipairs(olditems) do
          v.cname = v.name
          v.name = v.plainname
          stmt:bind_names(v)
          stmt:step()
          stmt:reset()
        end
        stmt:finalize()
        assert (self.db:exec("COMMIT"))

        self.db:exec("PRAGMA foreign_keys=0;")
        local retval = self.db:exec([[DROP TABLE itemdetails_bak;]])
        self:close('updatenamecolumn3')
      end
    end
  end
end

function EQdb:addleadsto()
  if not self:checkfortable('itemdetails') then
    return
  end
  if self:open('addleadsto') then
    self.db:exec([[ALTER TABLE itemdetails ADD COLUMN leadsto TEXT;]])
    --self.db:exec([[UPDATE itemdetails SET blessingtrains = 0;]])
    --assert (self.db:exec("BEGIN TRANSACTION"))
    self:close('addleadsto', true)
  end
end

-- eqset stuff
function EQdb:addeqset(item, eqsetname, wearloc)

end

-- helper functions
function putobjectininv(item, noworn)
  local teqdb = EQdb:new{}
  if type(item) ~= 'table' then
    item = teqdb:getitem(item)
  end
  ---tprint(item)
  if item and next(item) then
    if item.containerid == 'Worn' and (noworn == false or noworn == nil) then
      SendNoEcho('remove ' .. item.serial)
      return true
    elseif item.containerid ~= 'Inventory' then
      SendNoEcho('get ' .. item.serial .. ' ' .. item.containerid)
      return true
    end
  end
  return false
end

function putobjectincontainer(item, container)
  local teqdb = EQdb:new{}
  local tcontainer = tonumber(container)
  if type(item) ~= 'table' then
    item = teqdb:getitem(item)
  end
  if tcontainer then
    local itcontainer = teqdb:getitem(tcontainer)
    if itcontainer and next(itcontainer) then
      SendNoEcho('put ' .. item.serial .. ' ' .. itcontainer.serial)
      return true
    else
      SendNoEcho('put ' .. item.serial .. ' ' .. tcontainer)
      return true
    end
  else
    if container == 'Worn' then
      SendNoEcho('wear ' .. item.serial)
      return true
    elseif container ~= 'Inventory' then
      SendNoEcho('put ' .. item.serial .. ' ' .. trim(container))
      return true
    end
  end
  return false
end

