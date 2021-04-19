extends Node

onready var _dispatch_queue = $DispatchQueue


func _print(i):
	print("Processing ", i)
	return i


func _finished(i) -> void:
	print("Finished ", i)


func _all_finished() -> void:
	print("Over!")


func _on_Button_pressed() -> void:
	for i in 50:
		_dispatch_queue.dispatch(self, "_print", [i]).then(self, "_finished")
	_dispatch_queue.connect("all_tasks_finished", self, "_all_finished", [], CONNECT_ONESHOT)
