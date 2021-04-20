extends Node

export(Resource) var dispatch_queue_resource

onready var _dispatch_queue_node = $DispatchQueue


func _ready() -> void:
	if not dispatch_queue_resource:
		dispatch_queue_resource = preload("res://addons/dispatch_queue/dispatch_queue_resource.gd").new()


func _double(i):
	print("Processing ", i)
	return i * 2


func _finished(i) -> void:
	print("Finished ", i)


func _group_finished(results, from: int, to: int) -> void:
	print("Group [%d, %d) finished: %s" % [from, to, results])


func _all_finished() -> void:
	print("Over!\n")


func _on_NodeButton_pressed() -> void:
	_dispatch_all(_dispatch_queue_node)


func _on_ResourceButton_pressed() -> void:
	_dispatch_all(dispatch_queue_resource)


func _dispatch_all(queue) -> void:
	for i in 5:
		_dispatch_group(queue, i * 10, (i + 1) * 10)
	queue.connect("all_tasks_finished", self, "_all_finished", [], CONNECT_ONESHOT)


func _dispatch_group(queue, from: int, to: int) -> void:
	var tasks = []
	for i in range(from, to):
		tasks.append([self, "_double", [i]])
	queue.dispatch_group(tasks).then(self, "_group_finished", [from, to])
