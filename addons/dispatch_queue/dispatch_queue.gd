extends RefCounted
class_name DispatchQueue

## Signal emitted in main thread after all tasks are finished.
signal all_tasks_finished()

## Helper object that emits `finished` after all Tasks in a list finish.
class TaskGroup:
	extends RefCounted

	signal finished(results)

	var task_count := 0
	var task_results = []
	var mutex: Mutex = null


	func _init(threaded: bool) -> void:
		if threaded:
			mutex = Mutex.new()


	## Helper method for connecting to the `finished` signal.
	##
	## This enables the following pattern:
	##   dispatch_queue.dispatch(object, method).then(signal_responder.method)
	func then(callable: Callable, flags: int = 0) -> int:
		return finished.connect(callable, flags | CONNECT_ONE_SHOT)


	## Helper method for connecting to the `finished` signal with deferred flag
	func then_deferred(callable: Callable, flags: int = 0) -> int:
		return then(callable, flags | CONNECT_DEFERRED)


	func add_task(task) -> void:
		task.group = self
		task.id_in_group = task_count
		task_count += 1
		task_results.resize(task_count)


	func mark_task_finished(task, result) -> void:
		if mutex:
			mutex.lock()
		task_count -= 1
		task_results[task.id_in_group] = result
		var is_last_task = task_count == 0
		if mutex:
			mutex.unlock()
		if is_last_task:
			finished.emit(task_results)

## A single task to be executed.
##
## Connect to the `finished` signal to receive the result either manually
## or by calling `then`/`then_deferred`.
class Task:
	extends RefCounted

	signal finished(result)

	var object: Object
	var method: String
	var args: Array
	var group: TaskGroup = null
	var id_in_group: int = -1


	## Helper method for connecting to the `finished` signal.
	##
	## This enables the following pattern:
	##   dispatch_queue.dispatch(object, method).then(signal_responder.method)
	func then(callable: Callable, flags: int = 0) -> int:
		return finished.connect(callable, flags | CONNECT_ONE_SHOT)


	## Helper method for connecting to the `finished` signal with deferred flag
	func then_deferred(callable: Callable, flags: int = 0) -> int:
		return then(callable, flags | CONNECT_DEFERRED)


	func execute() -> void:
		var result = object.callv(method, args)
		finished.emit(result)
		if group:
			group.mark_task_finished(self, result)


class _WorkerPool:
	extends RefCounted

	var threads: Array[Thread] = []
	var should_shutdown := false
	var mutex := Mutex.new()
	var semaphore := Semaphore.new()


	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and self:
			shutdown()


	func shutdown() -> void:
		if threads.is_empty():
			return
		should_shutdown = true
		for i in threads.size():
			semaphore.post()
		for t in threads:
			if t.is_alive():
				t.wait_to_finish()
		threads.clear()
		should_shutdown = false


var _task_queue = []
var _workers: _WorkerPool = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and self:
		shutdown()


func create_serial() -> void:
	"""Attempt to create a threaded Dispatch Queue with 1 Thread"""
	create_concurrent(1)


func create_concurrent(thread_count: int = 1) -> void:
	"""Attempt to create a threaded Dispatch Queue with thread_count Threads"""
	if thread_count == get_thread_count():
		return

	if is_threaded():
		shutdown()

	_workers = _WorkerPool.new()
	for i in max(1, thread_count):
		var thread = Thread.new()
		_workers.threads.append(thread)
		thread.start(self._run_loop.bind(_workers))


func dispatch(object: Object, method: String, args: Array = []) -> Task:
	var task = Task.new()
	if object.has_method(method):
		task.object = object
		task.method = method
		task.args = args

		if is_threaded():
			_workers.mutex.lock()
			_task_queue.append(task)
			_workers.mutex.unlock()
			_workers.semaphore.call_deferred("post")
		else:
			if _task_queue.is_empty():
				call_deferred("_sync_run_next_task")
			_task_queue.append(task)
	else:
		push_error("Object '%s' has no method named %s" % [object, method])
	return task


func dispatch_group(task_list: Array) -> TaskGroup:
	var group = TaskGroup.new(is_threaded())
	for args in task_list:
		var task = callv("dispatch", args)
		if task.object:
			group.add_task(task)

	return group


func is_threaded() -> bool:
	return _workers != null


func get_thread_count() -> int:
	if is_threaded():
		return _workers.threads.size()
	else:
		return 0


func size() -> int:
	var result
	if is_threaded():
		_workers.mutex.lock()
		result = _task_queue.size()
		_workers.mutex.unlock()
	else:
		result = _task_queue.size()
	return result


func is_empty() -> bool:
	return size() <= 0


func clear() -> void:
	if is_threaded():
		_workers.mutex.lock()
		_task_queue.clear()
		_workers.mutex.unlock()
	else:
		_task_queue.clear()


func shutdown() -> void:
	clear()
	if is_threaded():
		var current_workers = _workers
		_workers = null
		current_workers.shutdown()


func _run_loop(pool: _WorkerPool) -> void:
	while true:
		pool.semaphore.wait()
		if pool.should_shutdown:
			break

		pool.mutex.lock()
		var task = _pop_task()
		pool.mutex.unlock()
		if task:
			task.execute()


func _sync_run_next_task() -> void:
	var task = _pop_task()
	if task:
		task.execute()
		call_deferred("_sync_run_next_task")


func _pop_task() -> Task:
	var task: Task = _task_queue.pop_front()
	if task and _task_queue.is_empty():
		task.then_deferred(self._on_last_task_finished)
	return task


func _on_last_task_finished(_result):
	if is_empty():
		all_tasks_finished.emit()
