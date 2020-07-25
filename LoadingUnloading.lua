
--Loading/Unloading handling with direct giants function 
--and not with local CP Triggers/ no more cp.worktool using!!

--for now only support for FieldSupplyAIDriver and FillableFieldworkAIDriver!

--Pipe callback used for augerwagons to open the cover on the fillableObject
function courseplay:unloadingTriggerCallback(superFunc,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:checkAIDriver(rootVehicle) then 
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) and not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then
			return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
		end
		if onEnter then 
			courseplay.debugFormat(2,"unloadingTriggerCallback onEnter")
			if fillableObject.spec_cover and fillableObject.getFillUnitIndexFromNode ~= nil then 
				local fillUnitIndex = fillableObject:getFillUnitIndexFromNode(otherId)
                if fillUnitIndex ~= nil then
					local dischargeNode = self:getDischargeNodeByIndex(self:getPipeDischargeNodeIndex())
					local fillType = nil
					if dischargeNode ~= nil then
                        fillType = self:getFillUnitFillType(dischargeNode.fillUnitIndex)
					end
					if fillType then 
						local objectFillUnitIndex = fillableObject:getFirstValidFillUnitToFill(fillType)
						if objectFillUnitIndex then
							SpecializationUtil.raiseEvent(fillableObject, "onAddedFillUnitTrigger",fillType,objectFillUnitIndex,1)
							courseplay.debugFormat(2,"open Cover of fillableObject")
						end
					end
				end
			end
		end
		if onLeave then
			courseplay.debugFormat(2,"unloadingTriggerCallback onLeave")
		end
	end
	if fillableObject and fillableObject.spec_fillUnit then
		if onLeave then 
			SpecializationUtil.raiseEvent(fillableObject, "onRemovedFillUnitTrigger",#fillableObject.spec_fillUnit.fillTrigger.triggers)
			courseplay.debugFormat(2,"close Cover of fillableObject")
		end
	end
	return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
end
Pipe.unloadingTriggerCallback = Utils.overwrittenFunction(Pipe.unloadingTriggerCallback,courseplay.unloadingTriggerCallback)

--used to check if fillTrigger is allowed and start/stop driver
function courseplay:setFillUnitIsFilling(superFunc,isFilling, noEventSend)
	local rootVehicle = self:getRootVehicle()
	if rootVehicle and courseplay:checkAIDriver(rootVehicle) then 
		local siloSelectedFillType = nil
		if rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) then--FillableFieldWorkDriver
			siloSelectedFillType = rootVehicle.cp.settings.siloSelectedFillTypeFillableFieldWorkDriver
		elseif rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then--FieldSupplyDriver
			siloSelectedFillType = rootVehicle.cp.settings.siloSelectedFillTypeFieldSupplyDriver
		else
			return superFunc(self,isFilling, noEventSend)
		end	
		local fillTypeData = siloSelectedFillType:getData()
		local spec = self.spec_fillUnit
		if isFilling ~= spec.fillTrigger.isFilling then
			if noEventSend == nil or noEventSend == false then
				if g_server ~= nil then
					g_server:broadcastEvent(SetFillUnitIsFillingEvent:new(self, isFilling), nil, nil, self)
				else
					g_client:getServerConnection():sendEvent(SetFillUnitIsFillingEvent:new(self, isFilling))
				end
			end
			if isFilling then
				-- find the first trigger which is activable
				spec.fillTrigger.currentTrigger = nil
				for _, trigger in ipairs(spec.fillTrigger.triggers) do
					for _,data in ipairs(fillTypeData) do
						if trigger:getIsActivatable(self) then
							local fillType = trigger:getCurrentFillType()
							local fillUnitIndex = nil
							if fillType and fillType == data.fillType then
								fillUnitIndex = self:getFirstValidFillUnitToFill(fillType)
							end
							if not rootVehicle.cp.driver:isFilledUntilPercantageX(fillType,data.maxFillLevel) then 
								if fillUnitIndex then
									rootVehicle = self:getRootVehicle()
									rootVehicle.cp.driver:setLoadingState(self,fillUnitIndex,fillType)
									spec.fillTrigger.currentTrigger = trigger
									courseplay.debugFormat(2,"FillUnit setLoading, FillType: "..g_fillTypeManager:getFillTypeByIndex(fillType).title)
									break
								end
							end
						end
					end
				end
			end
			spec.fillTrigger.isFilling = isFilling
			if self.isClient then
				self:setFillSoundIsPlaying(isFilling)
				if spec.fillTrigger.currentTrigger ~= nil then
					spec.fillTrigger.currentTrigger:setFillSoundIsPlaying(isFilling)
				end
			end
			SpecializationUtil.raiseEvent(self, "onFillUnitIsFillingStateChanged", isFilling)
			if not isFilling then
				self:updateFillUnitTriggers()
				rootVehicle.cp.driver:resetLoadingState()
				courseplay.debugFormat(2,"FillUnit resetLoading")
			end
		end
		return
	end
	return superFunc(self,isFilling, noEventSend)
end
FillUnit.setFillUnitIsFilling = Utils.overwrittenFunction(FillUnit.setFillUnitIsFilling,courseplay.setFillUnitIsFilling)

--scanning for LoadingTriggers and FillTriggers(checkFillTriggers)
function courseplay:isTriggerAvailable(vehicle)
    for key, object in pairs(g_currentMission.activatableObjects) do
		if object:getIsActivatable(vehicle) then
			local callback = {}		
			if object:isa(LoadTrigger) then 
				courseplay:activateTriggerForVehicle(object, vehicle,callback)
				if courseplay:handleLoadTriggerCallback(vehicle,callback) then 
					g_currentMission.activatableObjects[key] = nil
				end
				return
			end
        end
    end
	courseplay:checkFillTriggers(vehicle)
    return
end

--check recusively if fillTriggers are enableable 
function courseplay:checkFillTriggers(object)
	if object.spec_fillUnit then
		local spec = object.spec_fillUnit
		local coverSpec = object.spec_cover	
		if spec.fillTrigger and #spec.fillTrigger.triggers>0 then
			if coverSpec and coverSpec.isDirty then 
				local rootVehicle = object:getRootVehicle()
				if rootVehicle and rootVehicle.cp and rootVehicle.cp.driver and rootVehicle:getIsCourseplayDriving() and rootVehicle.cp.driver:isActive() then 
					rootVehicle.cp.driver:setLoadingState()
				end
				courseplay.debugFormat(2,"cover is still opening wait!")
			else	
				object:setFillUnitIsFilling(true)
			end
		end
	end
	-- get all attached implements recursively
	for _,impl in pairs(object:getAttachedImplements()) do
		self:checkFillTriggers(impl.object)
	end
end

--check for standart object unloading Triggers
function courseplay:isUnloadingTriggerAvailable(object)    
	local spec = object.spec_dischargeable
	local rootVehicle = object:getRootVehicle()
	if spec then 
		if spec:getCanToggleDischargeToObject() then 
			local currentDischargeNode = spec.currentDischargeNode
			if currentDischargeNode.dischargeObject then 
				rootVehicle.cp.driver:setInTriggerRange()
			end			
			if currentDischargeNode and spec.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
				if not spec:getCanDischargeToObject(currentDischargeNode) then
					for i=1,#spec.dischargeNodes do
						if spec:getCanDischargeToObject(spec.dischargeNodes[i])then
							spec:setCurrentDischargeNodeIndex(spec.dischargeNodes[i]);
							currentDischargeNode = spec:getCurrentDischargeNode()
							break
						end
					end
				end
				if spec:getCanDischargeToObject(currentDischargeNode) and not rootVehicle.cp.driver:isNearFillPoint() then
					spec:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)				
					rootVehicle.cp.driver:setUnloadingState()
				end
			end
		end
	end
	for _,impl in pairs(object:getAttachedImplements()) do
		courseplay:isUnloadingTriggerAvailable(impl.object)
	end
end

--CP callbacks for LoadingTriggers
function courseplay:handleLoadTriggerCallback(vehicle,callback)
	if callback.startLoading then
		return true
	end
	if callback.full then
		return 
	end
	if callback.waitingForCover then 
		return
	end	
	if callback.noSelectedFillTypes then
		vehicle.cp.driver:setLoadingState()
		CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_NO_FILLTYPE');
		return
	end	
	if callback.fillLevelReached  then 
		
		return true
	end
	if callback.emptyOne then
		vehicle.cp.driver:setLoadingState()
		CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
		return 
	end	
	if callback.emptyAll then 
		vehicle.cp.driver:setLoadingState()
		CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_IS_EMPTY');
		return 
	end
	if callback.fail then 
		--TODO ??
		CpManager:setGlobalInfoText(vehicle, 'FARM_SILO_NO_FILLTYPE');
		return 
	end	
	return 
end

--LoadTrigger activate, if fillType is right and fillLevel ok 
function courseplay:onActivateObject(superFunc,vehicle,callback)
	if courseplay:checkAIDriver(vehicle) then 
		local siloSelectedFillType = nil
		if vehicle.cp.driver:is_a(FillableFieldworkAIDriver) then
			siloSelectedFillType = vehicle.cp.settings.siloSelectedFillTypeFillableFieldWorkDriver
		elseif vehicle.cp.driver:is_a(FieldSupplyAIDriver) then
			siloSelectedFillType = vehicle.cp.settings.siloSelectedFillTypeFieldSupplyDriver
		else
			return superFunc(self)
		end
		if not self.isLoading then
			local fillLevels, capacity
			if self.source.getAllFillLevels then 
				fillLevels, capacity = self.source:getAllFillLevels(g_currentMission:getFarmId())
			elseif self.source.getAllProvidedFillLevels then --g_company fillLevels
				--self.managerId should be self.extraParameter!!!
				fillLevels, capacity = self.source:getAllProvidedFillLevels(g_currentMission:getFarmId(), self.managerId)
			else
				return superFunc(self)
			end
			local fillableObject = self.validFillableObject
			local fillUnitIndex = self.validFillableFillUnitIndex
			local firstFillType = nil
			local validFillTypIndexes = {}
			local fillTypeData = siloSelectedFillType:getData()
			local emptyOnes = 0
			for fillTypeIndex, fillLevel in pairs(fillLevels) do
				if self.fillTypes == nil or self.fillTypes[fillTypeIndex] then
					if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) then
						for _,data in ipairs(fillTypeData) do
							if fillLevel > 0 and  fillTypeIndex == data.fillType then
								if not vehicle.cp.driver:isFilledUntilPercantageX(fillTypeIndex,data.maxFillLevel) then 
									if fillableObject.spec_cover and fillableObject.spec_cover.isDirty then 
										vehicle.cp.driver:setLoadingState(fillableObject,fillUnitIndex,fillTypeIndex,self)
										callback.waitingForCover = true
										courseplay.debugFormat(2, 'Cover is still opening!')
										return
									end
									if fillableObject:getFillUnitCapacity(fillUnitIndex) <=0 then
									
									else
										self:onFillTypeSelection(fillTypeIndex)
										callback.startLoading = true
										return								
									end
								else
									courseplay.debugFormat(2, 'FillLevel reached!')
									callback.fillLevelReached = true
								end
							else 
								emptyOnes = emptyOnes+1
								callback.emptyOne = true
							end
						end
						if siloSelectedFillType:getSize() == 0 then
							callback.noSelectedFillTypes = true
							return
						end
					end
				end
			end
			if emptyOnes == siloSelectedFillType:getSize() then 
				callback.emptyAll = true
				return
			end
			callback.fail = true
		end
	else 
		return superFunc(self,vehicle)
	end
end
LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,courseplay.onActivateObject)

--LoadTrigger => start/stop driver and close cover once free from trigger
function courseplay:setIsLoading(superFunc,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
	local rootVehicle = self.validFillableObject:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) then
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) and not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then
			return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
		end
		if isLoading then 
			rootVehicle.cp.driver:setLoadingState(self.validFillableObject,fillUnitIndex, fillType,self)
			courseplay.debugFormat(2, 'LoadTrigger setLoading, FillType: '..g_fillTypeManager:getFillTypeByIndex(fillType).title)
		else 
			rootVehicle.cp.driver:resetLoadingState()
			courseplay.debugFormat(2, 'LoadTrigger resetLoading and close Cover')
			SpecializationUtil.raiseEvent(self.validFillableObject, "onRemovedFillUnitTrigger",#self.validFillableObject.spec_fillUnit.fillTrigger.triggers)
		end
	end
	return superFunc(self,isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
end
LoadTrigger.setIsLoading = Utils.overwrittenFunction(LoadTrigger.setIsLoading,courseplay.setIsLoading)

--LoadTrigger callback used to open correct cover for loading 
function courseplay:loadTriggerCallback(superFunc,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	--legancy code!!!
	courseplay:SiloTrigger_TriggerCallback(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:checkAIDriver(rootVehicle) then
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) and not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then
			return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
		end
		if onEnter then 
			courseplay.debugFormat(2, 'LoadTrigger onEnter')
			rootVehicle.cp.driver:setInTriggerRange()
			if fillableObject.getFillUnitIndexFromNode ~= nil then
				local fillLevels, capacity = self.source:getAllFillLevels(g_currentMission:getFarmId())
				local foundFillUnitIndex = fillableObject:getFillUnitIndexFromNode(otherId)
				for fillTypeIndex, fillLevel in pairs(fillLevels) do
					if fillableObject:getFillUnitSupportsFillType(foundFillUnitIndex, fillTypeIndex) then
						if fillableObject:getFillUnitAllowsFillType(foundFillUnitIndex, fillTypeIndex) then
							SpecializationUtil.raiseEvent(fillableObject, "onAddedFillUnitTrigger",fillTypeIndex,foundFillUnitIndex,1)
							courseplay.debugFormat(2, 'open Cover for loading')
						end
					end
				end
			end
		end
		if onLeave then
			courseplay.debugFormat(2, 'LoadTrigger onLeave')
		end
		rootVehicle.cp.driver:isInFirstLoadingTrigger(triggerId)
	end
	return superFunc(self,triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
end
LoadTrigger.loadTriggerCallback = Utils.overwrittenFunction(LoadTrigger.loadTriggerCallback,courseplay.loadTriggerCallback)

--FillTrigger callback used to set approach speed for Cp driver
function courseplay:fillTriggerCallback(superFunc, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local fillableObject = g_currentMission:getNodeObject(otherId)
	local rootVehicle
	if fillableObject then 
		rootVehicle = fillableObject:getRootVehicle()
	end
	if courseplay:checkAIDriver(rootVehicle) then
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) and not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then
			return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
		end		
		if onEnter then
			rootVehicle.cp.driver:setInTriggerRange()
			courseplay.debugFormat(2, 'fillTrigger onEnter')
		elseif onLeave then
			courseplay.debugFormat(2, 'fillTrigger onLeave')
		end
	end
	return superFunc(self,triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end
FillTrigger.fillTriggerCallback = Utils.overwrittenFunction(FillTrigger.fillTriggerCallback, courseplay.fillTriggerCallback)

--Pipe onDischargeStateChanged => start/stop self and stop/start fillableObject
function courseplay:onDischargeStateChanged(superFunc,state)
	local rootVehicle = self:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) then
		if not rootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) and not rootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then
			return superFunc(self,state)
		end
		local spec = self.spec_pipe
		if spec.nearestObjectInTriggers.objectId then
			local object = spec.nearestObjectInTriggers.objectId 
			local fillUnitIndex = spec.nearestObjectInTriggers.fillUnitIndex 
			local objectRootVehicle = nil 
			local dischargeNode = self:getDischargeNodeByIndex(self:getPipeDischargeNodeIndex())
			local fillType = nil
			if dischargeNode then
				local fillType = self:getFillUnitLastValidFillType(dischargeNode.fillUnitIndex)
			end
			if object and fillUnitIndex and fillType then 
				objectRootVehicle = object:getRootVehicle()
			end
			if objectRootVehicle and objectRootVehicle.cp and objectRootVehicle.cp.driver and objectRootVehicle:getIsCourseplayDriving() and objectRootVehicle.cp.driver:isActive() then
				if not objectRootVehicle.cp.driver:is_a(FillableFieldworkAIDriver) and not objectRootVehicle.cp.driver:is_a(FieldSupplyAIDriver) then
					return superFunc(self,state)
				end
				if state == Dischargeable.DISCHARGE_STATE_OFF then
					objectRootVehicle.cp.driver:resetLoadingState()				
				else  
					objectRootVehicle.cp.driver:setLoadingState(object,fillUnitIndex, fillType,self)
				end
			end
		end
	end
	return superFunc(self,state)
end
Pipe.onDischargeStateChanged = Utils.overwrittenFunction(Pipe.onDischargeStateChanged, courseplay.onDischargeStateChanged)

-- Custom version of trigger:onActivateObject to allow activating for a non-controlled vehicle
function courseplay:activateTriggerForVehicle(trigger, vehicle,callback)
	--Cache giant values to restore later
	local defaultGetFarmIdFunction = g_currentMission.getFarmId;
	local oldControlledVehicle = g_currentMission.controlledVehicle;

	--Override farm id to match the calling vehicle (fixes issue when obtaining fill levels)
	local overriddenFarmIdFunc = function()
		local ownerFarmId = vehicle:getOwnerFarmId()
		courseplay.debugVehicle(19, vehicle, 'Overriding farm id during trigger activation to %d', ownerFarmId);
		return ownerFarmId;
	end
	g_currentMission.getFarmId = overriddenFarmIdFunc;

	--Override controlled vehicle if I'm not in it
	if g_currentMission.controlledVehicle ~= vehicle then
		g_currentMission.controlledVehicle = vehicle;
	end

	--Call giant method with new params set
	--trigger:onActivateObject(vehicle,callback);
	trigger:onActivateObject(vehicle,callback)
	--Restore previous values
	g_currentMission.getFarmId = defaultGetFarmIdFunction;
	g_currentMission.controlledVehicle = oldControlledVehicle;
end

-- LoadTrigger doesn't allow filling non controlled tools
function courseplay:getIsActivatable(superFunc,objectToFill)
	--when the trigger is filling, it uses this function without objectToFill
	if objectToFill ~= nil then
		local vehicle = objectToFill:getRootVehicle()
		if objectToFill:getIsCourseplayDriving() or (vehicle~= nil and vehicle:getIsCourseplayDriving()) then
			--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
			if g_currentMission.controlledVehicle ~= vehicle then
				local oldControlledVehicle = g_currentMission.controlledVehicle;
				g_currentMission.controlledVehicle = vehicle or objectToFill;
				local result = superFunc(self,objectToFill);
				g_currentMission.controlledVehicle = oldControlledVehicle;
				return result;
			end
		end
	end
	return superFunc(self,objectToFill);
end
LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,courseplay.getIsActivatable)

--close cover after tipping if not closed already
function courseplay:endTipping(superFunc,noEventSend)
	local rootVehicle = self:getRootVehicle()
	if courseplay:checkAIDriver(rootVehicle) then
		if rootVehicle.cp.settings.automaticCoverHandling:is(true) and self.spec_cover then
			self:setCoverState(0, true)
		end
		rootVehicle.cp.driver:resetUnloadingState()
	end
	return superFunc(self,noEventSend)
end
Trailer.endTipping = Utils.overwrittenFunction(Trailer.endTipping,courseplay.endTipping)

function courseplay:checkAIDriver(rootVehicle) 
	if rootVehicle and rootVehicle.cp and rootVehicle.cp.driver and rootVehicle:getIsCourseplayDriving() and rootVehicle.cp.driver:isActive() then
		return true
	end
end



