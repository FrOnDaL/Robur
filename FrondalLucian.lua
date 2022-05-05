if Player.CharName ~= "Lucian" then
    return false
end

module("Frondal Lucian", package.seeall, log.setup)
clean.module("Frondal Lucian", clean.seeall, log.setup)
local _VER, _LASTMOD = "1.0.0", "04.05.2022"
--CoreEx.AutoUpdate("https://raw.githubusercontent.com/FrOnDaL/Robur/main/FrondalLucian.lua", _VER)

local Utils = {}
local Lucian = {}

local spells = {
    Q = _G.Libs.Spell.Targeted({
        Slot = _G.CoreEx.Enums.SpellSlots.Q,
        Range = 620,
    }),
    QExt = _G.Libs.Spell.Skillshot({
        Slot = _G.CoreEx.Enums.SpellSlots.Q,
        Range = 1000,
        Delay = 0.35,
        Speed = 1600,
        Radius = 25,
        Type = "Linear",
        UseHitbox = true
    }),
    W = _G.Libs.Spell.Skillshot({
        Slot = _G.CoreEx.Enums.SpellSlots.W,
        Range = 950,
        Delay = 0.3,
        Speed = 1600,
        Radius = 80,
        Type = "Linear",
        Collisions = { Heroes = true, Minions = true, WindWall = true },
        UseHitbox = true
    }),
    E = _G.Libs.Spell.Skillshot({
        Slot = _G.CoreEx.Enums.SpellSlots.E,
        Range = 1000,
        Type = "Linear",
        DashTime = 0.4,
    }),
    R = _G.Libs.Spell.Skillshot({
        Slot = _G.CoreEx.Enums.SpellSlots.R,
        Range = 1200,
        Delay = 0.1,
        Speed = 2500,
        Radius = 110,
        Type = "Linear",
        Collisions = { Heroes = true, Minions = true, WindWall = true },
    }),
}

local function GetNearbyHeroesAndTurrets(pos, range)
    local heroList, closestTurret = {}, nil
    for k, v in pairs(_G.CoreEx.ObjectManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero:Distance(pos) < range and hero.IsTargetable then
            table.insert(heroList, hero)
        end
    end

    for k, v in pairs(_G.CoreEx.ObjectManager.Get("enemy", "turrets")) do
        local turret = v.AsTurret
        if turret and turret.IsAlive and turret:Distance(pos) < (900+range) then
            closestTurret = turret
        end
    end
    return heroList, closestTurret
end

local function IsSafePosition(pos, heroList, nearbyTurret)
    local pPos = Player.Position
    if not heroList then
        heroList, nearbyTurret = GetNearbyHeroesAndTurrets(pos, 400)
    end

    if nearbyTurret and pos:Distance(nearbyTurret) <= 900 and pPos:Distance(nearbyTurret) >= 900 then
        return false
    end

    for k, hero in ipairs(heroList) do
        local dist = hero:Distance(pos)
        if dist < 400 and dist <= hero:Distance(pPos) then
            return false
        end
    end
    return true
end


function Lucian.Combo()
    if not Player:GetBuff("LucianPassiveBuff") then

        if _G.Libs.NewMenu.Get("EOn") and spells.E:GetTarget() and Player:Distance(spells.E:GetTarget()) < _G.Libs.NewMenu.Get("ERange") and spells.E:IsReady() then

            local ePos, skipSafety = nil, nil
            
            if _G.Libs.NewMenu.Get("EMode") == 0 then

                ePos, skipSafety = Lucian.GetBestEPos()

            elseif _G.Libs.NewMenu.Get("EMode") == 1 then

                ePos = _G.CoreEx.Renderer.GetMousePos()

            elseif _G.Libs.NewMenu.Get("EMode") == 2 then

                ePos = Lucian.GetPosE()            

            end

            if ePos and (skipSafety or IsSafePosition(ePos)) then

                spells.E:Cast(ePos)

            elseif _G.Libs.NewMenu.Get("EMode") == 3 then

                spells.E:Cast(spells.E:GetTarget())

            end

        end

        if _G.Libs.NewMenu.Get("QOn") and spells.Q:GetTarget() and spells.Q:IsReady() and spells.Q:IsInRange(spells.Q:GetTarget()) then

            spells.Q:Cast(spells.Q:GetTarget())

        end

        if _G.Libs.NewMenu.Get("WOn") and spells.W:GetTarget() and Player:Distance(spells.W:GetTarget()) < _G.Libs.NewMenu.Get("WRange") and spells.W:IsReady()  then

            spells.W:CastOnHitChance(spells.W:GetTarget(), _G.Libs.NewMenu.Get("WHit") / 100)

        end

        

    end
end


function Lucian.GetBestEPos()
    local pPos = Player.Position
    local qTarget = _G.Libs.TargetSelector():GetTarget(1000, true)
    if not qTarget then return end
    local peelPos = Lucian.GetPosE()
    if peelPos then return peelPos, true end
end


function Lucian.GetPosE()    
    local pPos = Player.Position
    local heroList, nearbyTurret = GetNearbyHeroesAndTurrets(pPos, 1000)

    for k, hero in ipairs(heroList) do
        if hero:Distance(pPos) < _G.Libs.NewMenu.Get("ERange") then
            local ePred = hero:FastPrediction(spells.E.DashTime)
            local aaRange = _G.Libs.TargetSelector():GetTrueAutoAttackRange(Player, hero)
            local safeDist = math.min(aaRange * 0.85, pPos:Distance(ePred)+300)



            local safePos = Lucian.GetBestSafeCircle(pPos, 450, ePred, safeDist, heroList, nearbyTurret)
            if safePos then
                return safePos
            end
        end
    end
end

function Lucian.GetBestSafeCircle(c1, r1, c2, r2, heroList, nearbyTurret)
    local points = _G.CoreEx.Geometry.CircleCircleIntersection(c1, r1, c2, r2)

    if #points == 2 then
        if not heroList then
            heroList, nearbyTurret = GetNearbyHeroesAndTurrets(c1, 400 + r1)
        end
        local safe1 = IsSafePosition(points[1], heroList, nearbyTurret)
        local safe2 = IsSafePosition(points[2], heroList, nearbyTurret)

        if safe1 and safe2 then
            local mousePos = _G.CoreEx.Renderer.GetMousePos()
            return (points[1]:Distance(mousePos) < points[2]:Distance(mousePos) and points[1]) or points[2]
        elseif safe1 then
            return points[1]
        elseif safe2 then
            return points[2]
        end
    end
end

function Utils.GetTargetableUnit(Range, Position)

    local totalTable = {}
    local table = _G.CoreEx.ObjectManager.Get("all", "minions")
    for _, minion in pairs(table) do
        minion = minion.AsAI
        if minion and minion.IsTargetable then
            local dist = Position:Distance(minion.Position)
            if dist < Range then
                totalTable[#totalTable+1] = minion
            end
        end
    end

  return totalTable
end


function Lucian.ExtendedQ()

    if not spells.QExt:GetTarget() then
        return false
    end

    local TrueRange = spells.Q.Range +  _G.CoreEx.ObjectManager.Player.AsHero.BoundingRadius + spells.QExt:GetTarget().BoundingRadius

    local Rect = _G.CoreEx.Geometry.Rectangle(_G.CoreEx.ObjectManager.Player.AsHero.Position, spells.QExt:GetTarget().Position, 25)

    if _G.Libs.NewMenu.Get("QOnExt") and spells.Q:IsReady() and (Player.Mana / Player.MaxMana) * 100 > _G.Libs.NewMenu.Get("QExtMana")  then
        local Minions = Utils.GetTargetableUnit(TrueRange, _G.CoreEx.ObjectManager.Player.AsHero.Position)

        for _, Minion in ipairs(Minions) do
            if Rect:Contains(Minion.Position) and Rect:Contains(spells.QExt:GetTarget().Position) then
                return spells.Q:Cast(Minion)
            end
        end
        return false
    end

    return false
end


function Lucian.LaneClear()

    if not Player:GetBuff("LucianPassiveBuff") and (Player.Mana / Player.MaxMana) * 100 > _G.Libs.NewMenu.Get("LaneMana") then

        local minions = _G.CoreEx.ObjectManager.GetNearby("enemy", "minions")

        if spells.Q:IsReady() and _G.Libs.NewMenu.Get("QLane") then
            for i, obj in ipairs(minions) do
                if obj.IsTargetable and spells.Q:IsInRange(obj.Position) then
                    local rect = _G.CoreEx.Geometry.Rectangle(_G.CoreEx.ObjectManager.Player.AsHero.Position, obj.Position:Extended(Player.Position, -spells.Q.Range), 55)
                    for j, obj2 in ipairs(minions) do
                        if i ~= j and obj.IsTargetable and rect:Contains(obj2.Position) then
                            if spells.Q:Cast(obj) then
                                return
                            end
                        end
                    end                    
                end
            end
        end
        if spells.W:IsReady() and _G.Libs.NewMenu.Get("WLane") then
            if spells.W:CastIfWillHit(2, "minions") then
                return
            end
        end
        if spells.E:IsReady() and _G.Libs.NewMenu.Get("ELane") then
            
            for i, obj in ipairs(minions) do
                if obj.IsTargetable and spells.Q:IsInRange(obj.Position) then

                    for j, obj2 in ipairs(minions) do
                        if i ~= j and obj.IsTargetable then
                            if spells.E:Cast(_G.CoreEx.Renderer.GetMousePos()) then
                                return
                            end
                        end
                    end                    
                end
            end

        end
    end

end

function Lucian.JungClear()

    if not Player:GetBuff("LucianPassiveBuff") and (Player.Mana / Player.MaxMana) * 100 > _G.Libs.NewMenu.Get("JungMana") then

        local JungMinions = _G.CoreEx.ObjectManager.GetNearby("neutral", "minions")

        if spells.Q:IsReady() and _G.Libs.NewMenu.Get("QJung") then



            for iJung, objJung in ipairs(JungMinions) do

                local monster = objJung.AsMinion

                if monster and spells.Q:IsInRange(monster) and monster.IsAlive then
                        
                    if spells.Q:Cast(monster) then
                        return
                    end
                        
                end
            end
            
        end

        if spells.W:IsReady() and _G.Libs.NewMenu.Get("WJung") then
            for iJung, objJung in ipairs(JungMinions) do

                local monster = objJung.AsMinion

                if monster and spells.Q:IsInRange(monster) and monster.IsAlive then
                 
                
                    if spells.W:Cast(monster.Position) then
                        return
                    end
                        
                end
            end
        end

        if spells.E:IsReady() and _G.Libs.NewMenu.Get("EJung") then
            
            for iJung, objJung in ipairs(JungMinions) do

                local monster = objJung.AsMinion

                if monster and spells.Q:IsInRange(monster) and monster.IsAlive then
                 
                
                    if spells.E:Cast(_G.CoreEx.Renderer.GetMousePos()) then
                        return
                    end
                        
                end
            end

        end
    end

end

function Lucian.OnPreAttack(args)
end

local lastTick = 0
function Lucian.OnTick()

    if _G.CoreEx.Game.GetTime() < (lastTick + 0.25) or (_G.CoreEx.Game.IsChatOpen() or _G.CoreEx.Game.IsMinimized() or Player.IsDead or Player.IsRecalling) then
        return
    end
    lastTick = _G.CoreEx.Game.GetTime()

    

    if _G.Libs.Orbwalker.GetMode() == "Combo" then

        if not Player:GetBuff("LucianR") then
            Lucian.Combo()
        end

    elseif _G.Libs.Orbwalker.GetMode() == "Waveclear" then

        Lucian.ExtendedQ()

        if _G.Libs.NewMenu.Get("LaneOn") then
            Lucian.LaneClear()
        end
        

        Lucian.JungClear()

    end

    if _G.Libs.NewMenu.Get("ROn") then

        _G.Libs.Orbwalker.Orbwalk(_G.CoreEx.Renderer.GetMousePos(), nil)

        if spells.R:GetTarget() and spells.R:IsReady() and spells.R:IsInRange(spells.R:GetTarget()) and not Player:GetBuff("LucianR") then

            spells.R:CastOnHitChance(spells.R:GetTarget(), _G.Libs.NewMenu.Get("RHit") / 100)

        end

    end
    
end

-- LucianR, LucianPassiveBuff
-- function Lucian.OnBuffGain(obj, buffInst)
--     if obj and buffInst then
--         if obj.IsHero then
--             INFO("Buff Name: " .. buffInst.Name)
--         end
--     end
-- end


function Lucian.OnDraw()

    if Player.IsDead then
        return
    end

    if _G.Libs.NewMenu.Get("LaneOn") then
        _G.CoreEx.Renderer.DrawTextOnPlayer("Lane Clear: On", 0xFFD166FF)
    else
        _G.CoreEx.Renderer.DrawTextOnPlayer("Lane Clear: Off", 0xFFD166FF)
    end

    if _G.Libs.NewMenu.Get("QDraw", true) then
        _G.CoreEx.Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 2, _G.Libs.NewMenu.Get("QDrawC"))
    end

    if _G.Libs.NewMenu.Get("EDraw", true) then
        _G.CoreEx.Renderer.DrawCircle3D(Player.Position, _G.Libs.NewMenu.Get("ERange"), 30, 2, _G.Libs.NewMenu.Get("EDrawC"))
    end

    if _G.Libs.NewMenu.Get("WDraw", true) then
        _G.CoreEx.Renderer.DrawCircle3D(Player.Position, _G.Libs.NewMenu.Get("WRange"), 30, 2, _G.Libs.NewMenu.Get("WDrawC"))
    end

    if _G.Libs.NewMenu.Get("RDraw", true) then
        _G.CoreEx.Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 2, _G.Libs.NewMenu.Get("RDrawC"))
    end

end


function Lucian.LoadMenu()
    _G.Libs.NewMenu.RegisterMenu("FrondalLucian", "Frondal Lucian", function()

        _G.Libs.NewMenu.Text("Author: Frondal - Version: " .. _VER .. " - Last Update: " .. _LASTMOD, true)

        _G.Libs.NewMenu.NewTree("frCombo", "Combo", function()
            _G.Libs.NewMenu.NewTree("QSet", "[Q] Settings", function()
                _G.Libs.NewMenu.Checkbox("QOn", "[Q] Enable", true)
                _G.Libs.NewMenu.Checkbox("QOnExt", "[Q] Enabled Extended (if the lane is clear 'V')", true)
                _G.Libs.NewMenu.Slider("QExtMana", "[Q] Extended Min Mana", 60, 0, 100, 1)
            end)
            _G.Libs.NewMenu.NewTree("WSet", "[W] Settings", function()
                _G.Libs.NewMenu.Checkbox("WOn", "[W] Enable", true)
                _G.Libs.NewMenu.Slider("WHit", "[W] Hitchance", 20, 1, 100, 1)
                _G.Libs.NewMenu.Slider("WRange", "[W] Range", 800, 600, 1000, 1)
            end)
            _G.Libs.NewMenu.NewTree("ESet", "[E] Settings", function()
                _G.Libs.NewMenu.Checkbox("EOn", "[E] Enable", true)
                _G.Libs.NewMenu.Dropdown("EMode", "[E] Mode", 0, {"Safe Position", "To Mouse", "Kiting Only", "To Target Enemy"}) 
                _G.Libs.NewMenu.Slider("ERange", "[E] Range", 850, 600, 1000, 1)
            end)
            _G.Libs.NewMenu.NewTree("RSet", "[R] Settings", function()
                _G.Libs.NewMenu.Keybind("ROn", "[R] Enable Key", string.byte('T'), false, false, true)
                _G.Libs.NewMenu.Slider("RHit", "[R] Hitchance", 20, 1, 100, 1)
            end)
            _G.Libs.NewMenu.NextColumn()
        end)

        _G.Libs.NewMenu.NewTree("frLane", "Lane Clear", function()

            _G.Libs.NewMenu.Checkbox("QLane",  "[Q] Use Lane Clear")
            _G.Libs.NewMenu.Checkbox("WLane",  "[W] Use Lane Clear")
            _G.Libs.NewMenu.Checkbox("ELane",  "[E] Use Lane Clear (Mouse position)")
            _G.Libs.NewMenu.Slider("LaneMana", "Lane Min Mana", 60, 0, 100, 1)
            _G.Libs.NewMenu.Keybind("LaneOn", "Lane Clear Enable", string.byte("N"), true, true, false)  
            _G.Libs.NewMenu.NextColumn()
        end)

        _G.Libs.NewMenu.NewTree("frJung", "Jung Clear", function()

            _G.Libs.NewMenu.Checkbox("QJung",  "[Q] Use Jung Clear", true)
            _G.Libs.NewMenu.Checkbox("WJung",  "[W] Use Jung Clear", true)
            _G.Libs.NewMenu.Checkbox("EJung",  "[E] Use Jung Clear (Mouse position)", true)
            _G.Libs.NewMenu.Slider("JungMana", "Jung Min Mana", 40, 0, 100, 1)

            _G.Libs.NewMenu.NextColumn()
        end)

        _G.Libs.NewMenu.NewTree("frDraw", "Draw Options", function()

            _G.Libs.NewMenu.ColoredText("Draw Options", 0x118AB2FF, true)
            _G.Libs.NewMenu.Checkbox("QDraw",  "Draw [Q] Range")
            _G.Libs.NewMenu.ColorPicker("QDrawC", "Draw [Q] Color", 0x118AB2FF)
            _G.Libs.NewMenu.Checkbox("WDraw",  "Draw [W] Range")
            _G.Libs.NewMenu.ColorPicker("WDrawC", "Draw [W] Color", 0x118AB2FF)
            _G.Libs.NewMenu.Checkbox("EDraw",  "Draw [E] Range", true)
            _G.Libs.NewMenu.ColorPicker("EDrawC", "Draw [E] Color", 0x118AB2FF)
            _G.Libs.NewMenu.Checkbox("RDraw",  "Draw [R] Range", true)
            _G.Libs.NewMenu.ColorPicker("RDrawC", "Draw [R] Color", 0x118AB2FF)

            _G.Libs.NewMenu.NextColumn()
        end)

    end)
end

function OnLoad()
    Lucian.LoadMenu()

    for eventName, eventId in pairs(_G.CoreEx.Enums.Events) do
        if Lucian[eventName] then
            _G.CoreEx.EventManager.RegisterCallback(eventId, Lucian[eventName])
        end
    end
    return true
end