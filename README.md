TODO
• Optimize the constraint-enabled in/out scanner to reduce lag.
• Add the ability for the effect to be (adv)duplicated, including objects welded to the inside of the ship.
• Fix the hull within a hull within a hull from sending you to limbo
• Work on making major mods work flawlessly with the mod, especially wire and spacebuild.
• Implement a dampening percentage slider so that values below 100% will allow some inertia through.
• Implement a dampening threshold slider so that only velocity changes above the value will obey the above.
• Recode the physgun beam in lua so that it renders.
• Add a stencil system so you can have the classic "cloaked ship with a doorway" effect.
• Fix parenting with Map Repeater.
• Fix adv dupe weirdness with Map Repeater.
• Fix thirdperson camera colliding with nonexistant brushes in Map Repeater
• Fix NPC walking off a hull causing prop bouncing weirdness.
• Add LOD for infinite maps to render distant cells.
• Cloaking for GHD's
• Extend cell keyvalues, such as space, spawning brushes if another brush spawned or didn't spawn, etc.

CHANGELOG
Revision 29: Lots of bug fixes for Map Repeater and GHD, converted both to net messages rather than usermessages.
Revision 28: Fixed Map Repeater for GMod 13.
----------------------------------------------------------------------------------------------------------------------------------------
Revision 27: Fixed the underwater system in gm13.
Revision 26: Ported to Gmod 13, some infinite map fixes, physghosts also should work now.
Revision 25: Fixed smartsnap in infinite maps (partially), fixed spawning initially without weapons.
Revision 24: Fixed hulls from erroring when broken. Added the map used for Map Repeater -- uncomment the second line in lua/autorun/gravityhull_init.lua in order to enable it.
Revision 23: Stopped maprepeat from loading, it was breaking spacebuild even in unaffected maps.
Revision 22: SUBMARINES YEAHHHHH
• added the prealpha maprepeat code-- don't use it yet though.
• fixed players in hulls being invisible underwater.
• fixed players in hulls having incorrect lighting (sort of).
• stopped the water warp effect from being visible when in a hull.
• increased the minimum distance for water fog while in a hull.
Revision 21 fixed the rocket launcher and improved velocity support so that ship velocity is added/subtracted during transitions.
Revision 20:
• added FireBullets support, fixing most SWEPs
• fixed ghosted explosives from infinitely exploding
• fixed a stack overflow when welding a contraption to the inside of a hull
• fixed transitions between ships taking too long to reset
• added a player gravity slider (will work on props later on)
• added a Help button to explain how to use the tool
• added a GravHull.RegisterHull(ent,protrusion,gravity) function for developers (YOU WILL NEED TO CALL GravHull.UpdateHull(ent) AFTERWARDS)
Revision 19 fixed stack overflow when welding an object to the inside of a ship
Revision 18 fixed easy weld and keep upright causing an error
Revision 17 added/fixed:
• New Tool Handler
- most tools work both inside and outside the ship now, including many wiremod ones
- physghosts can be constrained, colored, etc, redirecting to the actual entity
- ship prop modifications can be applied from the inside (i.e. color, material)
- should fix most trace-related errors including the WAC helicopter bug
• Fixed entities spawning hundreds of physghosts by accident
• Fixed physghosts permanently setting a prop's mass to 4768
• Added client console command 'ghd_fixcamera' which, if run enough times, should fix the camera bug whenever it occurs
• Fixed open sbep doors in a hull being closed on the inside
Revision 16 re-fixed buttons and chairs
Revision 15 fixed sbep lifts and hopefully spacebuild and stargate.
Revision 14 fixed the AddCSLuaFile bug.
Revision 13 fixed the floor checkbox designating hulls with extremely wrong angles, various lag/crash problems involving the new hull scanner, stopped the tool from designating something that's already designated, and fixed a bug with physghosts where a prop would disappear if you held a prop, put it in the ship, then walked in yourself without letting go. 
Revision 12, added/fixed:
• New Hull Scanner
- ignores no collides
- builds a hull out of welded/nailed props
- adds anything constrained without a weld (ropes, hydraulics) to the "moving parts" list for permanent physghosting, allowing hydraulic doors to function with collision
- two constrained hulls will also add each other as permanent physghosts
• SBEP Door Support
- uses SetNotSolid, so props will remain in the ship until they exit the door
• Vertical Protusion Factor Slider (0 to 300)
- sets the maximum distance from the floor for an entity to be inside the ship without a ceiling or walls
• Hit Surface Defines Floor checkbox
- if checked, gravity will be perpendicular to the normal of your tool's hit trace
- in laymen's terms, shoot the surface you want to walk on.
• Stopped rotating objects in a ship from pressing Use
• Applied Divran's file splits and loader
• Cleaned up the code a bit and moved the globals into a table called GravHull
Revision 11 fixed the chair teleport issue.
Revision 10 re-fixed physghosts, added explosion effects to gas cans, and stops physboxes from crashing
Revision 9 fixes vehicles, the invisible toolgun, no collide (sort of), and hopefully player respawning in ships
Revision 8 should fix the thruster crash (the ship was absorbing itself) and stargates, and the following hooks for easier mod integration:
• EnterShip(ent,ship,ghost,oldpos,oldang)
• ExitShip(ent,ship,ghost,oldpos,oldang)
• ValidHull(ent) -- return false to disallow ent from being considered part of the hull geometry
• OnCreatePhysghost(ship,ent,physghost) -- used for custom extra steps in the setup of physghosts (the objects you're actually dragging when you drag physgun something outside from inside a ship)
• AllowGhostSpot(pos) -- return false if pos should not be used to spawn ghost ships (i.e. underwater, though this is disabled by default)
Revision 7 should fix Smartsnap and possibly certain aim-based E2's
Revision 6 should fix the GetPhysicsAttacker crash
Revision 5 fixed:
• Chairs/Buttons not working when welded to a ship
• Sharpeye compatibility (and hopefully other view mods too, if you had the camera bug this should fix it permanently (EDIT: or not))
• Physghosts (they were nonfunctional due to a typo)
Revision 4 fixed entities not ghosting properly
Revision 3 fixed the in/out algorithm giving unexpected results
