util.AddNetworkString("maprepeat_num")
util.AddNetworkString("maprepeat_space")
util.AddNetworkString("maprepeat_rgen")
util.AddNetworkString("maprepeat_setcell")	
util.AddNetworkString("maprepeat_cell")
util.AddNetworkString("maprepeat_install")
util.AddNetworkString("maprepeat_uninstall")
local function maprepeat_num(k,v,p) -- Sends info_maprepeat info to client
	if !IsValid(p) then return end
	net.Start("maprepeat_num",p)
		net.WriteString(k)
		net.WriteFloat(v)
	net.Send(p)
end
local function maprepeat_rgen(e,t,p) -- Random Generation data
	if !e or e == NULL or !IsEntity(e) or !IsValid(p) then return end
	net.Start("maprepeat_rgen")
		net.WriteInt(e:EntIndex(),16) -- Sends entities to client
		net.WriteInt(#t,16) -- Sends chance to client
		net.WriteInt(t.r or 0,16) -- Sends (???) to client
		for k,v in pairs(t) do
			if type(v) == 'table' then -- COME BACK TO THIS!
				net.WriteString(v[1] or "?")
				net.WriteString(v[2] or "?")
				net.WriteString(v[3] or "?")
			end
		end
	net.Send(p)
end
local function maprepeat_space(s,p) -- Space data
	if !s or !p then return end
	net.Start("maprepeat_space")
		net.WriteInt(s,16) -- Sends the keyvalue to the client, so it knows when to render space.
	net.Send(p)
end
local function maprepeat_cell(ent,cell,set,p) -- Send cell data to client
	if !ent or ent == NULL or !IsEntity(ent) then return end
	net.Start((set and "maprepeat_setcell" or "maprepeat_cell"))
		net.WriteInt(ent:EntIndex(),16) -- Send entities to client
		net.WriteString(cell or "0 0 0") -- Send what cell the client is in to the client
	if(IsValid(p)) then -- If the player is valid, send it to them. If not, send it to everyone.
		net.Send(p)
	else
		net.Broadcast()
	end
end
MapRepeat.PosWrap = 0
MapRepeat.Hooks = {}
MapRepeat.Transition = {}
function MapRepeat.AddHook(a,b,c) -- Only adds hooks if MapRepeat is active
	MapRepeat.Hooks[a] = MapRepeat.Hooks[a] or {}
	MapRepeat.Hooks[a][b] = c
end
function MapRepeat.InstallHooks() -- Tells all clients to install hooks
	for a,t in pairs(MapRepeat.Hooks) do
		for b,c in pairs(t) do
			hook.Add(a,b,c)
		end
	end
	MapRepeat.Installed = true
	net.Start("maprepeat_install"); net.Broadcast()
end
function MapRepeat.SetNumber(k,v) -- Sends info_maprepeat info to client
	if !v then return end
	MapRepeat.Sync[k] = v
	maprepeat_num(k,v)
end
function MapRepeat.SetRGen(ent,tbl) -- Sets up the table for RGen
	MapRepeat.RGen[ent] = tbl
	maprepeat_rgen(ent,tbl)
end
function MapRepeat.AddCell(ent,cell) -- Add a cell serverside
	if ent == NULL then return end
	MapRepeat.Cells[cell] = MapRepeat.Cells[cell] or {} -- Script error prevention
	MapRepeat.Cells[cell][ent] = true -- The ent is in this cell
	ent.Cells = ent.Cells or {} -- Script error prevention
	ent.Cells[#ent.Cells+1] = cell -- Next index
	maprepeat_cell(ent,cell)
end
function MapRepeat.SetCell(ent,cell) -- Sets the cell for ShouldCollide and everything
	if ent.Cells then 
		for _,c in pairs(ent.Cells) do
			(MapRepeat.Cells[c]||{})[ent] = nil -- (???)
		end 
	end
	MapRepeat.Cells[cell] = MapRepeat.Cells[cell] or {} -- Script error prevention
	MapRepeat.Cells[cell][ent] = true
	ent.Cells = {cell} -- The ent is in this cell!
	maprepeat_cell(ent,cell,true) -- Send its cell data to client!

	-- Space stuff!
	local cellz = tonumber(string.sub(cell,5),10) -- Gets the z value of the cell (gets the 1 out of 0 0 1)
	local phys = ent:GetPhysicsObject()
	if (IsValid(phys) and !ent:IsPlayer() and ent:GetClass() != "prop_combine_ball") then
		if(SPACE and cellz >= tonumber(SPACE)) then -- If you're above the threshold
			phys:EnableGravity(false)
		elseif(SPACE and cellz < tonumber(SPACE)) then -- If you're below
				phys:EnableGravity(true)
		end
	/*elseif(ent:IsPlayer()) then -- BREAKS MR, COME BACK TO THIS!
		if(SPACE and cellz >= tonumber(SPACE)) then
			ent:SetGravity(0.000001)
		elseif(SPACE and cellz < tonumber(SPACE)) then
			ent:SetGravity(1)
		end*/
	end
	--
end
function MapRepeat.PlayerData(ply) -- Sets everything up for the player
	net.Start("maprepeat_install",ply); net.Send(ply)
	maprepeat_space(SPACE,ply) -- Tell the player about where space is
	for k,v in pairs(MapRepeat.Sync or {}) do maprepeat_num(k,v,ply) end
	for k,v in pairs(MapRepeat.RGen or {}) do maprepeat_rgen(k,v,ply) end
	for c,t in pairs(MapRepeat.Cells or {}) do 
		for k,v in pairs(t) do
			maprepeat_cell(k,c,false,ply)
		end
	end
	MapRepeat.SetCell(ply,"0 0 0")
end
hook.Add("PlayerInitialSpawn","SL_MRData",function(ply) -- Once the player spawns, set up their MapRepeat data.
	if MapRepeat then
		timer.Simple(1, function() MapRepeat.PlayerData(ply) end) 
		timer.Simple(1, function() ply:Spawn() end)
	end
end)
function MapRepeat.ClaimWep(ent) -- Special stuff for weapons
	local ply
	if ent:IsWeapon() and !ent.Cells then
		local dst = 10000
		for k,v in pairs(player.GetAll()) do
			if v:GetRealPos():Distance(ent:GetRealPos()) < dst then
				dst = v:GetRealPos():Distance(ent:GetRealPos())
				ply = v
			end
		end
	end
	if ply and ply.Cells then
		MapRepeat.SetCell(ent,ply.Cells[1])
		return false
	end
	return true
end
function MapRepeat.SameCell(e1,e2) -- Are these two ents in the same cell?
	if !e1.Cells then 
		if e1:IsWeapon() then -- If it's a weapon run the special weapon stuff.
			if MapRepeat.ClaimWep(e1) then return true end
		else
			return MapRepeat.RGen[e1] == nil
		end
	end
	if !e2.Cells then 
		if e2:IsWeapon() then
			if MapRepeat.ClaimWep(e2) then return true end
		else
			return MapRepeat.RGen[e2] == nil 
		end
	end
	local out = false
	for _,c in pairs(e1.Cells) do
		if !(MapRepeat.Cells[c] and MapRepeat.Cells[c].gen) then
			MapRepeat.GenCell(c) -- If the cell's not even valid, generate it.
		end
	end
	for _,c in pairs(e2.Cells) do
		if !(MapRepeat.Cells[c] and MapRepeat.Cells[c].gen) then
			MapRepeat.GenCell(c)
		end
	end
	for _,c1 in pairs(e1.Cells) do
		for _,c2 in pairs(e2.Cells) do
			if c1 == c2 then
				out = true
				break
			end
		end
		if out then break end
	end
	return out
end
concommand.Add("sl_mr_gencell",function(p,c,a)
	MapRepeat.GenCell(a[1]) -- Don't worry about this.
end)
MapRepeat.AddHook("ShouldCollide","SL_MRCollide",function(e1,e2)
	if e1.InShip or e2.InShip then return end
	if !MapRepeat.SameCell(e1,e2) then return false end -- If they're not in the same cell, don't let them collide.
end)
MapRepeat.AddHook("PhysgunPickup","SL_MRPickup",function(e1,e2)
	if !MapRepeat.SameCell(e1,e2) then return false end -- If they're not in the same cell, don't let players pick them up.
end)
MapRepeat.AddHook("PhysgunDrop","SL_MRPickup",function(e1,e2)
	if !MapRepeat.SameCell(e1,e2) then return false end -- If they're not in the same cell, don't let players pick them up
end)
local ENT = FindMetaTable("Entity")
if !ENT.ReallyValid then ENT.ReallyValid = ENT.IsValid end
function ENT:IsValid() -- Override for IsValid()
	if !self then return false end
	if self.m_isWorld then return false end
	if (self.m_tblToolsAllowed||{})[1] == "world" then 
		self.m_tblToolsAllowed = nil
		if self:GetPhysicsObject():IsValid() then self:GetPhysicsObject():EnableMotion(false) end
		self.m_isWorld = true
		return false 
	end
	return self:ReallyValid()
end
if !ENT.RealEyePos then ENT.RealEyePos = ENT.EyePos end
function ENT:EyePos() -- Override for EyePos()
	if self.Cells and #self.Cells == 1 then
		return MapRepeat.CellToPos(self:RealEyePos(),self.Cells[1])
	else
		return self:RealEyePos()
	end
end
hook.Add("InitPostEntity","MR_IPE",function() -- After entities are created
	if !MapRepeat.Installed then -- If MapRepeat's uninstalled, tell the client to uninstall it as well.
		MapRepeat = nil 
		net.Start("maprepeat_uninstall"); net.Broadcast();
		hook.Add("PlayerInitialSpawn","SL_NoMR",function(ply)
			net.Start("maprepeat_uninstall"); net.Send(ply);
		end)
	else
		MapRepeat.GenCell("0 0 0") -- Otherwise, generate the starting cell.
	end
end)
MapRepeat.AddHook("PlayerSpawn","DR_MPDeath",function(ply) -- Death hook
	if (IsValid(ply)) then
		MapRepeat.SetCell(ply,"0 0 0")
	end
end)
hook.Add("EntityKeyValue","MR_KVH",function(ent,k,v) -- Gets values inputted into entities
	local rep = {} -- Create a blank table
	if string.sub(k,1,4) == 'cell' then -- If the keyvalue is cell (like cell1)
		local i = string.sub(k,5) -- i is the number at the end of the name, such as cell1, cell2
		local c = v -- c variable is the value, such as 0 0 0
		if string.find(c,'?') or string.find(c,'%%') then -- If ? or chance
			local ct = MapRepeat.CellToArray(c) -- Get the values from the cell
			rep[#rep+1] = ct -- Next index
		else
			MapRepeat.AddCell(ent,c) -- Add them
		end
	end
	-- More space stuff!
	if string.sub(k,1,7) == 'space' then -- If it finds the keyvalue space
		if(v != 0 and v) then
			SPACE = v -- Global var space is the value!
		end
	end
	--
	if string.sub(k,1,8) == 'chance' then
		if (v and string.sub(v,1,1)=='%') then
		-- Coming soon!
		end
	end
	if #rep > 0 then -- If there are ? or %
		MapRepeat.SetRGen(ent,rep) -- Run RGen on the ent
	end
end)
local PHYS = FindMetaTable("PhysObj")
if !PHYS.RealWorldToLocal then -- If the function is broken or disabled, use the usual one
	PHYS.RealWorldToLocal = PHYS.WorldToLocal
end
function PHYS:WorldToLocal(_pos) -- Overrides WorldToLocal
	local _,pos = _,_pos
	if MapRepeat and MapRepeat.PosWrap <= 0 then
		_,pos = MapRepeat.PosToCell(_pos)
	elseif !MapRepeat then PHYS.WorldToLocal = PHYS.RealWorldToLocal end
	return self:RealWorldToLocal(pos)
end
if !PHYS.RealLocalToWorld then -- If the function is broken or disabled, use the usual one
	PHYS.RealLocalToWorld = PHYS.LocalToWorld
end
function PHYS:LocalToWorld(pos) -- Overrides LocalToWorld
	if !MapRepeat or MapRepeat.PosWrap > 0 then
		if !MapRepeat then PHYS.LocalToWorld = PHYS.RealLocalToWorld end
		return self:RealLocalToWorld(pos)
	end
	local tpos = MapRepeat.CellToPos(self:GetPos(),(self:GetEntity().Cells||{})[1])
	local out,_ = LocalToWorld(pos,Angle(0,0,0),tpos,self:GetAngles())
	return out
end
MapRepeat.AddHook("AllowGhostSpot","MR_GH_Ghosts",function(pos,rad) -- For GHD, where the ghost ship can be
	local s = MapRepeat.Sync
	if (pos.x < s.left+rad or pos.x > s.right-rad or 
		pos.y < s.top+rad or pos.y > s.bottom-rad or
		pos.z < s.down+rad or pos.z > s.up-rad) then return false end -- Basically, if it's in one of the cells other than the one you're in, don't allow it.
end)

if !PHYS.RealSetPos then -- If the function is broken or disabled, use the usual one
	PHYS.RealSetPos = PHYS.SetPos
end
function PHYS:SetPos(pos) -- Overrides SetPos
	if !MapRepeat or MapRepeat.PosWrap > 0 then
		if !MapRepeat then PHYS.SetPos = PHYS.RealSetPos end
		return self:RealSetPos(pos)
	end
	local cell,tpos = MapRepeat.PosToCell(pos)
	MapRepeat.SetCell(self:GetEntity(),cell)
	self:RealSetPos(tpos)
end

if !PHYS.RealGetPos then -- If the function is broken or disabled, use the usual one
	PHYS.RealGetPos = PHYS.GetPos
end
function PHYS:GetPos() -- Overrides GetPos
	if !MapRepeat or MapRepeat.PosWrap > 0 then
		if !MapRepeat then PHYS.GetPos = PHYS.RealGetPos end
		return self:RealGetPos()
	end
	local ent = self:GetEntity()
	if SERVER and ent.Cells and #ent.Cells == 1 then
		return MapRepeat.CellToPos(self:RealGetPos(),ent.Cells[1])
	elseif CLIENT and type(MapRepeat.CelledEnts[ent]) == 'string' then
		return MapRepeat.CellToPos(self:RealGetPos(),MapRepeat.CelledEnts[ent])
	end
	return self:RealGetPos()
end
