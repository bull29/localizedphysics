include("gravityhull/init.lua")

local AllowMapRepeat = true
if AllowMapRepeat then include("maprepeat/init.lua") end

if SERVER then
	AddCSLuaFile("gravityhull/init.lua")
	AddCSLuaFile("autorun/gravityhull_init.lua")
	if AllowMapRepeat then AddCSLuaFile("maprepeat/init.lua") end
end
