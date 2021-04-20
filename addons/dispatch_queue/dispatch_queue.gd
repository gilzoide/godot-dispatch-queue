extends Reference

signal all_tasks_finished()

class TaskGroup:
	"""
	Helper object that emits `finished` after all Tasks in a list finish.
	"""
	extends Reference
	
	signal finished()
	
	var task_count = 0
	
	
	func then(signal_responder: Object, method: String, binds: Array = [], flags: int = 0) -> int:
		"""
		Helper method for connecting to the `finished` signal.
		
		This enables the following pattern:
			
			dispatch_queue.dispatch(object, method).then(signal_responder, method)
		"""
		if signal_responder.has_method(method):
			return connect("finished", signal_responder, method, binds, flags | CONNECT_ONESHOT)
		else:
			push_error("Object '%s' has no method named %s" % [signal_responder, method])
			return ERR_METHOD_NOT_FOUND
	
	
	func then_deferred(signal_responder: Object, method: String, binds: Array = [], flags: int = 0) -> int:
		"""
		Helper method for connecting to the `finished` signal with deferred flag
		"""
		return then(signal_responder, method, binds, flags | CONNECT_DEFERRED)
	
	
	func mark_task_finished() -> void:
		task_count -= 1
		if task_count == 0:
			emit_signal("finished")


class Task:
	"""
	A single task to be executed.
	
	Connect to the `finished` signal to receive the result either manually
	or by calling `then`/`then_deferred`.
	"""
	extends Reference
	
	signal finished(result)
	
	var object: Object
	var method: String
	var args: Array
	var group: TaskGroup = null
	
	
	func then(signal_responder: Object, method: String, binds: Array = [], flags: int = 0) -> int:
		"""
		Helper method for connecting to the `finished` signal.
		
		This enables the following pattern:
			
			dispatch_queue.dispatch(object, method).then(signal_responder, method)
		"""
		if signal_responder.has_method(method):
			return connect("finished", signal_responder, method, binds, flags | CONNECT_ONESHOT)
		else:
			push_error("Object '%s' has no method named %s" % [signal_responder, method])
			return ERR_METHOD_NOT_FOUND
	
	
	func then_deferred(signal_responder: Object, method: String, binds: Array = [], flags: int = 0) -> int:
		"""
		Helper method for connecting to the `finished` signal with deferred flag
		"""
		return then(signal_responder, method, binds, flags | CONNECT_DEFERRED)
	
	
	func execute() -> void:
		var result = object.callv(method, args)
		emit_signal("finished", result)
		if group:
			group.mark_task_finished()


class _WorkerPool:
	extends Reference
	
	var threads = []
	var should_shutdown = false
	var mutex = Mutex.new()
	var semaphore = Semaphore.new()
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and self:
			shutdown()
	
	func shutdown() -> void:
		if threads.empty():
			return
		should_shutdown = true
		for i in threads.size():
			semaphore.post()
		for t in threads:
			if t.is_active():
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
	if not OS.can_use_threads() or thread_count == get_thread_count():
		return
	
	if is_threaded():
		shutdown()
	
	_workers = _WorkerPool.new()
	for i in max(1, thread_count):
		var thread = Thread.new()
		_workers.threads.append(thread)
		thread.start(self, "_run_loop", _workers)


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
			_task_queue.append(task)
			task.then(self, "_pop_task")
			task.call_deferred("execute")
	else:
		push_error("Object '%s' has no method named %s" % [object, method])
	return task


func dispatch_group(task_list: Array) -> TaskGroup:
	var group = TaskGroup.new()
	for args in task_list:
		var task = callv("dispatch", args)
		if task.object:
			task.group = group
			group.task_count += 1
	return group


func is_threaded() -> bool:
	return _workers != null


func get_thread_count() -> int:
	if is_threaded():
		return _workers.threads.size()
	else:
		return 0


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


func _pop_task(_sync_task_result = null) -> Task:
	var task: Task = _task_queue.pop_front()
	if _task_queue.empty():
		task.then_deferred(self, "_on_last_task_finished")
	return task


func _on_last_task_finished(_result):
	emit_signal("all_tasks_finished")
