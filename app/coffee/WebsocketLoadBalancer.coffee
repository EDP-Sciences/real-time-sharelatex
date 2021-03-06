Settings = require 'settings-sharelatex'
logger = require 'logger-sharelatex'
redis = require("redis-sharelatex")
SafeJsonParse = require "./SafeJsonParse"
rclientPub = redis.createClient(Settings.redis.web)
rclientSub = redis.createClient(Settings.redis.web)

module.exports = WebsocketLoadBalancer =
	rclientPub: rclientPub
	rclientSub: rclientSub

	emitToRoom: (room_id, message, payload...) ->
		if !room_id?
			logger.warn {message, payload}, "no room_id provided, ignoring emitToRoom"
			return
		data = JSON.stringify
			room_id: room_id
			message: message
			payload: payload
		logger.log {room_id, message, payload, length: data.length}, "emitting to room"
		@rclientPub.publish "editor-events", data

	emitToAll: (message, payload...) ->
		@emitToRoom "all", message, payload...

	listenForEditorEvents: (io) ->
		@rclientSub.subscribe "editor-events"
		@rclientSub.on "message", (channel, message) ->
			WebsocketLoadBalancer._processEditorEvent io, channel, message

	_processEditorEvent: (io, channel, message) ->
		SafeJsonParse.parse message, (error, message) ->
			if error?
				logger.error {err: error, channel}, "error parsing JSON"
				return
			if message.room_id == "all"
				io.sockets.emit(message.message, message.payload...)
			else if message.room_id?
				io.sockets.in(message.room_id).emit(message.message, message.payload...)
		
