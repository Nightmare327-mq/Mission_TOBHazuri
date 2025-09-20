-- Mission_TOBHazuri
-- Version 1.2
-- TODO: Implement bc support if asked for
-- TODO: Inmplement RGMercs.lua support if asked for (it has been)
-- TODO: Make the  writiing of an ini for run parameters optional, and off by default
---------------------------
local mq = require('mq')
LIP = require('lib.LIP')
Logger = require('utils.logger')
C = require('utils/common')

-- #region Variables
Logger.set_log_level(4) -- 4 = Info level, use 5 for debug, and 6 for trace
-- local DEBUG = true
Zone_name = mq.TLO.Zone.ShortName()
Task_Name = 'Brood Architect Hazuri'

local command = 0
local Ready = false
local my_class = mq.TLO.Me.Class.ShortName()
local request_zone = 'toe'
local request_npc = 'Alchemist Balino'
local request_phrase = 'group'
local zonein_phrase = 'ready'
local quest_zone = 'harbingerscradle_mission'
local delay_before_zoning = 27000  -- 27s

Settings = {
    general = {
        GroupMessage = "dannet",    -- or "bc" - not yet implemented
        BestForLast = true,         -- true if you want to do this achievement during the run, false if you will skip it and kill the Replicants as they spawn
        OpenChest = false,          -- true if you want to open the chest automatically at the end of the mission run
        Automation = 'CWTN',        -- automation method, 'CWTN' fro the CWTN plugins, or 'rgmercs' for the rgmercs lua automation.  KissAssist is not really supported currenlty, though it might work
    }
}
-- #endregion

Load_settings()

if (Settings.general.GroupMessage == 'dannet') then
   Logger.info('\aw Group Chat: \ayDanNet\aw.')
elseif (Settings.general.GroupMessage == 'bc') then
   Logger.info('\aw Group Chat: \ayBC\aw.')
else
   Logger.info("Unknown or invalid group command.  Must be either 'dannet' or 'bc'. Ending script. \ar%s", Settings.general.GroupMessage)
   return
end

Logger.info('\aw Automation: \ay%s', Settings.general.Automation)
Logger.info('\aw Open Chest: \ay%s', Settings.general.OpenChest)
Logger.info('\aw Best For Last: \ay%s', Settings.general.BestForLast)

if my_class ~= 'WAR' and my_class ~= 'SHD' and my_class ~= 'PAL' then 
	Logger.info('You must run the script on a tank class...')
	os.exit()
end
mq.cmdf('/%s pause on', my_class)

if Zone_name == request_zone then 
	if mq.TLO.Spawn(request_npc).Distance() > 40 then 
		Logger.info('You are in %s, but too far away from %s to start the mission!  We will attempt to double-invis and run to the mission npc', request_zone, request_npc)
        DBLinvis()
        MoveToAndSay(request_npc, request_phrase)
    end
    local task = Task(Task_Name, request_zone, request_npc, request_phrase)
    WaitForTask(delay_before_zoning)
    ZoneIn(request_npc, zonein_phrase, quest_zone)
    mq.delay(5000)
    local allinzone = WaitForGroupToZone(60)
    if allinzone == false then
        Logger.info('Timeout while waiting foe everyone to zone in.  Please check what is happening and restart the script')
        os.exit()
    end
end

Zone_name = mq.TLO.Zone.ShortName()

if Zone_name ~= quest_zone then 
	Logger.info('You are not in the mission...')
	os.exit()
end

-- Check group mana / endurance / hp
while Ready == false do 
	Ready = CheckGroupStats()
	mq.cmd('/noparse /dgga /if (${Me.Standing}) /sit')
	mq.delay(5000)
end

-- in case you are starting the script after you reach teh camp spot
if math.abs(mq.TLO.Me.Y() + 286) > 15 or math.abs(mq.TLO.Me.X() + 282) > 15 then
    Logger.info('Doing some setup. Invising and moving to spot.')

    DBLinvis()

    mq.delay(10000)

    -- Nav in 2 steps to avoid mobs if at all possible
    mq.cmd('/squelch /dgga /nav locyx -50 152 log=off')
    WaitForNav()

    mq.cmd('/squelch /dgga /nav locyx -286 -282 log=off')
    WaitForNav()
end

Logger.info('Doing some setup...')

mq.delay(2000)

DoPrep()

Logger.info('Starting the event in 10 seconds!')

mq.delay(10000)

mq.cmd('/squelch /nav locyx -240 50 log=off')
WaitForNav()

MoveToAndSay('Atathus', 'fight')

mq.cmdf('/%s gotocamp', my_class)

-- This section was waiting till all the starting adds were killed to do thwe rest of the script
while mq.TLO.SpawnCount("Hazuri xtarhater")() < 1 do
    if (mq.TLO.SpawnCount('unmodified experiment npc radius 60')() > 0) then
        Logger.debug('experiment Attack branch...')
        MoveToTargetAndAttack('unmodified experiment')
    end
	mq.delay(1000)
end

local event_zoned = function(line)
    -- zoned so quit
    command = 1
end

local event_failed = function(line)
    -- failed so quit
    command = 1
end

mq.event('Zoned','LOADING, PLEASE WAIT...#*#',event_zoned)
mq.event('Failed','#*#summons overwhelming enemies and your mission fails.#*#',event_failed)

while true do
	mq.doevents()

	if command == 1 then
        break
	end

	if mq.TLO.SpawnCount('_chest')() == 1 then
		Logger.info('I see the chest! You won!')
		break
	end

    if (mq.TLO.SpawnCount('Brood Architect Hazuri npc')() > 0 and mq.TLO.Spawn('Brood Architect Hazuri').PctHPs() < 10 and mq.TLO.SpawnCount('Hazuri Replicant npc')() == 0) then 
        Logger.debug('Brood Architect Hazuri Attack branch at end...')
        MoveToTargetAndAttack('Brood Architect Hazuri')
	elseif (mq.TLO.SpawnCount('An altered artificer npc')() + mq.TLO.SpawnCount('An altered skyguard npc')() 
		+ mq.TLO.SpawnCount('An altered overseer npc')() + mq.TLO.SpawnCount('An altered striker npc')()  > 0)
		or (mq.TLO.SpawnCount('Hazuri Replicant npc')() > 0 and mq.TLO.Spawn('Brood Architect Hazuri').PctHPs() < 10)
		then 
		--Logger.debug('In AddsUp section')
		if mq.TLO.SpawnCount('Brood Architect Hazuri npc')() > 0 and mq.TLO.Spawn('Brood Architect Hazuri').PctHPs() < 10 and mq.TLO.SpawnCount('Hazuri Replicant npc radius 60')() > 0 then 
			Logger.debug('Hazuri < 10 Replicant Attack branch...')
            -- mq.cmd('/hidecorpse npc') -- temporary solution to hide Hazuri corpse
            MoveToTargetAndAttack('Hazuri Replicant')
        elseif mq.TLO.SpawnCount('Hazuri Replicant npc radius 60')() > 0 and Settings.general.BestForLast == false then 
			Logger.debug('Replicant No BestForLast branch...')
            MoveToTargetAndAttack('Hazuri Replicant')
        elseif mq.TLO.SpawnCount('An altered artificer npc radius 60')() > 0 then 
			-- Logger.debug('artificer Attack branch...')
            MoveToTargetAndAttack('An altered artificer')
		elseif mq.TLO.SpawnCount('An altered skyguard npc radius 60')() > 0 then 
			-- Logger.debug('skyguard Attack branch...')
            MoveToTargetAndAttack('An altered skyguard')
		elseif mq.TLO.SpawnCount('An altered striker npc radius 60')() > 0 then 
			-- Logger.debug('striker Attack branch...')
			MoveToTargetAndAttack('An altered striker')
		elseif mq.TLO.SpawnCount('An altered overseer npc radius 60')() > 0 then 
			-- Logger.debug('overseer Attack branch...')
			MoveToTargetAndAttack('An altered overseer')
		else  
			StopAttack()
		end
	else
        if mq.TLO.SpawnCount('Brood Architect Hazuri npc')() > 0 then 
            Logger.debug('Brood Architect Hazuri Attack branch...')
            MoveToTargetAndAttack('Brood Architect Hazuri') 
        end
	end

    if mq.TLO.Target() ~= nil then 
        if mq.TLO.Target.Distance() > 20 then
            mq.cmd('/squelch /nav target distance=20 log=off') 
            WaitForNav()
        end
    end
			
	if math.abs(mq.TLO.Me.Y() + 286) > 15 or math.abs(mq.TLO.Me.X() + 282) > 15 then
		if math.random(1000) > 800 then
			mq.cmd('/squelch /nav locyx -286 -282 log=off')
            WaitForNav()
		end
	end
	mq.delay(1000)
end

if (Settings.general.OpenChest == true) then Action_OpenChest() end

mq.unevent('Zoned')
mq.unevent('Failed')
ClearStartingSetup()
Logger.info('...Ended')