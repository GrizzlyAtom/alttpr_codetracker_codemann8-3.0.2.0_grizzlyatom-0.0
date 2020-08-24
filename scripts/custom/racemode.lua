RaceMode = CustomItem:extend()

function RaceMode:init()
    self:createItem("Race Mode")
    self.code = "race_mode_surrogate"

    self:setState(0)
end

function RaceMode:setState(state)
    self:setProperty("state", state)
end

function RaceMode:getState()
    return self:getProperty("state")
end

function RaceMode:updateIcon()
    local item = Tracker:FindObjectForCode("race_mode")
    item.CurrentStage = self:getState()

    item = Tracker:FindObjectForCode("gt_bkgame")
    item.AcquiredCount = 0
    if self:getState() == 0 then
        self.ItemInstance.Icon = ImageReference:FromPackRelativePath("images/mode_race_off.png")
        item.Icon = ImageReference:FromPackRelativePath("images/BigKey.png", "@disabled")
    else
        self.ItemInstance.Icon = ImageReference:FromPackRelativePath("images/mode_race_on.png")
        item.Icon = ImageReference:FromPackRelativePath("images/race-flag.png")
    end
end

function RaceMode:onLeftClick()
    self:setState((self:getState() + 1) % 2)
end

function RaceMode:onRightClick()
    self:setState((self:getState() - 1) % 2)
end

function RaceMode:canProvideCode(code)
    if code == self.code then
        return true
    else
        return false
    end
end

function RaceMode:providesCode(code)
    if code == self.code and self:getState() ~= 0 then
        return self:getState()
    end
    return 0
end

function RaceMode:advanceToCode(code)
    if code == nil or code == self.code then
        self:setState((self:getState() + 1) % 2)
    end
end

function RaceMode:save()
    return {}
end

function RaceMode:load(data)
    local item = Tracker:FindObjectForCode("race_mode")
    self:setState(item.CurrentStage)
    return true
end

function RaceMode:propertyChanged(key, value)
    if key == "state" then
        self:updateIcon()
    end
end