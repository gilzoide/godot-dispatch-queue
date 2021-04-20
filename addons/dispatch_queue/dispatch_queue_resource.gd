"""
Resource that wraps a DispatchQueue.

Useful for sharing queues with multiple objects between scenes without resorting to Autoload.

Apart from creation, all DispatchQueue public methods and signals are supported.

If `thread_count == 0`, runs queue in synchronous mode.
If `thread_count < 0`, creates `OS.get_processor_count()` Threads.
"""
extends Resource

signal all_tasks_finished()

const DispatchQueue = preload("res://addons/dispatch_queue/dispatch_queue.gd")

export(int) var thread_count: int = -1 setget set_thread_count

var _dispatch_queue = DispatchQueue.new()


func _init(initial_thread_count: int = -1) -> void:
	_dispatch_queue.connect("all_tasks_finished", self, "_on_all_tasks_finished")
	set_thread_count(initial_thread_count)


func set_thread_count(value: int) -> void:
	if value < 0:
		value = OS.get_processor_count()
	thread_count = value
	if thread_count == 0:
		_dispatch_queue.shutdown()
	else:
		_dispatch_queue.create_concurrent(thread_count)
	emit_signal("changed")


# DispatchQueue wrappers
func dispatch(object: Object, method: String, args: Array = []) -> DispatchQueue.Task:
	return _dispatch_queue.dispatch(object, method, args)


func dispatch_group(task_list: Array) -> DispatchQueue.TaskGroup:
	return _dispatch_queue.dispatch_group(task_list)


func is_threaded() -> bool:
	return _dispatch_queue.is_threaded()


func get_thread_count() -> int:
	return _dispatch_queue.get_thread_count()


func clear() -> void:
	_dispatch_queue.clear()


func shutdown() -> void:
	_dispatch_queue.shutdown()


# Private functions
func _on_all_tasks_finished() -> void:
	emit_signal("all_tasks_finished")
