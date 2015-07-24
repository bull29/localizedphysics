local function maprepeat_num(k,v,p)
	umsg.Start("maprepeat_num",p)
		umsg.String(k)
		umsg.Float(v)
	umsg.End()
end
local function maprepeat_rgen(e,t,p)
	if !e or e == NULL or !IsEntity(e) then return end
	umsg.Start("maprepeat_rgen",p)
		umsg.Short(e:EntIndex())
		umsg.Short(#t)
		umsg.Short(t.r or 0)
		for k,v in pairs(t) do
			if type(v) == 'table' then
				umsg.String(v[1] or "?")
				umsg.String(v[2] or "?")
				umsg.String(v[3] or "?")
			end
		end
	umsg.End()
end
local function maprepeat_cell(ent,cell,set,p)
	if !ent or ent == NULL or !IsEntity(ent) then return end
	umsg.Start((set and "maprepeat_setcell" or "maprepeat_cell"),p)
		umsg.Short(ent:EntIndex())
		umsg.String(cell or "0 0 0")
	umsg.End()
end
MapRepeat.PosWrap = 0
MapRepeat.Hooks = {}
MapRepeat.Transition = {}
function MapRepeat.AddHook(a,b,c)
	MapRepeat.Hooks[a] = MapRepeat.Hooks[a] or {}
	MapRepeat.Hooks[a][b] = c
end
function MapRepeat.InstallHooks()
	for a,t in pairs(MapRepeat.Hooks) do
		for b,c in pairs(t) do
			hook.Add(a,b,c)
		end
	end
	MapRepeat.Installed = true
	umsg.Start("maprepeat_install"); umsg.End()
end
function MapRepeat.SetNumber(k,v)
	if !v then return end
	MapRepeat.Sync[k] = v
	maprepeat_num(k,v)
end
function MapRepeat.SetRGen(ent,tbl)
	MapRepeat.RGen[ent] = tbl
	maprepeat_rgen(ent,tbl)
end
function MapRepeat.AddCell(ent,cell)
	if ent == NULL then return end
	MapRepeat.Cells[cell] = MapRepeat.Cells[cell] or {}
	MapRepeat.Cells[cell][ent] = true
	ent.Cells = ent.Cells or {}
	ent.Cells[#ent.Cells+1] = cell
	maprepeat_cell(ent,cell)
end
function MapRepeat.SetCell(ent,cell)
	if ent.Cells then 
		for _,c in pairs(ent.Cells) do
			(MapRepeat.Cells[c]||{})[ent] = nil
		end 
	end
	MapRepeat.Cells[cell] = MapRepeat.Cells[cell] or {}
	MapRepeat.Cells[cell][ent] = true
	ent.Cells = {cell}
	maprepeat_cell(ent,cell,true)
end
function MapRepeat.PlayerData(ply)
	umsg.Start("maprepeat_install",ply); umsg.End()
	for k,v in pairs(MapRepeat.Sync or {}) do maprepeat_num(k,v,ply) end
	for k,v in pairs(MapRepeat.RGen or {}) do maprepeat_rgen(k,v,ply) end
	for c,t in pairs(MapRepeat.Cells or {}) do 
		for k,v in pairs(t) do
			if k == Entity(54) then print("SEND " .. c) end
			maprepeat_cell(k,c,false,ply)
		end
	end
	MapRepeat.SetCell(ply,"0 0 0")
end
hook.Add("PlayerInitialSpawn","SL_MRData",function(ply)
	if MapRepeat then
		timer.Simple(1, function() MapRepeat.PlayerData(ply) end) 
		timer.Simple(1, function() ply:Spawn() end)
	end
end)
function MapRepeat.ClaimWep(ent)
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
function MapRepeat.SameCell(e1,e2)
	if !e1.Cells then 
		if e1:IsWeapon() then
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
			MapRepeat.GenCell(c)
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
	MapRepeat.GenCell(a[1])
end)
MapRepeat.AddHook("ShouldCollide","SL_MRCollide",function(e1,e2)
	if e1.InShip or e2.InShip then return end
	if !MapRepeat.SameCell(e1,e2) then return false end
end)
MapRepeat.AddHook("PhysgunPickup","SL_MRPickup",function(e1,e2)
	if !MapRepeat.SameCell(e1,e2) then return false end
end)
MapRepeat.AddHook("PhysgunDrop","SL_MRPickup",function(e1,e2)
	if !MapRepeat.SameCell(e1,e2) then return false end
end)
local ENT = FindMetaTable("Entity")
if !ENT.ReallyValid then ENT.ReallyValid = ENT.IsValid end
function ENT:IsValid()
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
function ENT:EyePos()
	if self.Cells and #self.Cells == 1 then
		return MapRepeat.CellToPos(self:RealEyePos(),self.Cells[1])
	else
		return self:RealEyePos()
	end
end
hook.Add("InitPostEntity","MR_IPE",function()
	if !MapRepeat.Installed then 
		MapRepeat = nil 
		umsg.Start("maprepeat_uninstall"); umsg.End();
		hook.Add("PlayerInitialSpawn","SL_NoMR",function(ply)
			umsg.Start("maprepeat_uninstall",ply); umsg.End();
		end)
	else
		MapRepeat.GenCell("0 0 0")
	end
end)
MapRepeat.AddHook("EntityKeyValue","MR_KVH",function(ent,k,v)
	local rep = {}
	if string.sub(k,1,4) == 'cell' then
		local i = string.sub(k,5)
		local c = v
		if string.find(c,'?') or string.find(c,'%%') then 
			local ct = MapRepeat.CellToArray(c)
			rep[#rep+1] = ct
		else
			MapRepeat.AddCell(ent,c)
		end
	end
	if #rep > 0 then
		MapRepeat.SetRGen(ent,rep)
	end
end)
local PHYS = FindMetaTable("PhysObj")
if !PHYS.RealWorldToLocal then
	PHYS.RealWorldToLocal = PHYS.WorldToLocal
end
function PHYS:WorldToLocal(_pos)
	local _,pos = _,_pos
	if MapRepeat and MapRepeat.PosWrap <= 0 then
		_,pos = MapRepeat.PosToCell(_pos)
	elseif !MapRepeat then PHYS.WorldToLocal = PHYS.RealWorldToLocal end
	return self:RealWorldToLocal(pos)
end
if !PHYS.RealLocalToWorld then
	PHYS.RealLocalToWorld = PHYS.LocalToWorld
end
function PHYS:LocalToWorld(pos)
	if !MapRepeat or MapRepeat.PosWrap > 0 then
		if !MapRepeat then PHYS.LocalToWorld = PHYS.RealLocalToWorld end
		return self:RealLocalToWorld(pos)
	end
	local tpos = MapRepeat.CellToPos(self:GetPos(),(self:GetEntity().Cells||{})[1])
	local out,_ = LocalToWorld(pos,Angle(0,0,0),tpos,self:GetAngles())
	return out
end
MapRepeat.AddHook("AllowGhostSpot","MR_GH_Ghosts",function(pos,rad)
	local s = MapRepeat.Sync
	if (pos.x < s.left+rad or pos.x > s.right-rad or 
		pos.y < s.top+rad or pos.y > s.bottom-rad or
		pos.z < s.down+rad or pos.z > s.up-rad) then return false end
end)

if !PHYS.RealSetPos then
	PHYS.RealSetPos = PHYS.SetPos
end
function PHYS:SetPos(pos)
	if !MapRepeat or MapRepeat.PosWrap > 0 then
		if !MapRepeat then PHYS.SetPos = PHYS.RealSetPos end
		return self:RealSetPos(pos)
	end
	local cell,tpos = MapRepeat.PosToCell(pos)
	MapRepeat.SetCell(self:GetEntity(),cell)
	self:RealSetPos(tpos)
end

if !PHYS.RealGetPos then
	PHYS.RealGetPos = PHYS.GetPos
end
function PHYS:GetPos()
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