local GH = GravHull
local PLY = FindMetaTable("Player")
local ENT = FindMetaTable("Entity")
local PHY = FindMetaTable("PhysObj")

------------------------------------------------------------------------------------------
-- Name: OldSetViewEntity
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !PLY.OldSetViewEntity then
	PLY.OldSetViewEntity = PLY.SetViewEntity
end

------------------------------------------------------------------------------------------
-- Name: SetViewEntity
-- Desc: Override the function.
------------------------------------------------------------------------------------------
function PLY:SetViewEntity(ent)
	if IsValid(ent) then
		self:SendLua("SLViewEnt = Entity(" .. ent:EntIndex() .. ")")
	else
		self:SendLua("SLViewEnt = nil")
	end
	self:OldSetViewEntity(ent)
end

------------------------------------------------------------------------------------------
-- Name: SetNotSolid
-- Desc: Override the SetNotSolid function; required for sbep doors to function.
------------------------------------------------------------------------------------------
if !ENT.RealNotSolid then
	ENT.RealNotSolid = ENT.SetNotSolid
end
ENT.SetNotSolid = function(self,bool)
	if GH.DebugOverride and !IsValid(self) then error("Tried to use a NULL entity!",2) end
	self.IsNotSolid = bool
	self:RealNotSolid(bool)
	if IsValid(self.Ghost) then
		self.Ghost:RealNotSolid(bool)
	end
end
------------------------------------------------------------------------------------------
-- Name: Shipobject
-- Desc: Send an object to be processed by the clientside part of the mod.
------------------------------------------------------------------------------------------
function PLY:ShipObject(p,y,h,e,g)
	umsg.Start("sl_ship_object",self)
		umsg.Short(p:EntIndex())
		umsg.Bool(y)
		umsg.Bool(h)
		if e then
			umsg.Short(e:EntIndex())
			umsg.Short(g:EntIndex())
		end
	umsg.End()
end

------------------------------------------------------------------------------------------
-- Name: ComputeShadowControl
-- Desc: Override the ComputeShadowControl function; required for sbep lifts to function.
------------------------------------------------------------------------------------------
if !PHY.RealShadowControl then
	PHY.RealShadowControl = PHY.ComputeShadowControl
end
PHY.ComputeShadowControl = function(self,tab)
	if IsValid(self:GetEntity()) then
		local ship = self:GetEntity().InShip
		if IsValid(ship) then
			local data = GH.SHIPS[ship]
			if data and IsValid(data.MainGhost) then
				tab.pos,tab.angle = WorldToLocal(tab.pos,tab.angle,ship:GetPos(),ship:GetAngles())
				tab.pos,tab.angle = LocalToWorld(tab.pos,tab.angle,data.MainGhost:GetRealPos(),data.MainGhost:GetRealAngles())
			end
		end
	end
	self:RealShadowControl(tab)
end
------------------------------------------------------------------------------------------
-- Name: AddGhostRedirect
-- Desc: Used to quickly override a function that physghosts need to redirect.
------------------------------------------------------------------------------------------
function GH.AddGhostRedirect(name)
	local rnam = "Real"..name
	ENT[rnam] = ENT[rnam] or ENT[name]
	if GH.DebugOverride then
		ENT[name] = function(self, ...)
			if !IsValid(self) then error("Tried to use a NULL entity!",2) end
			if self.SLIsGhost and IsValid(self.SLMyGhost) then
				return self.SLMyGhost[rnam](self.SLMyGhost, ...)
			else
				return self[rnam](self, ...)
			end
		end
	else
		ENT[name] = function(self, ...)
			if self.SLIsGhost and IsValid(self.SLMyGhost) then
				return self.SLMyGhost[rnam](self.SLMyGhost, ...)
			else
				return self[rnam](self, ...)
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Name: TranslateConstraint
-- Desc: Override constraint arguments for physghosts.
------------------------------------------------------------------------------------------
function GH.TranslateConstraint(_e1,_e2,_p1,_p2)
	local e1,e2,p1,p2 = _e1,_e2,_p1,_p2
	if e1 and e1.SLIsGhost and IsValid(e1.SLMyGhost) then e1 = e1.SLMyGhost end
	if e2 and e2.SLIsGhost and IsValid(e2.SLMyGhost) then e2 = e2.SLMyGhost end
	if e1 and e2 and e1.InShip != e2.InShip then
		if GH.SHIPS[e1.InShip] then
			local isship = (e2.MyShip or (e2.Ghost and e2.Ghost.MyShip)) == e1.InShip
			if GH.EntInShip(e1.InShip, e2) and !isship then 
				GH.ShipEat(e1.InShip,e2)
			elseif GH.EntInShip(e1.InShip, e2, GH.SHIPS[e1.InShip].MainGhost) and !isship then
				GH.ShipEat(e1.InShip,e2,true)
			else
				for k,v in pairs(GH.ConstrainedEntities(e1)) do
					GH.ShipSpit(e1.InShip,v)
				end
			end
		end
		if GH.SHIPS[e2.InShip] then 
			local isship = (e1.MyShip or (e1.Ghost and e1.Ghost.MyShip)) == e2.InShip
			if GH.EntInShip(e2.InShip, e1) and !isship then
				GH.ShipEat(e2.InShip,e1)
			elseif GH.EntInShip(e2.InShip, e1, GH.SHIPS[e2.InShip].MainGhost) and !isship then
				GH.ShipEat(e2.InShip,e1,true)
			else
				for k,v in pairs(GH.ConstrainedEntities(e2)) do
					GH.ShipSpit(e2.InShip,v)
				end
			end
		end
	else
	/*	if p1 and p2 then --pos-based constraint
			p1 = e1:RealLocalToWorld(_e1:RealWorldToLocal(p1))
			p2 = e2:RealLocalToWorld(_e2:RealWorldToLocal(p2))
		end*/
	end
	if MapRepeat and (p1 or p2) then
		local c1,c2
		if p1 then c1,p1 = MapRepeat.PosToCell(p1) end
		if p2 then c2,p2 = MapRepeat.PosToCell(p2) end
	end
	return e1,e2,p1,p2
end

------------------------------------------------------------------------------------------
-- Name: AddConstraintRedirect
-- Desc: Override constraint functions for physghosts.
------------------------------------------------------------------------------------------
function GH.AddConstraintRedirect(name)
	local rnam = "Real"..name
	constraint[rnam] = constraint[rnam] or constraint[name]
	constraint[name] = function(...)
		local narg = table.Copy({...})
		local k1,k2,k3,k4 = 'n','n','n','n'
		for k,v in pairs(narg) do
			if type(v) == 'Entity' then
				if k1 != 'n' then k2 = k else k1 = k end
			end
			if type(v) == 'Vector' then
				if k3 != 'n' then k4 = k else k3 = k end
			end
		end
		narg.n = nil
		if MapRepeat then MapRepeat.PosWrap = MapRepeat.PosWrap + 1 end
		narg[k1],narg[k2],narg[k3],narg[k4] = GH.TranslateConstraint(narg[k1],narg[k2],narg[k3],narg[k4])
		local out = constraint[rnam](unpack(narg))
		if MapRepeat then MapRepeat.PosWrap = MapRepeat.PosWrap - 1 end
		return out
	end
end

function GH.GenSimpleOverrides()
	for _,func in pairs{
	"SetColor","SetMaterial","SetNetworkedAngle","SetNetworkedBool","SetNetworkedEntity","SetNetworkedFloat","SetNetworkedInt","SetNetworkedNumber","SetNetworkedString","SetNetworkedVar",
	"SetNetworkedVarProxy","SetNetworkedVector","SetSkin","SetNWAngle","SetNWBool","SetNWEntity","SetNWFloat","SetNWString","SetNWVector",} do
		GH.AddGhostRedirect(func)
	end
	for _,func in pairs{"AdvBallsocket","Axis","Ballsocket","Elastic","Hydraulic","Keepupright","Motor","Muscle","NoCollide","Rope","Slider","Weld","Winch"} do
		GH.AddConstraintRedirect(func)
	end
end
GH.GenSimpleOverrides()