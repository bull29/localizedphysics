local GH = GravHull
include('sh_codetools.lua')
GH.SHIPCONTENTS = {}
GH.GHOSTHULLS = {}
------------------------------------------------------------------------------------------
-- Name: AddHullIds
-- Desc: Called when a hull usermessage is recieved; waits until the entity indices are valid
------------------------------------------------------------------------------------------
local function AddHullIds(tab,enti,shipi,ghosti,times)
	local ent,ship,ghost = Entity(enti),Entity(shipi),Entity(ghosti)
	if !(IsValid(ent) && IsValid(ship) && IsValid(ghost)) then
		if (times < 50) then
			timer.Simple(0.1,function() AddHullIds(tab,enti,shipi,ghosti,times+1) end)
		end
		return
	end
	tab[ent] = {S = ship, G = ghost}
	ent.Ghost = ghost
	ghost.Hull = ent
end
local draw_with_effect = kv_swap{
	"player",
	"npc_grenade_frag",
	"crossbow_bolt",
	"prop_combine_ball",
	"rpg_missile",
	"gmod_cameraprop",
	"gmod_turret",
}
------------------------------------------------------------------------------------------
-- Name: AddPropIds
-- Desc: Called when a contents usermessage is recieved; waits until the entity indices are valid
------------------------------------------------------------------------------------------
local function AddPropIds(tab,enti,shipi,ghosti,times)
	local ent,ship,ghost = Entity(enti),Entity(shipi),Entity(ghosti)
	if !(IsValid(ent) && IsValid(ship) && IsValid(ghost)) then
		if (times < 50) then
			timer.Simple(0.1,function() AddPropIds(tab,enti,shipi,ghosti,times+1) end)
		end
		return
	end
	if (ent == LocalPlayer()) then
		ent.RollCorrection = true
	end
	tab[ent] = {S = ship, G = ghost}
	if ent == ship then ent.Ghost = ghost end
	if (draw_with_effect[ent:GetClass()] or ent:IsVehicle() or (ent:GetMoveType() != MOVETYPE_NONE && (ent:GetBoneCount()||0) > 1)) then
		local ed = EffectData()
		ed:SetEntity(ent)
		ent.OldColor = ent:GetColor()
		ent:SetColor(Color(0,0,0,0))
		ent.WasHidden = true
		util.Effect("player_rotate",ed)
	end
end
------------------------------------------------------------------------------------------
-- Name: sl_ship_object
-- Desc: The hull/contents usermessage, basically gives the client data about ships
------------------------------------------------------------------------------------------
usermessage.Hook("sl_ship_object",function(um) --this is how the server tells us which entities are "contained"
	local enti,yes,hull = um:ReadShort(),um:ReadBool(),um:ReadBool()
	local tab = GH.SHIPCONTENTS
	if hull then tab = GH.GHOSTHULLS end
	if yes and hull then
		local shipi,ghosti = um:ReadShort(),um:ReadShort()
		AddHullIds(tab,enti,shipi,ghosti,0)
	elseif yes then
		local shipi,ghosti = um:ReadShort(),um:ReadShort()
		AddPropIds(tab,enti,shipi,ghosti,0)
	else
		local ent = Entity(enti)
		if IsValid(ent) then
			if ent.RealColor or ent.WasHidden then
				ent:SetColor(ent.RealColor or Color(255,255,255,255))
				if ent:GetColor().a == 0 then ent:SetColor(Color(255,255,255,255)) end
			end
			if (ent == LocalPlayer()) then
				ent.RollCorrection = true
			end
			tab[ent] = nil
		end
	end
end)
------------------------------------------------------------------------------------------
-- Name: sl_ship_explosion
-- Desc: The explosion usermessage, used
------------------------------------------------------------------------------------------
usermessage.Hook("sl_ship_explosion",function(um)
	local ed = EffectData()
	local pos = um:ReadVector()
	ed:SetStart(pos)
	ed:SetOrigin(pos)
	util.Effect("Explosion",ed)
	/* DECALS DON'T WORK YET
	local tr = util.RealTraceLine{ent:GetPos(), endpos = ent:GetPos() - Vector(0,0,ent:BoundingRadius()), filter = ent}
	if (tr.Hit) then
		util.Decal("Scorch",tr.HitPos+tr.HitNormal,tr.HitPos-tr.HitNormal)
	end*/
end)
------------------------------------------------------------------------------------------
-- Name: sl_antiteleport_cl
-- Desc: Clientside portion of the anti-teleport handshake
------------------------------------------------------------------------------------------
usermessage.Hook("sl_antiteleport_cl",function(um) --recieved when the player's position is set by the server, used to avoid SetPos packet loss resulting in teleporting to the sky
	local ppos = um:ReadVector()
	if (LocalPlayer():GetRealPos():Distance(ppos) > 3000) then
		RunConsoleCommand("sl_antiteleport")
	end
end)
local RenderViewing = false
/*hook.Add("PreDrawOpaqueRenderables","SLShipStart",function()
	if RenderViewing then return end
	local ply = LocalPlayer()
	local data = GH.SHIPCONTENTS[ply]
	if data then
		local pos,ang = EyePos(),EyeAngles()
		pos = data.S:LocalToWorld(data.G:WorldToLocal(pos))
		ang = data.S:LocalToWorldAngles(data.G:WorldToLocalAngles(ang))
		RenderViewing = true
		render.RenderView{
			origin = pos,
			angles = ang,
			x = 0, y = 0,
			w = ScrW(),
			h = ScrH(),
			drawviewmodel = false
		}
		RenderViewing = false
	end
end)*/ 
------------------------------------------------------------------------------------------
-- Name: SLBindPress
-- Desc: Used for overriding binds so they send an extra console command making them work in ships
------------------------------------------------------------------------------------------
hook.Add("PlayerBindPress","SLBindPress",function(ply,str,down)
	if string.find(str,"+use") && GH.SHIPCONTENTS[ply] && !(ply:KeyDown(IN_ATTACK) and IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass()=="weapon_physgun") then
		RunConsoleCommand("sl_external_use")
	end
end)
local cvt = CreateClientConVar("ghd_cameramethod",0,true,false)
------------------------------------------------------------------------------------------
-- Name: DoCalcView
-- Desc: The magic calcview hook.
------------------------------------------------------------------------------------------
GH.DoCalcView = function(ply,pos,ang,fov,nope)
	local apply = false
	local method = cvt:GetInt()
	local view
	if method == 0 then
		if nope == "SLShipView" then return end
		view = hook.Call("CalcView",GAMEMODE,ply,pos,ang,fov,"SLShipView")
	elseif method == 1 then 
		view = {origin = pos, angles = ang}
	end
	xpcall(function()
		if ply.RollCorrection then
			local pa = ply:EyeAngles()
			if pa.r > 0 then
				pa.r = pa.r * 0.9
				if (pa.r < 1) then pa.r = pa.r * 0.5 end
				if (pa.r < 0.1) then pa.r = 0 end
			elseif pa.r < 0 then
				pa.r = pa.r * 0.9
				if (pa.r > -1) then pa.r = pa.r * 0.5 end
				if (pa.r > -0.1) then pa.r = 0 end
			end
			if pa.r == 0 then ply.RollCorrection = nil end
			ply:SetEyeAngles(pa)
			ply.LastCorrection = CurTime()
		end
		local data = GH.SHIPCONTENTS[ply]
		if ply:InVehicle() && IsValid(ply:GetVehicle()) then
			data = GH.SHIPCONTENTS[ply:GetVehicle()]
		end
		if IsValid(SLViewEnt) then
			data = GH.SHIPCONTENTS[SLViewEnt]
		end
		if data && IsValid(data.S) && IsValid(data.G) then
			local tpos,tang = WorldToLocal(view.origin,view.angles,data.G.RealPos or data.G:GetRealPos(),data.G.RealAng or data.G:GetRealAngles())
			view.origin,view.angles = LocalToWorld(tpos,tang,data.S:GetPos(true),data.S:GetAngles())
			if view.vm_origin and view.vm_angles then
				local vmpos,vmang = WorldToLocal(view.vm_origin,view.vm_angles,data.G.RealPos or data.G:GetRealPos(),data.G.RealAng or data.G:GetRealAngles())
				view.vm_origin, view.vm_angles = LocalToWorld(vmpos,vmang,data.S:GetPos(true),data.S:GetAngles())
			end
			apply = true
		end
	end,ErrorNoHalt)
	if apply then
		if method == 0 then
			return view//GAMEMODE:CalcView(ply,pos,ang,fov)
		elseif method == 1 then
			return GAMEMODE:CalcView(ply,view.origin,view.angles,fov)
		end
	end
end
hook.Add("CalcView","SLShipView",GH.DoCalcView)
local cvhook = "SLShipView"
------------------------------------------------------------------------------------------
-- Name: ghd_fixcamera
-- Desc: The magic calcview fixing function-- renames the hook in an attempt to claim priority.
------------------------------------------------------------------------------------------
concommand.Add("ghd_fixcamera",function()
	hook.Remove("CalcView",cvhook)
	cvhook = string.char(math.random(32,122)).."SLShipView"
	hook.Add("CalcView",cvhook,GH.DoCalcView)
	Msg("GHD Camera Fix attempted, try now and run again if it doesn't work.")
end)
------------------------------------------------------------------------------------------
-- Name: SLRestoreRealPos
-- Desc: Called after each frame to SetPos the objects back where they should be once rendered.
------------------------------------------------------------------------------------------
local function SLRestoreRealPos(TABLE)
	for ent,data in pairs(TABLE) do
		if IsValid(ent) then
			//if !(GH.SHIPCONTENTS[LocalPlayer()] and GH.SHIPCONTENTS[LocalPlayer()].S == data.S) then
				if data and IsValid(data.S) and IsValid(data.G) then
					if ent.RealPos then ent:SetPos(ent.RealPos) end
					if ent.RealAng then ent:SetAngles(ent.RealAng) end
					if ent.RealColor then ent:SetColor(ent.RealColor) end
					if ent.RealRenderMode then ent:SetRenderMode(ent.RealRenderMode) end
					if (ent.GetActiveWeapon and IsValid(ent:GetActiveWeapon())) then ent:GetActiveWeapon():SetColor(Color(255,255,255,255)) end
				end
			//end
		end
	end
end
hook.Add("PostRenderVGUI","SLShipEnd",function()
	xpcall(function()
		SLRestoreRealPos(GH.SHIPCONTENTS)
		SLRestoreRealPos(GH.GHOSTHULLS)
	end,ErrorNoHalt)
end)
------------------------------------------------------------------------------------------
-- Name: SLShipContents
-- Desc: Called before each frame to SetPos the objects to their transformed location.
------------------------------------------------------------------------------------------
local function SLShipContents(TABLE,UseSG,cover)
	for ent,data in pairs(TABLE) do
		if IsValid(ent) then
			if data and IsValid(data.S) and IsValid(UseSG and data.S.Ghost or data.G) then
				local G = (UseSG and data.S.Ghost or data.G)
				if draw_with_effect[ent:GetClass()] and ent != LocalPlayer() then
				/*
					local pos,ang,eye = ent:GetRealPos(),ent:GetRealAngles(),ent:EyeAngles()
					ent.RealPos = pos
					ent.RealAng = ang
					ent.RealEye = eye
					ent:SetPos(data.S:LocalToWorld(G:WorldToLocal(pos))) 
					ent:SetAngles(data.S:LocalToWorldAngles(G:WorldToLocalAngles(ang)))*/
					//ent:SetEyeAngles(data.S:LocalToWorldAngles(G:WorldToLocalAngles(eye)))
					ent.RealColor = ent:GetColor()
					ent.RealRenderMode = ent:GetRenderMode()
					ent:SetRenderMode(RENDERMODE_NONE)
					if (ent.GetActiveWeapon and IsValid(ent:GetActiveWeapon())) then ent:GetActiveWeapon():SetColor(Color(0,0,0,0)) end
				elseif ent != LocalPlayer() && (ent:GetMoveType() != MOVETYPE_NONE and ent:GetBoneCount()) == 1 && !ent.WasHidden then
					local pos,ang = ent:GetRealPos(),ent:GetRealAngles()
					ent.RealPos = pos
					ent.RealAng = ang
					if cover then
						ent:SetPos((G.RealPos or G:GetRealPos())-(RenderAngles():Forward()))
						ent:SetAngles(G:GetRealAngles())
					else
						local npos,nang = WorldToLocal(pos,ang, G.RealPos or G:GetRealPos(), G.RealAng or G:GetRealAngles())
						npos,nang = LocalToWorld(npos,nang, data.S:GetPos(), data.S:GetAngles())
						ent:SetPos(npos)
						ent:SetAngles(nang)
					end
				end
			else
				TABLE[ent] = nil
			end
		else
			TABLE[ent] = nil
		end
	end
end
hook.Add("RenderScene","SLShipDraw",function() --fake the positions of "contained" objects, unless the player is in the same place as the object
	xpcall(function()
		SLShipContents(GH.GHOSTHULLS,nil,true)
		SLShipContents(GH.SHIPCONTENTS)
	end,ErrorNoHalt)
end)
------------------------------------------------------------------------------------------
-- Name: sl_fake_tooltrace
-- Desc: Sent by the server to fake the tool trace for interrupted CanTool messages
------------------------------------------------------------------------------------------
usermessage.Hook("sl_fake_tooltrace",function(um)
	local wep = um:ReadEntity()
	local ent = um:ReadEntity()
	local pos = um:ReadVector()
	local nrm = um:ReadVector()
	local bone = um:ReadShort()
	wep:DoShootEffect(pos,nrm,ent,bone,true)
end)
local warpmat = Material("effects/water_warp01")
local mats = {}
local bmat = {}
local fogs = {}
local underwater = false
local wasinship = false
hook.Add("Think","SLWaterCheck",function()
    local ply = LocalPlayer()
    if ply:WaterLevel() == 3 then
        if !underwater then
            local tr = util.TraceLine{start = ply:GetPos(), endpos = ply:GetPos()+Vector(0,0,10000), mask = MASK_NPCSOLID_BRUSHONLY}
            tr = util.TraceLine{start = tr.HitPos, endpos = tr.HitPos+Vector(0,0,-20000), mask = CONTENTS_WATER}
			if !tr.HitTexture then return end
            mats[tr.HitTexture] = mats[tr.HitTexture] or Material(tr.HitTexture)
            local mtl = mats[tr.HitTexture]
            local blw = mtl:GetString("$bottommaterial")
			if blw then
				bmat[blw] = bmat[blw] or Material(blw)
				blw = bmat[blw]
				/*
				mtl:SetInt("$fogenable",1)
				blw:SetInt("$fogenable",1)
				mtl:SetInt("$fogstart",1)
				blw:SetInt("$fogstart",1)
				blw:SetInt("$fogend",1000000)
				mtl:SetInt("$fogend",1000000)
				blw:SetTexture("$normalmap",emptynrm)
				mtl:SetTexture("$normalmap",emptynrm)*/
				blw:SetString("$underwateroverlay","")
			end
        end
        underwater = true
    else
        underwater = false
    end
    if GravHull.SHIPCONTENTS[ply] then
        if !wasinship then
            for k,v in pairs(bmat) do
				fogs[k.."s"] = v:GetInt("$fogstart")
				fogs[k.."e"] = v:GetInt("$fogend")
				if fogs[k.."s"] < 500 then
					v:SetInt("$fogstart",500)
				end
				if fogs[k.."e"] < 1000 then
					v:SetInt("$fogend",1000)
				end
            end
        end
        wasinship = true
    else
		if wasinship then
            for k,v in pairs(bmat) do
                v:SetInt("$fogstart",fogs[k.."s"])
                v:SetInt("$fogend",fogs[k.."e"])
            end
        end
        wasinship = false
    end
end)
hook.Add("PreDrawHUD","SLWaterOverlay",function()
    for k,v in pairs(ents.FindByClass("class CLuaEffect")) do 
        if (v.DrawAgainInWater && bit.band(util.PointContents(v.Ent:GetPos()), CONTENTS_WATER) != 0) then 
            v:Render()
        end
    end
    if underwater then
        render.UpdateRefractTexture()
        render.SetMaterial(warpmat)
        render.DrawScreenQuad()
    end
end)