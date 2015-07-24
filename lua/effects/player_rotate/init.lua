--player_rotate effect, used to transform things with multiple bones (orginally was for players, hence the name)
function EFFECT:Init(ed)
    self.Ent = ed:GetEntity()
end
function EFFECT:Render()
    local ent = self.Ent
local data = GravHull.SHIPCONTENTS[ent]
if !data then return false end
    //if ent:GetClass() == "prop_ragdoll" or ent:IsPlayer() then 
        local lpos,lang = WorldToLocal(EyePos(),RenderAngles(),data.S:GetPos(),data.S:GetAngles())
        cam.Start3D(LocalToWorld(lpos,lang,data.G.RealPos or data.G:GetRealPos(),data.G.RealAng or data.G:GetRealAngles()))
    /*else
        cam.Start3D(EyePos(),RenderAngles())
    end*/
		local col = (ent.OldColor or ent:GetColor())
        local r,g,b,a = col.r, col.g, col.b, col.a
        render.SetColorModulation(r/255,g/255,b/255)
        render.SetBlend(a/255)
        //if ent:GetClass() == "prop_ragdoll" or ent:IsPlayer() then
            self.DrawAgainInWater = true
            local lc = render.GetLightColor(ent:GetPos(true))
            render.SuppressEngineLighting(true)
            render.ResetModelLighting(lc.x*1.2-0.2,lc.y*1.2-0.2,lc.z*1.2-0.2)
            ent:SetupBones()
            ent:DrawModel()
            render.SuppressEngineLighting(false)
        /*else
            self.DrawAgainInWater = nil
            local oo = ent:GetRenderOrigin()
            local oa = ent:GetRenderAngles()
            ent:SetRenderOrigin(ent:GetPos())
            ent:SetRenderAngles(ent:GetAngles())
            ent:SetupBones()
            ent:DrawModel()
            ent:SetRenderOrigin(oo)
            ent:SetRenderAngles(oa)
        end*/
        if ent:IsPlayer() and IsValid(ent:GetActiveWeapon()) then 
            ent:GetActiveWeapon():DrawModel() 
        end
        for k,v in pairs(player.GetAll()) do
            if v:GetVehicle() == ent then
                v:DrawModel()
            end
        end
    cam.End3D()
end
function EFFECT:Think()
    if !IsValid(self.Ent) then return false end
    local ent = self.Ent
    local data = GravHull.SHIPCONTENTS[ent]
    if !(data && IsValid(data.S) && IsValid(data.G)) then 
        if ent.OldBonePos then 
            ent.BuildBonePositions = ent.OldBonePos 
            ent.OldBonePos = nil
        end
        return false 
    end
    if ent:IsPlayer() && !ent:Alive() then return false end
    local pos = WorldToLocal(ent:GetRealPos(),Angle(0,0,0),data.G:GetRealPos(),data.G:GetRealAngles())
    pos = LocalToWorld(pos,Angle(0,0,0),data.S:GetPos(true),data.S:GetAngles())
    self:SetRenderBoundsWS(pos-(ent:OBBMaxs()-ent:OBBMins()),pos+(ent:OBBMaxs()-ent:OBBMins()))
    return true
end