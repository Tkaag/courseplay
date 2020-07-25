LinkedListSettingsEvent = {};
LinkedListSettingsEvent.TYPE_ADD_ELEMENT = 0
LinkedListSettingsEvent.TYPE_DELETE_X = 1
LinkedListSettingsEvent.TYPE_MOVE_UP_X = 2
LinkedListSettingsEvent.TYPE_MOVE_DOWN_X = 3
local LinkedListSettingsEvent_mt = Class(LinkedListSettingsEvent, Event);

InitEventClass(LinkedListSettingsEvent, "LinkedListSettingsEvent");

function LinkedListSettingsEvent:emptyNew()
	local self = Event:new(LinkedListSettingsEvent_mt)
	self.className = "LinkedListSettingsEvent"
	return self
end

function LinkedListSettingsEvent:new(vehicle,settingType, name, values)
	courseplay:debug(string.format("courseplay:LinkedListSettingsEvent:new(%s, %s)", tostring(name), tostring(value)), 5)
	self.vehicle = vehicle
	self.settingType = settingType
	self.messageNumber = Utils.getNoNil(self.messageNumber, 0) + 1
	self.name = name
	self.values = values
	self.dataTypes = dataTypes
	return self
end

function LinkedListSettingsEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if streamReadBool(streamId) then
		self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	else
		self.vehicle = nil
	end
	self.settingType = streamDebugReadInt32(streamId)
	local messageNumber = streamReadFloat32(streamId)
	self.name = streamReadString(streamId)
	if self.dataTypes and #self.dataTypes >0 then
		
	end
	
	self.value = streamReadInt32(streamId)

	courseplay:debug("	readStream",5)
	courseplay:debug("		id: "..tostring(self.vehicle).."/"..tostring(messageNumber).."  self.name: "..tostring(self.name).."  self.value: "..tostring(self.value),5)

	self:run(connection)
end

function LinkedListSettingsEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
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
	streamWriteInt32(streamId, self.value)
end

function LinkedListSettingsEvent:run(connection) -- wir fuehren das empfangene event aus
	courseplay:debug("\t\t\trun",5)
	courseplay:debug(('\t\t\t\tid=%s, name=%s, value=%s'):format(tostring(self.vehicle), tostring(self.name), tostring(self.value)), 5);

	if self.settingType == LinkedListSettingsEvent.TYPE_ADD_ELEMENT then 
		self.vehicle.cp.settings[self.name]:addLast(self.value)
	elseif self.settingType == LinkedListSettingsEvent.TYPE_DELETE_X then
		self.vehicle.cp.settings[self.name]:deleteByIndex(self.value)
	elseif self.settingType == LinkedListSettingsEvent.TYPE_MOVE_UP_X then
		self.vehicle.cp.settings[self.name]:moveUpByIndex(self.value)
	elseif self.settingType == LinkedListSettingsEvent.TYPE_MOVE_DOWN_X then
		self.vehicle.cp.settings[self.name]:moveDownByIndex(self.value)
	end
	if not connection:getIsServer() then
		courseplay:debug("broadcast settings event feedback",5)
		g_server:broadcastEvent(LinkedListSettingsEvent:new(self.vehicle, self.name, self.value), nil, connection, self.vehicle)
	end
end

function LinkedListSettingsEvent.sendEvent(vehicle,settingType, name, values,dataTypes)
	if g_server ~= nil then
		courseplay:debug("broadcast settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_server:broadcastEvent(LinkedListSettingsEvent:new(vehicle,settingType, name, values,dataTypes), nil, nil, self)
	else
		courseplay:debug("send settings event", 5)
		courseplay:debug(('\tid=%s, name=%s'):format(tostring(vehicle), tostring(name)), 5)
		g_client:getServerConnection():sendEvent(LinkedListSettingsEvent:new(vehicle,settingType, name, values,dataTypes))
	end;
end

function LinkedListSettingsEvent.sendAddElementEvent(vehicle, name, values,dataTypes)
	LinkedListSettingsEvent.sendEvent(vehicle,LinkedListSettingsEvent.TYPE_ADD_ELEMENT, name, values,dataTypes)
end

function LinkedListSettingsEvent.sendDeleteEvent(vehicle, name, value)
	LinkedListSettingsEvent.sendEvent(vehicle,LinkedListSettingsEvent.TYPE_DELETE_X, name, values,dataTypes)
end

function LinkedListSettingsEvent.sendMoveUpXEvent(vehicle, name, value)
	LinkedListSettingsEvent.sendEvent(vehicle,LinkedListSettingsEvent.TYPE_MOVE_UP_X, name, values,dataTypes)
end

function LinkedListSettingsEvent.sendMoveDownXEvent(vehicle, name, value)
	LinkedListSettingsEvent.sendEvent(vehicle,LinkedListSettingsEvent.TYPE_MOVE_DOWN_X, name, values,dataTypes)
end