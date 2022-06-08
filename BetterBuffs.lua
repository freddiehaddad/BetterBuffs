local maxBuffsToDisplay = 32
local maxDebuffsToDisplay = 16
local numBuffsDisplayed = 0
local numDebuffsDisplayed = 0

function BetterBuffs_UpdateBuffAnchors()
  local buff, numBuffs, previousBuff

  numBuffs = 0
  for i = 1, numBuffsDisplayed do
    buff = BetterBuffsBuffFrame.BetterBuffsBuffButton[i]
    numBuffs = numBuffs + 1
    if buff.parent ~= BetterBuffsBuffFrame then
      buff.count:SetFontObject(NumberFontNormal)
      buff:SetParent(BetterBuffsBuffFrame)
      buff.parent = BetterBuffsBuffFrame
    end
    buff:ClearAllPoints()
    if numBuffs == 1 then
      buff:SetPoint("TOPRIGHT", BetterBuffsBuffFrame, "TOPRIGHT", 0, 0)
    else
      buff:SetPoint("RIGHT", previousBuff, "LEFT", BUFF_HORIZ_SPACING, 0)
    end
    previousBuff = buff
  end

  numBuffs = 0
  for i = 1, numDebuffsDisplayed do
    buff = BetterBuffsDebuffFrame.BetterBuffsDebuffButton[i]
    numBuffs = numBuffs + 1
    if buff.parent ~= BetterBuffsDebuffFrame then
      buff.count:SetFontObject(NumberFontNormal)
      buff:SetParent(BetterBuffsDebuffFrame)
      buff.parent = BetterBuffsDebuffFrame
    end
    buff:ClearAllPoints()
    if numBuffs == 1 then
      buff:SetPoint("TOPLEFT", BetterBuffsDebuffFrame, "TOPLEFT", 0, 0)
    else
      buff:SetPoint("LEFT", previousBuff, "RIGHT", -BUFF_HORIZ_SPACING, 0)
    end
    previousBuff = buff
  end
end

function BetterBuffsAuraButton_UpdateDuration(auraButton, timeLeft)
  local duration = auraButton.duration
  if SHOW_BUFF_DURATIONS == "1" and timeLeft then
    duration:SetFormattedText(SecondsToTimeAbbrev(timeLeft))
    if timeLeft < BUFF_DURATION_WARNING_TIME then
      duration:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    else
      duration:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    duration:Show()
  else
    duration:Hide()
  end
end

function BetterBuffsAuraButton_OnUpdate(self)
  local index = self:GetID()
  if self.timeLeft < BUFF_WARNING_TIME then
    self:SetAlpha(BetterBuffs.BuffAlphaValue)
  else
    self:SetAlpha(1.0)
  end

  -- Update duration
  securecall("BetterBuffsAuraButton_UpdateDuration", self, self.timeLeft) -- Taint issue with SecondsToTimeAbbrev 

  -- Update our timeLeft
  local timeLeft = self.expirationTime - GetTime()
  if self.timeMod > 0  then
    timeLeft = timeLeft / self.timeMod
  end
  self.timeLeft = max(timeLeft, 0)

  if SMALLER_AURA_DURATION_FONT_MIN_THRESHOLD then
    local aboveMinThreshold = self.timeLeft > SMALLER_AURA_DURATION_FONT_MIN_THRESHOLD
    local belowMaxThreshold = not SMALLER_AURA_DURATION_FONT_MAX_THRESHOLD or self.timeLeft < SMALLER_AURA_DURATION_FONT_MAX_THRESHOLD
    if aboveMinThreshold and belowMaxThreshold then
      self.duration:SetFontObject(SMALLER_AURA_DURATION_FONT)
      self.duration:SetPoint("TOP", self, "BOTTOM", 0, SMALLER_AURA_DURATION_OFFSET_Y)
    else
      self.duration:SetFontObject(DEFAULT_AURA_DURATION_FONT)
      self.duration:SetPoint("TOP", self, "BOTTOM")
    end
  end

  if BetterBuffs.BuffFrameUpdateTime > 0 then
    return
  end
  if GameTooltip:IsOwned(self) then
    GameTooltip:SetUnitAura(PlayerFrame.unit, index, self.filter)
  end
end

function BetterBuffsAuraButton_Update(buttonName, index, filter, texture, count, debuffType, duration, expirationTime, timeMod)
  --print("BetterBuffsAuraButton_Update")
  local buff, buffArray, buffFrame, template, helpful

  local unit = PlayerFrame.unit

  if filter == "HELPFUL" then
    helpful = true
    buffFrame = BetterBuffsBuffFrame
    template = "BetterBuffsBuffButtonTemplate"
  else
    helpful = false
    buffFrame = BetterBuffsDebuffFrame
    template = "BetterBuffsDebuffButtonTemplate"
  end

  buffArray = buffFrame[buttonName]
  buff = buffArray and buffFrame[buttonName][index]

  -- if button doesn't exist make it
  if not buff then
    local buffName = buttonName..index
    buff = CreateFrame("Button", buffName, buffFrame, template)
    --print("CreateFrame("..buffName..")")
    buff.parent = buffFrame
  end

  -- Setup Buff
  buff:SetID(index)
  buff.unit = unit
  buff.filter = filter
  buff:SetAlpha(1.0)
  buff.exitTime = nil
  buff:Show()

  -- set filter-specific attributes
  if not helpful then
    -- set color of debuff border based on dispel class.
    if buff.Border then
      local color
      if debuffType then
        color = DebuffTypeColor[debuffType]
        if ENABLE_COLORBLIND_MODE == "1" then
          buff.symbol:Show()
          buff.symbol:SetText(DebuffTypeSymbol[debuffType] or "")
        else
          buff.symbol:Hide()
        end
      else
        buff.symbol:Hide()
        color = DebuffTypeColor["none"]
      end
      buff.Border:SetVertexColor(color.r, color.g, color.b)
    end
  end

  if duration > 0 and expirationTime then
    if SHOW_BUFF_DURATIONS == "1" then
      buff.duration:Show()
    else
      buff.duration:Hide()
    end

    local timeLeft = (expirationTime - GetTime())
    if timeMod > 0 then
      buff.timeMod = timeMod
      timeLeft = timeLeft / timeMod
    end

    if not buff.timeLeft then
      buff.timeLeft = timeLeft
      buff:SetScript("OnUpdate", BetterBuffsAuraButton_OnUpdate)
    else
      buff.timeLeft = timeLeft
    end

    buff.expirationTime = expirationTime
  else
    buff.duration:Hide()
    if buff.timeLeft then
      buff:SetScript("OnUpdate", nil)
    end
    buff.timeLeft = nil
  end

  -- set Texture
  buff.Icon:SetTexture(texture)

  buff:ClearAllPoints()
  buff:SetPoint("CENTER", buffFrame, "CENTER", 0, 0)
end

function BetterBuffs_OnLoad(self)
  --print("BetterBuffs_OnLoad")
  self.BuffFrameUpdateTime = 0
  self.BuffFrameFlashTime = 0
  self.BuffFrameFlashState = 1
  self.BuffAlphaValue = 1
  self.numEnchants = 0
  self.bottomEdgeExtent = 0

  self:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
  self:RegisterEvent("GROUP_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")

  -- disable blizzard buffs
  BuffFrame:Hide()
  BuffFrame:UnregisterAllEvents()
  TemporaryEnchantFrame:Hide()
  TemporaryEnchantFrame:UnregisterAllEvents()
end

function BetterBuffs_OnEvent(self, event, ...)
  local unit = ...
  if event == "UNIT_AURA" and unit == PlayerFrame.unit then
    BetterBuffs_UnitAuraEvent()
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" then
    BetterBuffs_UnitAuraEvent()
  elseif event == "PLAYER_ENTERING_WORLD" then
    BetterBuffs_UnitAuraEvent()
  end
end

function BetterBuffs_OnUpdate(self, elapsed)
  if self.BuffFrameUpdateTime > 0 then
    self.BuffFrameUpdateTime = self.BuffFrameUpdateTime - elapsed
  else
    self.BuffFrameUpdateTime = self.BuffFrameUpdateTime + TOOLTIP_UPDATE_TIME
  end

  self.BuffFrameFlashTime = self.BuffFrameFlashTime - elapsed
  if self.BuffFrameFlashTime < 0 then
    local overtime = -self.BuffFrameFlashTime
    if self.BuffFrameFlashState == 0 then
      self.BuffFrameFlashState = 1
      self.BuffFrameFlashTime = BUFF_FLASH_TIME_ON
    else
      self.BuffFrameFlashState = 0
      self.BuffFrameFlashTime = BUFF_FLASH_TIME_OFF
    end
    if overtime < self.BuffFrameFlashTime then
      self.BuffFrameFlashTime = self.BuffFrameFlashTime - overtime
    end
  end

  if self.BuffFrameFlashState == 1 then
    self.BuffAlphaValue = (BUFF_FLASH_TIME_ON - self.BuffFrameFlashTime) / BUFF_FLASH_TIME_ON
  else
    self.BuffAlphaValue = self.BuffFrameFlashTime / BUFF_FLASH_TIME_ON
  end
  self.BuffAlphaValue = (self.BuffAlphaValue * (1 - BUFF_MIN_ALPHA)) + BUFF_MIN_ALPHA
end

function BetterBuffsBuffButton_OnLoad(self)
  --print("BetterBuffsBuffButton_OnLoad")
  self:RegisterForClicks("RightButtonUp")
end

function BetterBuffsBuffButton_OnClick(self)
  --print("BetterBuffsBuffButton_OnClick")
  CancelUnitBuff(self.unit, self:GetID(), self.filter)
end

do
  function BetterBuffs_UpdateWithSlots(buttonName, unit, filter, maxCount)
    --print("BetterBuffs_UpdateWithSlots")
    local index = 1
    AuraUtil.ForEachAura(unit, filter, maxCount, function(...)
      local _, texture, count, debuffType, duration, expirationTime, _, _, _, _, _, _, _, _, timeMod = ...
      BetterBuffsAuraButton_Update(buttonName, index, filter, texture, count, debuffType, duration, expirationTime, timeMod)
      index = index + 1
      return index > maxCount
    end)

    local buffFrame
    if filter == "HELPFUL" then
      buffFrame = BetterBuffsBuffFrame
    else
      buffFrame = BetterBuffsDebuffFrame
    end

    -- hide remaining frames
    local count = index - 1
    local buffArray = buffFrame[buttonName]
    if buffArray then
      for i = index, #buffArray do
        --print("filter: " .. filter .. ", hiding index: " .. index)
        buffArray[i]:Hide()
      end
    end

    return count
  end

  function BetterBuffs_UnitAuraEvent()
    --print("BetterBuffs_UnitAuraEvent")
    numBuffsDisplayed = BetterBuffs_UpdateWithSlots("BetterBuffsBuffButton", PlayerFrame.unit, "HELPFUL", maxBuffsToDisplay)
    --print("Buffs: " .. numBuffsDisplayed)
    numDebuffsDisplayed = BetterBuffs_UpdateWithSlots("BetterBuffsDebuffButton", PlayerFrame.unit, "HARMFUL", maxDebuffsToDisplay)
    --print("Debuffs: " .. numDebuffsDisplayed)

    BetterBuffs_UpdateBuffAnchors()
  end
end
