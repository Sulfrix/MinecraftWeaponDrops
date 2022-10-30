
if (CLIENT) then return end

util.AddNetworkString("mcitem_playerdrop")

CreateConVar("mcitem_manualdrops", "1", FCVAR_REPLICATED, "Enable players manually dropping weapons as Minecraft items.")
CreateConVar("mcitem_manualdrops_time", "30", FCVAR_REPLICATED, "How long manual drops take to disappear.")
CreateConVar("mcitem_deathdrops", "1", FCVAR_REPLICATED, "Enable players dropping their weapons as Minecraft items on death.")
CreateConVar("mcitem_deathdrops_ammo", "1", FCVAR_REPLICATED, "Enable deathdrops containing ammo.")
CreateConVar("mcitem_deathdrops_time", "20", FCVAR_REPLICATED, "How long death drops take to disappear.")
CreateConVar("mcitem_deathdrops_exclude", "", FCVAR_REPLICATED, "Comma-seperated list of weapons that shouldn't be dropped when a player dies. See mcitem_deathdrops_excludesandbox for the Sandbox weapons")
CreateConVar("mcitem_deathdrops_excludesandbox", "1", FCVAR_REPLICATED, "Shortcut to adding either just the Sandbox tools (1) or all of the Sandbox default weapons (2) to mcitem_deathdrops_exclude")
CreateConVar("mcitem_deathdrops_noadmin", "1", FCVAR_REPLICATED, "Disables dropping weapons that are admin-only.")
CreateConVar("mcitem_manualpickup", "0", FCVAR_REPLICATED, "If on, the player must interact with drops to pick them up.")
CreateConVar("mcitem_autoequip", "0", FCVAR_REPLICATED, "Overrides the way weapon auto-switching works with the items. -1 = no autoswitch, 0 = default (weight-based), 1 = always autoswitch")
CreateConVar("mcitem_npc_deathdrop", "1", FCVAR_REPLICATED, "NPCs will drop their currently held weapon on death.")
CreateConVar("mcitem_npc_pickup", "1", FCVAR_REPLICATED, "NPCs will be able to pick up item weapons. If this is set to 2, NPCs will pick up any dropped item, even if the weapon isn't marked as NPC usable. Can be perf-intensive.")


-- weapon_crowbar,weapon_physgun,weapon_physcannon,weapon_pistol,weapon_357,weapon_smg1,weapon_ar2,weapon_shotgun,weapon_crossbow,weapon_frag,weapon_rpg,gmod_camera,gmod_tool

local excludepreset1 = string.Split("weapon_physgun,gmod_camera,gmod_tool", ",")
local excludepreset2 = string.Split("weapon_crowbar,weapon_physgun,weapon_physcannon,weapon_pistol,weapon_357,weapon_smg1,weapon_ar2,weapon_shotgun,weapon_crossbow,weapon_frag,weapon_rpg,gmod_camera,gmod_tool", ",")


net.Receive("mcitem_playerdrop", function(len, ply)
    if (GetConVar("mcitem_manualdrops"):GetBool()) then
        MCDropEyes(ply)
    end
end)

hook.Add("PlayerSwitchWeapon", "MCPreventAutoSwitch", function (ply, oldw, neww)
    if (IsValid(neww)) then
        if (neww.noSwitch) then
            if (SERVER) then
                neww.noSwitch = false
            end
            return true
        end
    end
end)

hook.Add( "PlayerCanPickupWeapon", "MCAllowPickup", function( ply, ent )
    if (ent:GetTable().noPickup) then
        return false
    end
end )

hook.Add( "GravGunPickupAllowed", "MCAllowPickup", function( ply, ent )
    if (ent:GetTable().noPickup or ent:GetClass() == "sent_mcitem") then
        return false
    end
end )



hook.Add("DoPlayerDeath", "MCPlayerDeath", function(ply, ent)
    if (!GetConVar("mcitem_deathdrops"):GetBool()) then return end
    local exclude = string.Split(GetConVar("mcitem_deathdrops_exclude"):GetString(), ",")
    if (GetConVar("mcitem_deathdrops_excludesandbox"):GetInt() == 1) then
        table.Merge(exclude, excludepreset1)
    end
    if (GetConVar("mcitem_deathdrops_excludesandbox"):GetInt() == 2) then
        table.Merge(exclude, excludepreset2)
    end
    local rot = 360/math.min(16, #ply:GetWeapons())
    local ang = Angle(-18, 0, 0)
    local weaps = ply:GetWeapons()
    --PrintTable(ply:GetAmmo())
    local ammo = ply:GetAmmo() -- For each ammo type on the player, each weapon will have an equal cut of its ammo type given to each item.
    local ammoCounts = {}
    for k, v in ipairs(weaps) do
        if (ammoCounts[v:GetPrimaryAmmoType()] == nil) then
            ammoCounts[v:GetPrimaryAmmoType()] = 1
        else
            ammoCounts[v:GetPrimaryAmmoType()] = ammoCounts[v:GetPrimaryAmmoType()] + 1
        end
        if (ammoCounts[v:GetSecondaryAmmoType()] == nil) then
            ammoCounts[v:GetSecondaryAmmoType()] = 1
        else
            ammoCounts[v:GetSecondaryAmmoType()] = ammoCounts[v:GetSecondaryAmmoType()] + 1
        end
    end
    --PrintTable(ammoCounts)
    for k, v in ipairs(weaps) do
        if (!table.HasValue(exclude, v:GetClass()) and (!v.AdminOnly or !GetConVar("mcitem_deathdrops_noadmin"):GetBool())) then
            local i = MCDropWeapon(v, ply:GetPos()+ply:OBBCenter()+(ang:Forward()*20), ang:Forward()*(math.Rand(0.05, 1.1)))
            i.ttl = GetConVar("mcitem_deathdrops_time"):GetFloat()
            if (GetConVar("mcitem_deathdrops_ammo"):GetBool()) then
                i.ammoType1 = v:GetPrimaryAmmoType()
                i.ammoType2 = v:GetSecondaryAmmoType()
                if (i.ammoType1 and ammo[i.ammoType1] ~= nil) then
                    i.ammo1 = ammo[i.ammoType1]/ammoCounts[i.ammoType1]
                end
                if (i.ammoType2 and ammo[i.ammoType2] ~= nil) then
                    i.ammo2 = ammo[i.ammoType2]/ammoCounts[i.ammoType2]
                end
            end
            ang.y = ang.y + rot
        end
    end
end)

hook.Add("OnNPCKilled", "NPCDeath", function(npc, attacker, inflictor)
    if (GetConVar("mcitem_npc_deathdrop"):GetBool()) then
        if (npc.GetActiveWeapon == nil) then -- some NPC someone reported doesn't have this method???
            return
        end
        if (IsValid(npc:GetActiveWeapon())) then
            local i = MCDropWeapon(npc:GetActiveWeapon(), npc:GetPos()+npc:OBBCenter(), Angle(-45, math.Rand(-180, 180), 0):Forward()*0.6)
            i.ttl = GetConVar("mcitem_deathdrops_time"):GetFloat()
        end
    end
end)



hook.Add("ShouldCollide", "MCShouldCollide", function(ent1, ent2)
    if (ent1:GetClass() == "sent_mcitem" or ent2:GetClass() == "sent_mcitem") then
        if (ent1:GetClass() == "player" or ent2:GetClass() == "player") then
            return false
        end
    end
    if (ent1:GetClass() == "sent_mcitem" and ent2:GetClass() == "sent_mcitem") then
        return false
    end
end)