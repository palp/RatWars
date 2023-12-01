extends Node

signal create_session_request_complete
signal get_leaderboard_request_complete
signal update_session_request_complete
signal submit_session_request_complete
signal unlock_request_complete

var logger = LogStream.new("Server", LogStream.LogLevel.WARN)

var leaderboard: Array
var session: Dictionary
var unlocks: Array

@onready var get_leaderboard_http_request = HTTPRequest.new()
@onready var create_session_http_request = HTTPRequest.new()
@onready var update_session_http_request = HTTPRequest.new()
@onready var submit_session_http_request = HTTPRequest.new()
@onready var unlock_http_request = HTTPRequest.new()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_leaderboard_http_request.request_completed.connect(_on_leaderboard_response)
	add_child(get_leaderboard_http_request)
	create_session_http_request.request_completed.connect(_on_create_session_response)
	add_child(create_session_http_request)
	update_session_http_request.request_completed.connect(_on_update_session_response)
	add_child(update_session_http_request)
	submit_session_http_request.request_completed.connect(_on_submit_session_response)
	add_child(submit_session_http_request)
	unlock_http_request.request_completed.connect(_on_unlock_response)
	add_child(unlock_http_request)


func create_game_session():
	if session.has("id"):
		logger.warn("create_session: Not replacing existing session!")
		return {}
	create_session_http_request.request(
		GameConfig.api_base_url + "/session", PackedStringArray([]), HTTPClient.METHOD_POST
	)
	await create_session_request_complete
	return session


func update_game_session(score):
	if not session.has("id"):
		logger.warn("update_game_session: Not replacing existing session!")
		return {}
	update_session_http_request.request(
		GameConfig.api_base_url + "/session/%s" % session.id,
		PackedStringArray([]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"score": score})
	)
	await update_session_request_complete
	return session


func end_game_session():
	session = {}


func submit_game_session(score, name):
	if not session.has("id"):
		logger.warn("submit_game_session: Not replacing existing session!")
		return {}
	submit_session_http_request.request(
		GameConfig.api_base_url + "/session/%s/submit" % session.id,
		PackedStringArray([]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"score": score, "name": name})
	)
	await submit_session_request_complete
	session = {}
	return leaderboard


func get_leaderboard():
	get_leaderboard_http_request.request(GameConfig.api_base_url + "/leaderboard")
	await get_leaderboard_request_complete

	return leaderboard

func unlock_content(code):
	unlock_http_request.request(GameConfig.api_base_url + "/unlock", PackedStringArray([]), HTTPClient.METHOD_POST, JSON.stringify({"code": code}))
	await unlock_request_complete

	return unlocks


func _on_create_session_response(result, response_code, headers, body):
	var body_string = body.get_string_from_utf8()
	logger.debug(
		"create_session_response: ",
		{"result": result, "response_code": response_code, "headers": headers, "body": body_string}
	)
	if response_code == 200:
		session = JSON.parse_string(body_string)
	elif response_code >= 400 and response_code < 500:
		logger.warn(
			"create_session_error: ",
			{"response_code": response_code, "body": JSON.parse_string(body_string)}
		)
	else:
		logger.warn("create_session_error: ", {"response_code": response_code, "body": body_string})

	emit_signal("create_session_request_complete")


func _on_leaderboard_response(result, response_code, headers, body):
	var body_string = body.get_string_from_utf8()
	logger.debug(
		"get_leaderboard_response: ",
		{"result": result, "response_code": response_code, "headers": headers, "body": body_string}
	)
	if response_code == 200:
		leaderboard = JSON.parse_string(body_string)
	elif response_code >= 400 and response_code < 500:
		logger.warn(
			"get_leaderboard_error: ",
			{"response_code": response_code, "body": JSON.parse_string(body_string)}
		)
	else:
		logger.warn(
			"get_leaderboard_error: ", {"response_code": response_code, "body": body_string}
		)

	emit_signal("get_leaderboard_request_complete")


func _on_update_session_response(result, response_code, headers, body):
	var body_string = body.get_string_from_utf8()
	logger.debug(
		"update_session_response: ",
		{"result": result, "response_code": response_code, "headers": headers, "body": body_string}
	)
	if response_code == 200:
		session = JSON.parse_string(body_string)
	elif response_code >= 400 and response_code < 500:
		logger.warn(
			"update_session_error: ",
			{"response_code": response_code, "body": JSON.parse_string(body_string)}
		)
	else:
		logger.warn(
			"uopdate_session_error: ", {"response_code": response_code, "body": body_string}
		)
	emit_signal("update_session_request_complete")


func _on_submit_session_response(result, response_code, headers, body):
	var body_string = body.get_string_from_utf8()
	logger.debug(
		"submit_session_response: ",
		{"result": result, "response_code": response_code, "headers": headers, "body": body_string}
	)
	if response_code == 200:
		leaderboard = JSON.parse_string(body_string)
	elif response_code >= 400 and response_code < 500:
		logger.warn(
			"submit_session_error: ",
			{"response_code": response_code, "body": JSON.parse_string(body_string)}
		)
	else:
		logger.warn("submit_session_error: ", {"response_code": response_code, "body": body_string})
	emit_signal("submit_session_request_complete")

func _on_unlock_response(result, response_code, headers, body):
	var body_string = body.get_string_from_utf8()
	logger.debug(
		"unlock_response: ",
		{"result": result, "response_code": response_code, "headers": headers, "body": body_string}
	)
	if response_code == 200:		
		unlocks = JSON.parse_string(body_string)['content']
	elif response_code >= 400 and response_code < 500:
		logger.warn(
			"unlock_error: ",
			{"response_code": response_code, "body": JSON.parse_string(body_string)}
		)
	else:
		logger.warn("unlock_error: ", {"response_code": response_code, "body": body_string})
	emit_signal("unlock_request_complete")
