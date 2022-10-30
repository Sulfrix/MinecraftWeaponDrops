
AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Minecraft Item"
ENT.Author = "Sulfrix"
ENT.Information = "A dropped item, like Minecraft."
ENT.Category = "Minecraft"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

CacheNPCs = {} -- turns out looping through all entities is a bad idea!


function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Item")
    self:NetworkVar("Bool", 0, "Picked")
    self:NetworkVar("Float", 0, "PickedTime")
    self:NetworkVar("Entity", 1, "PickedEnt")
end

function ENT:SpawnFunction( ply, tr, ClassName )

	if ( !tr.Hit ) then return end

	local ent = ents.Create( ClassName )
	ent:SetPos( tr.HitPos + tr.HitNormal * 10 )
	ent:Spawn()
	ent:Activate()
    --ent:SetType(2)
    --ent:SetExpireAt(CurTime() + 5)
    
	return ent
    
end

if (CLIENT) then
    mdl = ClientsideModel("models/Items/car_battery01.mdl")
    mdl:SetNoDraw(true)
end

function ENT:Initialize()

    self:DrawShadow(false)

    if (IsValid(self:GetItem())) then
        local i = self:GetItem()
        --self:GetItem():SetNoDraw(true)
        i:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        if (SERVER) then
            i:GetTable().noPickup = true
            i:SetLocalPos(Vector(0, 0, 0))
            i:SetAngles(Angle(0, 0, 0))
            i:DrawShadow(false)
        end
    end
    
	if (CLIENT) then
        self.shadowsize = 8
        return
    end
	self:SetModel( "models/Items/car_battery01.mdl" )
    
    
	local size = 10
	self:PhysicsInitBox(Vector(-4, -4, -4), Vector(4, 4, 4)) 

    --self:SetMoveType(MOVETYPE_NONE)


    
	self:PhysWake()
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    self:GetPhysicsObject():SetMaterial("player")

    self:SetUseType(SIMPLE_USE)



end

local pickupTime = 0.15

function ENT:Think()
	if (CLIENT) then 
		self:SetAngles(Angle(0, 0, 0))
		return 
	end
    if (!IsValid(self:GetItem())) then
        self:Remove()
        return
    end
	local prevel = self:GetPhysicsObject():GetVelocity()
    self:SetAngles(Angle(0, 0, 0)) -- For some reason SetAngles also resets the physics object's velocity, *but only on a dedicated server??* WTF?
	if (prevel:Length() < 10) then
		self:GetPhysicsObject():SetVelocity(Vector(0, 0, 0))
	else
		self:GetPhysicsObject():SetVelocity(prevel)
	end
    --self:SetPos(self:GetPos()+self:GetVelocity())

    if (IsValid(self:GetItem())) then
        self:GetItem():SetLocalPos(Vector(0, 0, 0))
    end

    if (self.ttl == nil or self.ttl <= 0) then
        self.ttl = 10
    end
    if (CurTime() - self:GetCreationTime() > self.ttl) then
        
        if (IsValid(self:GetItem())) then
            self:GetItem():Remove()
        end
        self:Remove()
    end


    if (!self:GetPicked()) then
        for k, ply in ipairs(player.GetAll()) do
            -- DistToSqr used for performance
            if (self:GetPos():DistToSqr(ply:GetPos()) < 50*50 and CurTime() - self:GetCreationTime() > 1 and !GetConVar("mcitem_manualpickup"):GetBool()) then
                self:Pick(ply)
            end
        end

        local npcusable = false or GetConVar("mcitem_npc_pickup"):GetInt() == 2

        for k, v in ipairs(list.Get("NPCUsableWeapons")) do
            if v.class == self:GetItem():GetClass() then
                npcusable = true
                break;
            end
        end

       -- PrintTable(CacheNPCs)
        if (GetConVar("mcitem_npc_pickup"):GetBool() and npcusable and CurTime() - self:GetCreationTime() > 1) then
            for k, npc in ipairs(CacheNPCs) do
                -- DistToSqr used for performance
                if (IsValid(npc)) then
                    if (self:GetPos():DistToSqr(npc:GetPos()) < 50*50 and !npc.isPickingUp) then
                        self:Pick(npc)
                    end
                else
                    table.remove(CacheNPCs, k)
                    k = k - 1
                end
                
            end
        end
        
    else
        if (CurTime() - self:GetPickedTime() >= pickupTime) then
            local i = self:GetItem()
            local ply = self:GetPickedEnt()
            if (ply:IsPlayer()) then
                if (self.ammoType1 ~= nil and self.ammo1 ~= nil) then
                    ply:GiveAmmo(self.ammo1, self.ammoType1, true)
                end
                if (self.ammoType2 ~= nil and self.ammo2 ~= nil) then
                    ply:GiveAmmo(self.ammo2, self.ammoType2, true)
                end
                if (GetConVar("mcitem_autoequip"):GetInt() ~= 0) then
                    i.noSwitch = true
                    ply:PickupWeapon(i)
                    i.noSwitch = false
                else
                    ply:PickupWeapon(i)
                end
                if (GetConVar("mcitem_autoequip"):GetInt() == 1) then
                    ply:SelectWeapon(i:GetClass())
                end
            else
                ply:PickupWeapon(i)
                ply.isPickingUp = false
            end
            
            self:Remove()
        end
    end

    if (FrameTime() < 0.032) then
        self:NextThink( CurTime() )
        return true 
    else
        self:NextThink( CurTime() + 5 ) -- Server overloaded, reduce item ticking
        return true 
    end
end

function ENT:Use( activator )

    if (GetConVar("mcitem_manualpickup"):GetBool()) then
        self:Pick(activator)
    end

end

function ENT:Pick(ply)
    local hasWeap = false
    local alive = false
    if (ply:IsPlayer()) then
        hasWeap = ply:HasWeapon(self:GetItem():GetClass())
        alive = ply:Alive()
    elseif (ply:IsNPC()) then
        hasWeap = IsValid(ply:GetActiveWeapon())
        alive = ply:Health() > 0
    end
    if (alive and IsValid(self:GetItem()) and !hasWeap and !self:GetPicked()) then
        self:SetPicked(true)
        self:SetPickedTime(CurTime())
        self:SetPickedEnt(ply)
        self:EmitSound("pop.ogg", 75, math.Rand(140, 180), 1, CHAN_ITEM, 0, 0)
        if (ply:IsNPC()) then
            ply.isPickingUp = true
        end
    end
end

function MCDropWeapon(ent, pos, dir)
    if (IsValid(ent:GetOwner())) then
        ent:GetOwner():DropWeapon(ent)
        ent:SetOwner()
    end

    local i = ents.Create("sent_mcitem")
    ent:SetParent(i)
    ent:SetLocalPos(Vector(0, 0, 0))
    ent:SetAngles(Angle(0, 0, 0))
    i:SetPos(pos)
    i:SetItem(ent)
    i:Spawn()
    i:GetPhysicsObject():SetVelocity(dir*200)
    return i
end

function MCDropEyes(ply)
    local weap = ply:GetActiveWeapon()
    if (IsValid(weap)) then
        local i = MCDropWeapon(weap, ply:EyePos(), ply:EyeAngles():Forward())
        i.ttl = GetConVar("mcitem_manualdrops_time"):GetFloat()
    end
end

function ENT:PickedMatrix()
    if (!self:GetPicked()) then
        return nil
    end
    local m = Matrix()
    local frac = (CurTime()-self:GetPickedTime())/pickupTime
    if (frac > 1) then
        m:Translate(Vector(10000, 1000, 100)) -- too lazy to have a proper way of hiding the weapon
    end
    frac = frac * frac
    local useMid = Vector(self.lastMid)
    useMid:Rotate(self.lastAngles)
    local pos = LerpVector(frac, self.lastPos, self:GetPickedEnt():OBBCenter()+self:GetPickedEnt():GetPos()-useMid)
    self.shadowFrom = pos
    --pos = self:GetPickedEnt():OBBCenter()+self:GetPickedEnt():GetPos()
    m:Translate(pos-self:GetPos())
    m:Rotate(self.lastAngles)
    return m
end

function ENT:Draw()


    if (self.offset == nil) then self.offset = math.random(100) end
    
    local t = (SysTime() - self:GetCreationTime()) + self.offset
    
    
    local m = Matrix()


    self.shadowfrom = self.lastPos
    
    
    --self:DrawModel()


    if (!IsValid(self:GetItem())) then
        local trans = Vector(0, 0, 6+math.sin(t*2)*4)
        self.lastPos = self:GetPos()+trans
        m:Translate(trans)
        local rot = Angle(0, t*45, 0)
        self.lastAngles = rot
        m:Rotate(rot)
        --gself:EnableMatrix("RenderMultiply", m)
        --self:DrawModel()
    else
        local i = self:GetItem()

        if (!self:GetPicked()) then
            local mins, maxs = i:GetModelBounds()
            if (maxs == nil) then maxs = 0 end
            if (mins == nil) then mins = 0 end
            local total = maxs - mins
            local target = 32
            local largest = math.max(total.x, total.y, 0)
            local scale = target/largest
            local mid = (maxs + mins)/2
            self.shadowsize = math.max(8, largest/3)

            --render.DrawBox(self:GetPos(), Angle(0, 0, 0),  mins, maxs)

            local trans = Vector(0, 0, (total.z/2+3)+math.sin(t*2)*4)
            self.lastPos = self:GetPos()+trans
            m:Translate(trans)
            --m:Scale(Vector(scale, scale, scale))
            local rot = Angle(0, t*45, 0)
            self.lastAngles = rot
            m:Rotate(rot)
            m:Translate(-mid)
            self.lastMid = mid
            self.lastPos = self:GetPos()+m:GetTranslation()
            --m:Translate(Vector(50, 0, 0))
        else
            m = self:PickedMatrix()
        end

        local usepos = self:GetPos()

        if (true) then
            local mid = Vector(self.lastMid)
            mid:Rotate(self.lastAngles)
            usepos = self:GetPos()+m:GetTranslation()+mid
        end

        if (RealFrameTime() < 0.1) then
            local tr = util.TraceLine( {
                start = usepos,
                endpos = usepos + Vector(0, 0, -64),
                filter = {self},
                collisiongroup = COLLISION_GROUP_WEAPON
            })
            
            if (tr.Hit and (CurTime() - self:GetCreationTime()) > 0.2) then
                local opac = 1 - tr.Fraction
                local shadowAngle = tr.HitNormal:Angle()
                shadowAngle:RotateAroundAxis(shadowAngle:Right(), -90)
                cam.Start3D2D(tr.HitPos+(tr.HitNormal*0.1), shadowAngle, 1)
                drawCircle(0, 0, self.shadowsize, 16, Color(0, 0, 0, 200*opac))
                cam.End3D2D()
            end
        end
        

        i:SetRenderOrigin(self:GetPos()+m:GetTranslation())
        i:SetRenderAngles(m:GetAngles())
        --i:EnableMatrix("RenderMultiply", m)
        --i:SetupBones()
        --i:DrawModel()
    end
    
    
    mdl:SetPos(self:GetPos()+Vector(0, 0, 6+math.sin(t*2)*4))
    mdl:SetAngles(Angle(0, t*45, 0))
    mdl:SetupBones()
    --mdl:DrawModel()
end

if (SERVER) then
    hook.Add("OnEntityCreated", "MCNPCSpawn", function(ent)
        if (IsValid(ent)) then
            if (ent:IsNPC()) then
                table.insert(CacheNPCs, ent)
            end
        end
    end)
end

function drawCircle(x, y, r, d, color)
    local verts = {}
    --surface.SetDrawColor(255, 0, 0, 255)
    --table.insert(verts, -1, {x = x, y = y})
    for i=0,d+1 do
      local step = (math.pi*2)/d
      local newVert = {x = math.cos(i*step)*r+x, y = math.sin(i*step)*r+y}
      table.insert(verts, #verts, newVert)
      --surface.DrawRect(newVert.x-2, newVert.y-2, 4, 4)
    end
    draw.NoTexture()
    surface.SetDrawColor(color)
    surface.DrawPoly(verts)
  end

function ENT:OnTakeDamage( dmginfo )
end


if ( SERVER ) then return end -- We do NOT want to execute anything below in this FILE on SERVER
