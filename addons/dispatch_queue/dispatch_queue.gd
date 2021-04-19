extends Reference

signal all_tasks_finished()

class Task:
	"""
	A single task to be executed.
	
	Connect to the "finished" signal to receive the result either manually
	or by calling "then".
	"""
	extends Reference
	
	signal finished(result)
	
	var object: Object
	var method: String
	var args: Array
	
	
	func execute() -> void:
		var result = object.callv(method, args)
		emit_signal("finished", result)
	
	
	func then(signal_responder: Object, method: String, binds: Array = [], flags: int = 0) -> int:
		"""
		Helper method for connecting to the "finished" signal.
		
		This enables the following pattern:
			
			dispatch_queue.dispatch(object, method).then(signal_responder, method)
		"""
		if signal_responder.has_method(method):
			return connect("finished", signal_responder, method, binds, flags + CONNECT_ONESHOT)
		else:
			push_error("Object '%s' has no method named %s" % [signal_responder, method])
			return ERR_METHOD_NOT_FOUND


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


func create_concurrent(thread_count := 1) -> void:
	"""Attempt to create a threaded Dispatch Queue with thread_count Threads"""
	if is_threaded():
		shutdown()
	
	if not OS.can_use_threads():
		return
	
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
		task.call_deferred("emit_signal", "finished", null)
	return task


func is_threaded() -> bool:
	return _workers != null


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
	var task = _task_queue.pop_front()
	if _task_queue.empty():
		call_deferred("emit_signal", "all_tasks_finished")
	return task
