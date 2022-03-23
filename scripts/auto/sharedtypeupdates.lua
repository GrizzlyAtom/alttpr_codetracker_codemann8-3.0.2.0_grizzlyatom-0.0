function updateRoomLocations(segment, locations)
    local i = 1
    while i <= #locations do
        local clearedCount = 0
        for i, slot in ipairs(locations[i][2]) do
            local roomData = segment:ReadUInt16(0x7ef000 + (slot[1] * 2))

            -- if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
            --     print(locationRef, roomData, 1 << slot[2])
            -- end

            if (roomData & (1 << slot[2])) ~= 0 then
                clearedCount = clearedCount + 1
            elseif OBJ_ENTRANCE:getState() < 2 and OBJ_RACEMODE:getState() == 0 and slot[3] and roomData & slot[3] ~= 0 then
                if #locations[i] < 3 or Tracker:FindObjectForCode("ow_swapped_" .. string.format("%02x", (locations[i] + 0x40) % 0x80)).ItemState:getState() == 0 then
                    clearedCount = clearedCount + 1
                end
            end
        end

        local remove = false
        if clearedCount > 0 then
            for i, loc in ipairs(locations[i][1]) do
                location = Tracker:FindObjectForCode(loc)
                if location then
                    if not location.Owner.ModifiedByUser then
                        location.AvailableChestCount = location.ChestCount - clearedCount
                    end
                    
                    if location.AvailableChestCount == 0 then
                        remove = true
                    end
                else--if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
                    print("Couldn't find location", loc)
                end
            end

            if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
                print(locations[i][1][1], clearedCount)
            end
        end
        
        if remove then
            table.remove(locations, i)
        else
            i = i + 1
        end
    end
end

function updateChestCountFromDungeon(segment, dungeonPrefix, address)
    local item = Tracker:FindObjectForCode(dungeonPrefix .. "_item").ItemState
    if item and segment then
        item.CollectedCount = segment:ReadUInt8(address)
    end
end

function updateDoorKeyCountFromRoomSlotList(segment, doorKeyRef, roomSlots)
    local doorKey = Tracker:FindObjectForCode(doorKeyRef)
    if doorKey then
        local clearedCount = 0
        for i, slot in ipairs(roomSlots) do
            local roomData = segment:ReadUInt16(0x7ef000 + (slot[1] * 2))

            if (roomData & (1 << slot[2])) ~= 0 then
                clearedCount = clearedCount + 1
            elseif #slot > 2 then
                roomData = segment:ReadUInt16(0x7ef000 + (slot[3] * 2))

                if (roomData & (1 << slot[4])) ~= 0 then
                    clearedCount = clearedCount + 1
                end
            end
        end

        if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
            print(doorKeyRef, clearedCount)
        end

        doorKey.AcquiredCount = clearedCount
    else--if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
        print("Couldn't find door/key", doorKeyRef)
    end
end

function updateDungeonChestCountFromRoomSlotList(segment, dungeonPrefix, roomSlots)
    local item = Tracker:FindObjectForCode(dungeonPrefix .. "_item").ItemState
    if item then
        if OBJ_DOORSHUFFLE:getState() < 2 then
            local clearedCount = 0
            for i, slot in ipairs(roomSlots) do
                local roomData = segment:ReadUInt16(0x7ef000 + (slot[1] * 2))

                if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
                    print(dungeonPrefix, roomData, 1 << slot[2])
                end

                if (roomData & (1 << slot[2])) ~= 0 then
                    clearedCount = clearedCount + 1
                end
            end

            local map = Tracker:FindObjectForCode(dungeonPrefix .. "_map")
            local compass = Tracker:FindObjectForCode(dungeonPrefix .. "_compass")
            local smallkey = Tracker:FindObjectForCode(dungeonPrefix .. "_smallkey")
            local bigkey = Tracker:FindObjectForCode(dungeonPrefix .. "_bigkey")
            local potkey = Tracker:FindObjectForCode(dungeonPrefix .. "_potkey")
            local dungeonItems = 0

            if map.Active and OBJ_KEYMAP:getState() == 0 then
                dungeonItems = dungeonItems + 1
            end

            if compass.Active and OBJ_KEYCOMPASS:getState() == 0 then
                dungeonItems = dungeonItems + 1
            end

            if smallkey.AcquiredCount and OBJ_KEYSMALL:getState() == 0 then
                dungeonItems = dungeonItems + smallkey.AcquiredCount
            end

            if bigkey.Active and OBJ_KEYBIG:getState() == 0 and dungeonPrefix ~= "hc" then
                dungeonItems = dungeonItems + 1
            end

            if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
                print(dungeonPrefix .. " Dungeon Items:", dungeonItems)
                print(dungeonPrefix .. " Chests:", clearedCount)
            end

            if potkey and OBJ_POOL_KEYDROP:getState() > 0 then
                local addedKeys = potkey.AcquiredCount
                if OBJ_KEYBIG:getState() == 0 and dungeonPrefix == "hc" and bigkey.Active then
                    addedKeys = addedKeys - 1
                end
                if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
                    print(dungeonPrefix .. " Key Drops:", addedKeys)
                end
                item.RemainingCount = math.max(item.MaxCount - ((clearedCount - dungeonItems) + addedKeys), 0)
            else
                item.RemainingCount = math.max(item.MaxCount - (clearedCount - dungeonItems), 0)
            end
        end
    else--if CONFIG.PREFERENCE_ENABLE_DEBUG_LOGGING then
        print("Couldn't find chest:", dungeonPrefix)
    end
end

function updateDungeonKeysFromPrefix(segment, dungeonPrefix, address)
    local chestKeys = Tracker:FindObjectForCode(dungeonPrefix .. "_smallkey")

    if OBJ_DOORSHUFFLE:getState() > 0 then
        INSTANCE.NEW_KEY_SYSTEM = true
    elseif not INSTANCE.NEW_KEY_SYSTEM then
        local offset = 0x7ef4e0
        while (offset <= 0x7ef4ed) do
            if AutoTracker:ReadU16(offset) > 0 then
                INSTANCE.NEW_KEY_SYSTEM = true
                break
            end
            offset = offset + 2
        end
    end

    if INSTANCE.NEW_KEY_SYSTEM then
        if address > 0x7ef400 then
            chestKeys.AcquiredCount = segment:ReadUInt8(address) + (dungeonPrefix == "hc" and segment:ReadUInt8(address + 1) or 0)
        end
    elseif OBJ_KEYSMALL:getState() < 2 and address < 0x7ef400 then
        local doorsOpened = Tracker:FindObjectForCode(dungeonPrefix .. "_door")
        local currentKeys = 0

        if DATA.DungeonIdMap[CACHE.DUNGEON] == dungeonPrefix and segment:ReadUInt8(0x7ef36f) ~= 0xff then
            currentKeys = segment:ReadUInt8(0x7ef36f)
        else
            currentKeys = segment:ReadUInt8(address)
        end

        local potKeys = Tracker:FindObjectForCode(dungeonPrefix .. "_potkey")
        if potKeys and OBJ_POOL_KEYDROP:getState() == 0 then
            local offsetKey = 0
            if dungeonPrefix == "hc" and Tracker:FindObjectForCode("hc_bigkey").Active then
                offsetKey = 1
            end
            chestKeys.AcquiredCount = currentKeys + doorsOpened.AcquiredCount - (potKeys.AcquiredCount - offsetKey)
        else
            chestKeys.AcquiredCount = currentKeys + doorsOpened.AcquiredCount
        end
    end
end