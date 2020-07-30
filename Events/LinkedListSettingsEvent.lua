SiloSelectedFillTypeEvent = {};
SiloSelectedFillTypeEvent.TYPE_ADD_ELEMENT = 0
SiloSelectedFillTypeEvent.TYPE_DELETE_X = 1
SiloSelectedFillTypeEvent.TYPE_MOVE_UP_X = 2
SiloSelectedFillTypeEvent.TYPE_MOVE_DOWN_X = 3
SiloSelectedFillTypeEvent.TYPE_CHANGE_RUNCOUNTER = 3
SiloSelectedFillTypeEvent.TYPE_CHANGE_MAX_FILLLEVEL = 3
local SiloSelectedFillTypeEvent_mt = Class(SiloSelectedFillTypeEvent, Event);

InitEventClass(SiloSelectedFillTypeEvent, "SiloSelectedFillTypeEvent");

function SiloSelectedFillTypeEvent:emptyNew()
	local self = Event:new(SiloSelectedFillTypeEvent_mt)
	self.className = "SiloSelectedFillTypeEvent"
	return self
end

function SiloSelectedFillTypeEvent:new(vehicle,settingType,parentName, name, index, value)
	courseplay:debug(string.format("courseplay:SiloSelectedFillTypeEvent:new(%s, %s)", tostring(name), tostring(value)), 5)
	self.vehicle = vehicle
	self.settingType = settingType
	self.messageNumber = Utils.getNoNil(self.messageNumber, 0) + 1
	self.name = name
	self.index = index
	self.value = value
	return self
end

function SiloSelectedFillTypeEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		self.vehicle = nil
	end
	self.settingType = streamDebugReadInt32(streamId)
	local messageNumber = streamReadFloat32(streamId)
	self.name = streamReadString(streamId)

	self.index = streamReadInt32(streamId)
	if self:validValueCall(self.settingType) then
		self.value = streamReadInt32(streamId)
	end
	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(self.vehicle).."/"..tostring(messageNumber).."  self.name: "..tostring(self.name).."  self.value: "..tostring(self.value),5)

	self:run(connection)
end

function SiloSelectedFillTypeEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	courseplay:debug("		writeStream",5)
	courseplay:debug("			id: "..tostring(self.vehicle).."/"..tostring(self.messageNumber).."  self.name: "..tostring(self.name).."  value: "..tostring(self.value),5)

	if self.vehicle ~= nil then
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	else
		streamWriteBool(streamId, false)
	end
	streamWriteInt32(streamId,self.settingType)
	streamWriteFloat32(streamId, self.messageNumber)
	streamWriteString(streamId, self.name)
	streamWriteInt32(streamId, self.index)
	if self:validValueCall(self.settingType) then
		streamWriteInt32(streamId, self.value)
	end
end

function SiloSelectedFillTypeEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, name=%s, value=%s'):format(tostring(self.vehicle), tostring(self.name), tostring(self.value)), 5);

	if self.settingType == SiloSelectedFillTypeEvent.TYPE_ADD_ELEMENT then 
		self.vehicle.cp.settings[self.name]:onFillTypeSelection(self.value)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_DELETE_X then
		self.vehicle.cp.settings[self.name]:deleteByIndex(self.index)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_MOVE_UP_X then
		self.vehicle.cp.settings[self.name]:moveUpByIndex(self.index)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_MOVE_DOWN_X then
		self.vehicle.cp.settings[self.name]:moveDownByIndex(self.index)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_CHANGE_RUNCOUNTER then
		self.vehicle.cp.settings[self.name]:moveDownByIndex(self.value)
	elseif self.settingType == SiloSelectedFillTypeEvent.TYPE_CHANGE_MAX_FILLLEVEL then
		self.vehicle.cp.settings[self.name]:moveDownByIndex(self.value)
	end
	if not connection:getIsServer() then
		courseplay:debug("broadcast settings event feedback",5)
		g_server:broadcastEvent(SiloSelectedFillTypeEvent:new(self.vehicle, self.name, self.value), nil, connection, self.vehicle)
	end
end

function SiloSelectedFillTypeEvent.sendEvent(vehicle,settingType, name, values,dataTypes)
	if g_server ~= nil then
		courseplay:debug("broadcast settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_server:broadcastEvent(SiloSelectedFillTypeEvent:new(vehicle,settingType, name, values,dataTypes), nil, nil, self)
	else
		courseplay:debug("send settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_client:getServerConnection():sendEvent(SiloSelectedFillTypeEvent:new(vehicle,settingType, name, values,dataTypes))
	end;
end

function SiloSelectedFillTypeEvent.sendAddElementEvent(vehicle,parentName, name, fillType)
	SiloSelectedFillTypeEvent.sendEvent(vehicle,SiloSelectedFillTypeEvent.TYPE_ADD_ELEMENT, name, 0, fillType)
end

function SiloSelectedFillTypeEvent.sendDeleteEvent(vehicle,parentName, name, index)
	SiloSelectedFillTypeEvent.sendEvent(vehicle,SiloSelectedFillTypeEvent.TYPE_DELETE_X, name, index)
end

function SiloSelectedFillTypeEvent.sendMoveUpXEvent(vehicle,parentName, name, index)
	SiloSelectedFillTypeEvent.sendEvent(vehicle,SiloSelectedFillTypeEvent.TYPE_MOVE_UP_X, name, index)
end

function SiloSelectedFillTypeEvent.sendMoveDownXEvent(vehicle,parentName, name, index)
	SiloSelectedFillTypeEvent.sendEvent(vehicle,SiloSelectedFillTypeEvent.TYPE_MOVE_DOWN_X, name, index)
end

function SiloSelectedFillTypeEvent.sendChangeRunCounterEvent(vehicle,parentName, name, index, value)
	SiloSelectedFillTypeEvent.sendEvent(vehicle,SiloSelectedFillTypeEvent.TYPE_CHANGE_RUNCOUNTER, name, index, value)
end

function SiloSelectedFillTypeEvent.sendChangeMaxFillLevelEvent(vehicle,parentName, name, index, value)
	SiloSelectedFillTypeEvent.sendEvent(vehicle,SiloSelectedFillTypeEvent.TYPE_CHANGE_MAX_FILLLEVEL, name, index, value)
end

function SiloSelectedFillTypeEvent:validValueCall(settingType)
	if settingType == SiloSelectedFillTypeEvent.TYPE_ADD_ELEMENT or settingType == SiloSelectedFillTypeEvent.TYPE_CHANGE_MAX_FILLLEVEL or settingType == SiloSelectedFillTypeEvent.TYPE_CHANGE_RUNCOUNTER then
		return true
	end
end
