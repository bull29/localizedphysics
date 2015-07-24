local GH = GravHull
local PLY = FindMetaTable("Player")

------------------------------------------------------------------------------------------
-- Name: RealPlayerTrace
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !util.RealPlayerTrace then
	util.RealPlayerTrace = util.GetPlayerTrace
end

------------------------------------------------------------------------------------------
-- Name: RealTraceLine
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !util.RealTraceLine then
	util.RealTraceLine = util.TraceLine
end

------------------------------------------------------------------------------------------
-- Name: RealEyeTrace
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !PLY.RealEyeTrace then
	PLY.RealEyeTrace = PLY.GetEyeTrace
end

------------------------------------------------------------------------------------------
-- Name: RealEyeTraceNoCursor
-- Desc: Save the original function elsewhere.
------------------------------------------------------------------------------------------
if !PLY.RealEyeTraceNoCursor then
	PLY.RealEyeTraceNoCursor = PLY.GetEyeTraceNoCursor
end

--aim stuff
if !PLY.RealShootPos then
	PLY.RealShootPos = PLY.GetShootPos
end
if !PLY.RealAimVector then
	PLY.RealAimVector = PLY.GetAimVector
end/*
if !PLY.RealAimVector then
	PLY.RealAimVector = PLY.GetAimVector
end*/

------------------------------------------------------------------------------------------
-- Name: util.TraceLine
-- Desc: Currently disabled...
------------------------------------------------------------------------------------------
/*
util.TraceLine = function(tab)
	local tr = util.RealTraceLine(tab)
xpcall(function()
	if !IsValid(tr.Entity) then return tr end
	if (CLIENT and IsValid(tr.Entity) and (GH.GHOSTHULLS[tr.Entity] or GH.SHIPCONTENTS[tr.Entity])) or
	   (SERVER and IsValid(tr.Entity) and (GH.HULLS[tr.Entity] or tr.Entity.InShip)) then
		if CLIENT and GH.SHIPCONTENTS[tr.Entity] then 
			local data = GH.SHIPCONTENTS[tr.Entity]
			local pos,ang = WorldToLocal(tr.HitPos,Angle(0,0,0),data.G.RealPos or data.G:GetRealPos(),data.G.RealAng or data.G:GetRealAngles())
			pos,ang = LocalToWorld(pos,ang,data.S.RealPos or data.S:GetRealPos(),data.S.RealAng or data.S:GetRealAngles())
			tr.HitPos = pos
		elseif CLIENT and GH.GHOSTHULLS[tr.Entity] then
		elseif SERVER and tr.Entity.InShip then
			local data = GH.SHIPS[tr.Entity.InShip]
			tr.HitPos = tr.Entity.InShip:LocalToWorld(data.MainGhost:WorldToLocal(tr.HitPos))
		end
	end
end,ErrorNoHalt)
	return tr
end*/

------------------------------------------------------------------------------------------
-- Name: util.GetPlayerTrace
-- Desc: Override the function.
------------------------------------------------------------------------------------------
util.GetPlayerTrace = function(ply,dir,real)
	if (real) then return util.RealPlayerTrace(ply,dir) end
	local data
	if CLIENT then data = GH.SHIPCONTENTS[ply] else data = GH.SHIPS[ply.InShip] end
	if (data and !real) then
		local dataG = data.G or data.MainGhost
		local dataS = data.S or ply.InShip
		local aimvec = dir or ply:RealAimVector()
		if !(IsValid(dataG) and IsValid(dataS)) then return util.RealPlayerTrace(ply,dir) end
		local posin,_p = WorldToLocal(ply:RealShootPos(),Angle(0,0,0),dataG.RealPos or dataG:GetRealPos(),dataG.RealAng or dataG:GetRealAngles())
		local nrmin,_n = WorldToLocal(aimvec+(dataG.RealPos or dataG:GetRealPos()),Angle(0,0,0),dataG.RealPos or dataG:GetRealPos(),dataG.RealAng or dataG:GetRealAngles())
		local pos,_p = LocalToWorld(posin,_p,dataS.RealPos or dataS:GetRealPos(),dataS.RealAng or dataS:GetRealAngles())
		local nrm,_n = LocalToWorld(nrmin,_n,vector_origin,dataS.RealAng or dataS:GetRealAngles())
		local filt = {ply}
		local trace = { start = pos, endpos = pos + (nrm*16834), filter = filt }/*
		local tr = util.RealTraceLine(trace)
		if CLIENT then
			if IsValid(tr.Entity) and GH.GHOSTHULLS[tr.Entity] then
				return util.RealPlayerTrace( ply, aimvec )
			end
		else
			if IsValid(tr.Entity) and GH.HULLS[tr.Entity] then
				return util.RealPlayerTrace( ply, aimvec )
			end
		end*/
		return trace
	elseif MapRepeat then
		local nrm = dir or ply:GetAimVector()
		return { start = ply:GetShootPos(), endpos = ply:GetShootPos() + (nrm*16384), filter = {ply} }
	else
		local trace = util.RealPlayerTrace(ply,dir)
		/*
		if MapRepeat then
			for _,e in pairs(ents.GetAll()) do
				if e:GetMoveType() != MOVETYPE_NONE then
					if (SERVER and !MapRepeat.SameCell(ply,e)) or 
					   (CLIENT and !(MapRepeat.Cells[ply.CellStr or "0 0 0"] and (MapRepeat.Cells[ply.CellStr or "0 0 0"][e] or MapRepeat.Cells[ply.CellStr or "0 0 0"][e:EntIndex()]))) then
						if type(trace.filter) != 'table' then trace.filter = {trace.filter} end
						trace.filter[#trace.filter+1] = e
					end
				end
			end
		end*/
		return trace
	end
end

------------------------------------------------------------------------------------------
-- Name: GetEyeTraceNoCursor
-- Desc: Override the function.
------------------------------------------------------------------------------------------
function PLY:GetEyeTraceNoCursor()
	return self:GetEyeTrace(true)
end

------------------------------------------------------------------------------------------
-- Name: GetEyeTrace
-- Desc: Override the function.
------------------------------------------------------------------------------------------
function PLY:GetEyeTrace(hax,real)
	if ( self.LastPlayerTrace == CurTime() && self.LastTraceWasReal == real && self.LastTraceWasHax == hax) then
		return self.PlayerTrace
	end
	
	local data
	if CLIENT then data = GH.SHIPCONTENTS[self] else data = GH.SHIPS[self.InShip] end
	local aimvec = (hax and self:RealAimVector() or self:RealAimVector())
	local filt = {self}
	if CLIENT then 
		for gh,_ in pairs(GH.GHOSTHULLS) do
			filt[#filt+1] = gh
		end
	else
		for _,sh in pairs(GH.HULLS) do
			if IsValid(sh.Ghost) then
				filt[#filt+1] = sh.Ghost
			end
		end
		if MapRepeat and !data then
			for _,e in pairs(ents.GetAll()) do
				if !MapRepeat.SameCell(self,e) then
					filt[#filt+1] = e
				end
			end
		end
	end
	if (data and !real) then
		local dataG = data.G or data.MainGhost
		local dataS = data.S or self.InShip
		if !(IsValid(dataG) && IsValid(dataS)) then
			self.PlayerTrace = util.TraceLine{ start = self:RealShootPos(), endpos = self:RealShootPos()+(aimvec*16834), filter = filt}
			return self.PlayerTrace
		end
		local posin,_p = WorldToLocal(self:RealShootPos(),Angle(0,0,0),dataG.RealPos or dataG:GetRealPos(),dataG.RealAng or dataG:GetRealAngles())
		local nrmin,_n = WorldToLocal(aimvec+(dataG.RealPos or dataG:GetRealPos()),Angle(0,0,0),dataG.RealPos or dataG:GetRealPos(),dataG.RealAng or dataG:GetRealAngles())
		local pos,_p = LocalToWorld(posin,_p,dataS.RealPos or dataS:GetRealPos(),dataS.RealAng or dataS:GetRealAngles())
		local nrm,_n = LocalToWorld(nrmin,_n,vector_origin,dataS.RealAng or dataS:GetRealAngles())
		self.PlayerTrace = util.TraceLine{ start = pos, endpos = pos + (nrm*16834), filter = filt }
	else
		aimvec = (hax and self:GetAimVector() or self:GetAimVector())
		self.PlayerTrace = util.TraceLine{ start = self:GetShootPos(), endpos = self:GetShootPos()+(aimvec*16834), filter = filt}
	end
	self.LastPlayerTrace = CurTime()
	self.LastTraceWasReal = real
	self.LastTraceWasHax = hax
	
	return self.PlayerTrace
end

function PLY:GetShootPos()
	local data
	if CLIENT then data = GH.SHIPCONTENTS[self] else data = GH.SHIPS[self.InShip] end
	if data then
		local dataG = data.G or data.MainGhost
		local dataS = data.S or self.InShip
		if !(IsValid(dataG) && IsValid(dataS)) then
			return self:RealShootPos()
		end
		local posin,_p = WorldToLocal(self:RealShootPos(),Angle(0,0,0),dataG.RealPos or dataG:GetRealPos(),dataG.RealAng or dataG:GetRealAngles())
		local pos,_p = LocalToWorld(posin,_p,dataS.RealPos or dataS:GetRealPos(),dataS.RealAng or dataS:GetRealAngles())
		return pos or self:RealShootPos()
    elseif SERVER and MapRepeat and self.Cells and #self.Cells == 1 then
		return MapRepeat.CellToPos(self:RealShootPos(),self.Cells[1])
	elseif CLIENT and MapRepeat and type(MapRepeat.CelledEnts[self]) == 'string' then
		return MapRepeat.CellToPos(self:RealShootPos(),MapRepeat.CelledEnts[self])
	else
		return self:RealShootPos()
	end
end
function PLY:GetAimVector()
	local data
	if CLIENT then data = GH.SHIPCONTENTS[self] else data = GH.SHIPS[self.InShip] end
	if data then
		local dataG = data.G or data.MainGhost
		local dataS = data.S or self.InShip
		if !(IsValid(dataG) && IsValid(dataS)) then
			return self:RealAimVector()
		end
		local posin,_p = WorldToLocal(self:RealAimVector(),Angle(0,0,0),vector_origin,dataG.RealAng or dataG:GetRealAngles())
		local pos,_p = LocalToWorld(posin,_p,vector_origin,dataS.RealAng or dataS:GetRealAngles())
		return pos or self:RealAimVector()
	else
		return self:RealAimVector()
	end
end/*
function PLY:GetAimVector()
	local data
	if CLIENT then data = GH.SHIPCONTENTS[self] else data = GH.SHIPS[self.InShip] end
	if data then
		local dataG = data.G or data.MainGhost
		local dataS = data.S or self.InShip
		if !(IsValid(dataG) && IsValid(dataS)) then
			return self:RealAimVector()
		end
		local posin,_p = WorldToLocal(self:RealAimVector(),Angle(0,0,0),vector_origin,dataG.RealAng or dataG:GetRealAngles())
		local pos,_p = LocalToWorld(posin,_p,vector_origin,dataS.RealAng or dataS:GetRealAngles())
		return pos or self:RealAimVector()
	else
		return self:RealAimVector()
	end
end*/