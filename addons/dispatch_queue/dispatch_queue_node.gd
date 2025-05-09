## Node that wraps a DispatchQueue.
##
## Useful for having a local queue in a scene or as an Autoload.
##
## Apart from creation, all DispatchQueue public methods and signals are supported.
##
## Creates the Threads when entering tree and shuts down when exiting tree.
## If `thread_count == 0`, runs queue in synchronous mode.
## If `thread_count < 0`, creates `OS.get_processor_count()` Threads.
extends Node
class_name DispatchQueueNode

signal all_tasks_finished()

@export var thread_count: int = -1: set = set_thread_count

var _dispatch_queue = DispatchQueue.new()


func _ready() -> void:
	_dispatch_queue.all_tasks_finished.connect(self._on_all_tasks_finished)


func _enter_tree() -> void:
	set_thread_count(thread_count)


func _exit_tree() -> void:
	_dispatch_queue.shutdown()


func set_thread_count(value: int) -> void:
	if value < 0:
		value = OS.get_processor_count()
	thread_count = value
	if thread_count == 0:
		_dispatch_queue.shutdown()
	else:
		_dispatch_queue.create_concurrent(thread_count)


# DispatchQueue wrappers
func dispatch(callable: Callable, priority: int = 0) -> DispatchQueue.Task:
	return _dispatch_queue.dispatch(callable, priority)


func dispatch_group(task_list: Array[Callable], priority: int = 0) -> DispatchQueue.TaskGroup:
	return _dispatch_queue.dispatch_group(task_list, priority)


func is_threaded() -> bool:
	return _dispatch_queue.is_threaded()


func get_thread_count() -> int:
	return _dispatch_queue.get_thread_count()


func size() -> int:
	return _dispatch_queue.size()


func is_empty() -> bool:
	return _dispatch_queue.is_empty()


func clear() -> void:
	_dispatch_queue.clear()


func shutdown() -> void:
	_dispatch_queue.shutdown()


# Private functions
func _on_all_tasks_finished() -> void:
	all_tasks_finished.emit()
