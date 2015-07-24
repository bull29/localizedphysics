local GH = GravHull
local ENT = FindMetaTable("Entity")

------------------------------------------------------------------------------------------
-- Name: GetRealPos
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !ENT.GetRealPos then
    ENT.GetRealPos = ENT.GetPos
end

------------------------------------------------------------------------------------------
-- Name: GetRealAngles
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !ENT.GetRealAngles then
	ENT.GetRealAngles = ENT.GetAngles
end

------------------------------------------------------------------------------------------
-- Name: RealFireBullets
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !ENT.RealFireBullets then
	ENT.RealFireBullets = ENT.FireBullets
end

------------------------------------------------------------------------------------------
-- Name: GetRealVelocity
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !ENT.GetRealVelocity then
	ENT.GetRealVelocity = ENT.GetVelocity
end

------------------------------------------------------------------------------------------
-- Name: FireBullets
-- Desc: Also fire bullets from the physghost.
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Name: GetPos
-- Desc: Override the function.
------------------------------------------------------------------------------------------
ENT.GetPos = function(self,_nomr)
	if GH.DebugOverride and !IsValid(self) then error("Tried to use a NULL entity!",2) end
    self.UsedFakePos = true
	local nomr = _nomr
	if MapRepeat and MapRepeat.PosWrap and MapRepeat.PosWrap > 0 then nomr = true end
	if self.FakePosTime == CurTime() then return self.FakePos end
    if SERVER and (IsValid(self.InShip or self.MyShip) and GH.SHIPS[self.InShip or self.MyShip]) or
       CLIENT and (GH.SHIPCONTENTS[self] or GH.GHOSTHULLS[self]) then
        if self:IsWeapon() then
            return self:GetRealPos()
        else
            local data = SERVER and (GH.SHIPS[self.InShip or self.MyShip]) or
                         CLIENT and (GH.SHIPCONTENTS[self] or GH.GHOSTHULLS[self])
            local s,g = (self.InShip or self.MyShip or data.S), (data.MainGhost or data.G)
			if (IsValid(s) && IsValid(g)) then
				local pos,ang = WorldToLocal(self.RealPos or self:GetRealPos(),self.RealAng or self:GetRealAngles(),g.RealPos or g:GetRealPos(),g.RealAng or g:GetRealAngles())
				pos,ang = LocalToWorld(pos,ang,s:GetPos(nomr),s:GetAngles()) --recursive so you can live out your inception fantasies
				self.FakePos = pos
				self.FakePosTime = CurTime()
				return pos or self:GetRealPos()
			else
				return self:GetRealPos()
			end
        end
    elseif SERVER and !nomr and MapRepeat and self.Cells and #self.Cells == 1 then
		return MapRepeat.CellToPos(self:GetRealPos(),self.Cells[1])
	elseif CLIENT and !nomr and MapRepeat and type(MapRepeat.CelledEnts[self]) == 'string' then
		return MapRepeat.CellToPos(self:GetRealPos(),MapRepeat.CelledEnts[self])
	else
		return self:GetRealPos()
    end
end


------------------------------------------------------------------------------------------
-- Name: SetPos
-- Desc: Override the SetPos function; required for proper teleportation.
------------------------------------------------------------------------------------------
if !ENT.SetRealPos then
	ENT.SetRealPos = ENT.SetPos
end
ENT.SetPos = function(self,pos,_nomr)
	local nomr = _nomr
	if MapRepeat and MapRepeat.PosWrap and MapRepeat.PosWrap > 0 then nomr = true end
	if SERVER then
		if IsValid(self.InShip) and GH.SHIPS[self.InShip] then
			local S,G = self.InShip,GH.SHIPS[self.InShip].MainGhost
			if IsValid(S) && IsValid(G) then
				local npos = WorldToLocal(pos,Angle(0,0,0),S:GetPos(),S:GetAngles())
				npos = LocalToWorld(npos,Angle(0,0,0),G:GetRealPos(),G:GetRealAngles())
				self:SetRealPos(npos)
			else
				self:SetRealPos(pos)
			end
		else
			if GH.DebugOverride and !IsValid(self) then error("Tried to use a NULL entity!",2) end
			if MapRepeat then
				local cell,npos = MapRepeat.PosToCell(pos)
				if !(self.Cells and cell == self.Cells[1]) then
					MapRepeat.SetCell(self,cell)
				end
				self:SetRealPos(npos)
			else
				self:SetRealPos(pos)
			end
		end
	elseif MapRepeat and !nomr then
		local cell,npos = MapRepeat.PosToCell(pos)
		self:SetRealPos(npos)
	else
		self:SetRealPos(pos)
	end
end

------------------------------------------------------------------------------------------
-- Name: GetAngles
-- Desc: Override the function.
------------------------------------------------------------------------------------------
ENT.GetAngles = function(self)
	if GH.DebugOverride and !IsValid(self) then error("Tried to use a NULL entity!",2) end
	self.UsedFakeAng = true
	if self.FakeAngTime == CurTime() then return self.FakeAng end
    if SERVER and (IsValid(self.InShip or self.MyShip) and GH.SHIPS[self.InShip or self.MyShip]) or
       CLIENT and (GH.SHIPCONTENTS[self] or GH.GHOSTHULLS[self]) then
        if self:IsWeapon() then
            return self:GetRealPos()
        else
            local data = SERVER and (GH.SHIPS[self.InShip or self.MyShip]) or
                         CLIENT and (GH.SHIPCONTENTS[self] or GH.GHOSTHULLS[self])
            local s,g = (self.InShip or self.MyShip or data.S), (data.MainGhost or data.G)
			if (IsValid(s) && IsValid(g)) then
				local pos,ang = WorldToLocal(self.RealPos or self:GetRealPos(),self.RealAng or self:GetRealAngles(),g.RealPos or g:GetRealPos(),g.RealAng or g:GetRealAngles())
				pos,ang = LocalToWorld(pos,ang,s:GetPos(),s:GetAngles())
				self.FakeAng = ang
				self.FakeAngTime = CurTime()
				return ang or self:GetRealAngles()
			else
				return self:GetRealAngles()
			end
        end
    else
        return self:GetRealAngles()
    end
end


------------------------------------------------------------------------------------------
-- Name: GetVelocity
-- Desc: Currently disabled...
------------------------------------------------------------------------------------------
/*
ENT.GetVelocity = function(self)
	self.UsedFakeVel = true
	if self.FakeVelTime == CurTime() then return self.FakeVel end
    if SERVER and (IsValid(self.InShip or self.MyShip) and GH.SHIPS[self.InShip or self.MyShip]) or
       CLIENT and (GH.SHIPCONTENTS[self] or GH.GHOSTHULLS[self]) then
		local data = SERVER and (GH.SHIPS[self.InShip or self.MyShip]) or
					 CLIENT and (GH.SHIPCONTENTS[self] or GH.GHOSTHULLS[self])
		local s,g = (self.InShip or self.MyShip or data.S), (data.MainGhost or data.G)
		if (IsValid(s) && IsValid(g)) then
			local vel = WorldToLocal(self:GetRealVelocity(),Angle(0,0,0),vector_origin,g.RealAng or g:GetRealAngles())
			vel = LocalToWorld(vel,Angle(0,0,0),vector_origin,s:GetAngles())
			self.FakeVel = vel
			self.FakeVelTime = CurTime()
			return vel or self:GetRealVelocity()
		else
			return self:GetRealVelocity()
		end
    else
        return self:GetRealVelocity()
    end
end*/

------------------------------------------------------------------------------------------
-- Name: FindInSphere
-- Desc: Override the function.
------------------------------------------------------------------------------------------
if !ents.RealFindInSphere then
	ents.RealFindInSphere = ents.FindInSphere
end
ents.FindInSphere = function(vec,rad)
	local out = {}
	for _,e in pairs(ents.GetAll()) do
		if IsValid(e) and e:GetPos():Distance(vec) <= rad and !e.SLIsGhost then
			out[#out+1] = e
		end
	end
	return out
end


if !ENT.RealWorldToLocal then
	ENT.RealWorldToLocal = ENT.WorldToLocal
end
function ENT:WorldToLocal(pos)
	local out,_ = WorldToLocal(pos,Angle(0,0,0),self:GetPos(),self:GetAngles())
	return out
end
if !ENT.RealWorldToLocalAngles then
	ENT.RealWorldToLocalAngles = ENT.WorldToLocalAngles
end
function ENT:WorldToLocalAngles(ang)
	local _,out = WorldToLocal(vector_origin,ang,self:GetPos(),self:GetAngles())
	return out
end

if !ENT.RealLocalToWorld then
	ENT.RealLocalToWorld = ENT.LocalToWorld
end
function ENT:LocalToWorld(pos)
	local out,_ = LocalToWorld(pos,Angle(0,0,0),self:GetPos(),self:GetAngles())
	return out
end
if !ENT.RealLocalToWorldAngles then
	ENT.RealLocalToWorldAngles = ENT.LocalToWorldAngles
end
function ENT:LocalToWorldAngles(ang)
	local _,out = LocalToWorld(vector_origin,ang,self:GetPos(),self:GetAngles())
	return out
end