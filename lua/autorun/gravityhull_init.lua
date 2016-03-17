include("gravityhull/init.lua")
include("maprepeat/init.lua")
if SERVER then
	AddCSLuaFile("gravityhull/init.lua")
	AddCSLuaFile("maprepeat/init.lua")
	AddCSLuaFile("autorun/gravityhull_init.lua")
end
