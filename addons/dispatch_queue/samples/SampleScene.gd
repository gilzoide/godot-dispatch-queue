extends Node

const DispatchQueue = preload("res://addons/dispatch_queue/dispatch_queue.gd")

export(int) var thread_count = -1

var _counter = 0
var _dispatch_queue = DispatchQueue.new()

func _ready() -> void:
	if thread_count < 0:
		thread_count = OS.get_processor_count()


func _print(i):
	print("Processing ", i)
	return i


func _finished(i) -> void:
	print("Finished ", i)


func _all_finished() -> void:
	_dispatch_queue.shutdown()
	print("Over!")


func _on_Button_pressed() -> void:
	if thread_count > 1:
		_dispatch_queue.create_concurrent(thread_count)
	for i in 50:
		_dispatch_queue.dispatch(self, "_print", [i]).then(self, "_finished")
	_dispatch_queue.connect("all_tasks_finished", self, "_all_finished", [], CONNECT_ONESHOT)
