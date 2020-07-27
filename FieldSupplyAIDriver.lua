
--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
Field Supply AI Driver to let fill tools with digestate or liquid manure on the field egde
Also known as mode 8
]]

---@class FieldSupplyAIDriver : FillableFieldworkAIDriver
FieldSupplyAIDriver = CpObject(FillableFieldworkAIDriver)

FieldSupplyAIDriver.myStates = {
	ON_REFILL_COURSE = {},
	WAITING_FOR_GETTING_UNLOADED = {}
}

--- Constructor
function FieldSupplyAIDriver:init(vehicle)
	FillableFieldworkAIDriver.init(self, vehicle)
	self:initStates(FieldSupplyAIDriver.myStates)
	self.supplyState = self.states.ON_REFILL_COURSE
	self.mode=courseplay.MODE_FIELD_SUPPLY 
	self:setHudContent()
end

function FieldSupplyAIDriver:setHudContent()
	courseplay.hud:setFieldSupplyAIDriverContent(self.vehicle)
end

function FieldSupplyAIDriver:start(startingPoint)
	self:beforeStart()
	self:getSiloSelectedFillTypeSetting():cleanUpOldFillTypes()
	self.course = Course(self.vehicle, self.vehicle.Waypoints)
	self.ppc:setCourse(self.course)
	local ix = self.course:getStartingWaypointIx(AIDriverUtil.getDirectionNode(self.vehicle), startingPoint)
	self.ppc:initialize(ix)
	self.state = self.states.ON_UNLOAD_OR_REFILL_COURSE
	self.refillState = self.states.REFILL_DONE
	AIDriver.continue(self)
end

function FieldSupplyAIDriver:stop(msgReference)
	-- TODO: revise why FieldSupplyAIDriver is derived from FieldworkAIDriver, as it has no fieldwork course
	-- so this override would not be necessary.
	AIDriver.stop(self, msgReference)
end


function FieldSupplyAIDriver:drive(dt)
	-- update current waypoint/goal point
	if self.supplyState == self.states.ON_REFILL_COURSE  then
		self:clearInfoText('REACHED_OVERLOADING_POINT')
		FillableFieldworkAIDriver.driveUnloadOrRefill(self)
		AIDriver.drive(self, dt)
	elseif self.supplyState == self.states.WAITING_FOR_GETTING_UNLOADED then
		self:stopAndWait(dt)
		self:setInfoText('REACHED_OVERLOADING_POINT')
		self:updateInfoText()
		-- unload into a FRC if there is one
		courseplay:isUnloadingTriggerAvailable(self.vehicle)
	--	AIDriver.tipIntoStandardTipTrigger(self)
		--if i'm empty or fillLevel is below threshold then drive to get new stuff
		if self:isFillLevelToContinueReached() then
			self:continue()
			self.loadingState = self.states.NOTHING
		end
	end
end

function FieldSupplyAIDriver:continue()
	self:changeSupplyState(self.states.ON_REFILL_COURSE )
	self.state = self.states.RUNNING
	if self:isUnloading() then
		self.activeTriggers=nil
	end
	self.loadingState = self.states.DRIVE_NOW
	self:forceStopLoading()
end

function FieldSupplyAIDriver:onWaypointPassed(ix)
	self:debug('onWaypointPassed %d', ix)
	--- Check if we are at the last waypoint and should we continue with first waypoint of the course
	-- or stop.
	if ix == self.course:getNumberOfWaypoints() then
		self:onLastWaypoint()
	elseif self.course:isWaitAt(ix) then
		-- show continue button
		self.state = self.states.STOPPED
		self:changeSupplyState(self.states.WAITING_FOR_GETTING_UNLOADED)
	end
end

function FieldSupplyAIDriver:changeSupplyState(newState)
	self.supplyState = newState;
end

function FieldSupplyAIDriver:isFillLevelToContinueReached()
	local fillTypeData, fillTypeDataSize= self:getSiloSelectedFillTypeData()
	if fillTypeData == nil then
		return
	end
	local fillLevelInfo = {}
	self:getAllFillLevels(self.vehicle, fillLevelInfo)
	for fillType, info in pairs(fillLevelInfo) do	
		for _,data in ipairs(fillTypeData) do
			if data.fillType == fillType then
				local fillLevelPercentage = info.fillLevel/info.capacity*100
				if fillLevelPercentage <= self.vehicle.cp.settings.driveOnAtFillLevel:get() and self:levelDidNotChange(fillLevelPercentage) then
					return true
				end
			end
		end
	end
end

--TODO might change this one 
function FieldSupplyAIDriver:levelDidNotChange(fillLevelPercent)
	--fillLevel changed in last loop-> start timer
	if self.prevFillLevelPct == nil or self.prevFillLevelPct ~= fillLevelPercent then
		self.prevFillLevelPct = fillLevelPercent
		courseplay:setCustomTimer(self.vehicle, "fillLevelChange", 3);
	end
	--if time is up and no fillLevel change happend, return true
	if courseplay:timerIsThrough(self.vehicle, "fillLevelChange",false) then
		if self.prevFillLevelPct == fillLevelPercent then
			return true
		end
		courseplay:resetCustomTimer(self.vehicle, "fillLevelChange",true);
	end
end

--TODO: figure out the usage of this one ??
function FieldSupplyAIDriver:stopAndWait(dt)
	AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, false, fwd, 0, 1, 0, 1)
end
