extends Node

export(Resource) var dispatch_queue_resource

onready var _dispatch_queue_node = $DispatchQueue


func _ready() -> void:
	if not dispatch_queue_resource:
		dispatch_queue_resource = preload("res://addons/dispatch_queue/dispatch_queue_resource.gd").new()


func _print(i):
	print("Processing ", i)
	return i


func _finished(i) -> void:
	print("Finished ", i)


func _all_finished() -> void:
	print("Over!")


func _on_NodeButton_pressed() -> void:
	_dispatch_all(_dispatch_queue_node)


func _on_ResourceButton_pressed() -> void:
	_dispatch_all(dispatch_queue_resource)


func _dispatch_all(queue) -> void:
	for i in 50:
		queue.dispatch(self, "_print", [i]).then(self, "_finished")
	queue.connect("all_tasks_finished", self, "_all_finished", [], CONNECT_ONESHOT)
