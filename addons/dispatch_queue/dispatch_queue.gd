extends RefCounted
class_name DispatchQueue

## Emitted when the last queued Task finishes.
## This signal is emitted deferred, so it is safe to call non Thread-safe APIs.
signal all_tasks_finished()

## Helper object that emits "finished" after all Tasks in a list finish.
class TaskGroup:
	extends RefCounted

	## Emitted after Task executes, passing the result as argument.
	## The signal is emitted in the same Thread that executed the Task, so you
	## need to connect with CONNECT_DEFERRED if you want to call non Thread-safe APIs.
	signal finished(results)

	var task_count := 0
	var task_results = []
	var mutex: Mutex = null


	func _init(threaded: bool) -> void:
		if threaded:
			mutex = Mutex.new()


	## Helper method for connecting to the "finished" signal.
	##
	## This enables the following pattern:
	##   dispatch_queue.dispatch_group(task_list).then(continuation_callable)
	func then(callable: Callable, flags: int = 0) -> int:
		return finished.connect(callable, flags | CONNECT_ONE_SHOT)


	## Alias for `then` that also adds CONNECT_DEFERRED to flags.
	func then_deferred(callable: Callable, flags: int = 0) -> int:
		return then(callable, flags | CONNECT_DEFERRED)


	func add_task(task: Task) -> void:
		task.group = self
		task.id_in_group = task_count
		task_count += 1
		task_results.resize(task_count)


	func mark_task_finished(task: Task, result) -> void:
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

	## Emitted after all Tasks in the group finish, passing the results Array as argument.
	## The signal is emitted in the same Thread that executed the last pending Task, so you
  	## need to connect with CONNECT_DEFERRED if you want to call non Thread-safe APIs.
	signal finished(result)

	var callable: Callable
	var group: TaskGroup = null
	var id_in_group: int = -1


	## Helper method for connecting to the "finished" signal.
	##
	## This enables the following pattern:
	##   dispatch_queue.dispatch(callable).then(continuation_callable)
	func then(callable: Callable, flags: int = 0) -> int:
		return finished.connect(callable, flags | CONNECT_ONE_SHOT)


	## Alias for `then` that also adds CONNECT_DEFERRED to flags.
	func then_deferred(callable: Callable, flags: int = 0) -> int:
		return then(callable, flags | CONNECT_DEFERRED)


	func execute() -> void:
		var result = callable.call()
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


## Creates a Thread of execution to process tasks.
## If queue was already serial, this is a no-op, otherwise calls `shutdown` and create a new Thread.
func create_serial() -> void:
	create_concurrent(1)


## Creates `thread_count` Threads of execution to process tasks.
## If queue was already concurrent with `thread_count` Threads, this is a no-op.
## Otherwise calls `shutdown` and create new Threads.
## If `thread_count <= 1`, creates a serial queue.
func create_concurrent(thread_count: int = 1) -> void:
	if thread_count == get_thread_count():
		return

	if is_threaded():
		shutdown()

	_workers = _WorkerPool.new()
	var run_loop = self._run_loop.bind(_workers)
	for i in max(1, thread_count):
		var thread = Thread.new()
		_workers.threads.append(thread)
		thread.start(run_loop)


## Create a Task for executing `callable`.
## On threaded mode, the Task will be executed on a Thread when there is one available.
## On synchronous mode, the Task will be executed on the next frame.
func dispatch(callable: Callable) -> Task:
	var task = Task.new()
	if callable.is_valid():
		task.callable = callable
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
		push_error("Trying to dispatch an invalid callable, ignoring it")
	return task


## Create all tasks in `task_list` by calling `dispatch` on each value,
## returning the TaskGroup associated with them.
func dispatch_group(task_list: Array[Callable]) -> TaskGroup:
	var group = TaskGroup.new(is_threaded())
	for callable in task_list:
		var task: Task = dispatch(callable)
		group.add_task(task)

	return group


## Returns whether queue is threaded or synchronous.
func is_threaded() -> bool:
	return _workers != null


## Returns the current Thread count.
## Returns 0 on synchronous mode.
func get_thread_count() -> int:
	if is_threaded():
		return _workers.threads.size()
	else:
		return 0


## Returns the number of queued tasks.
func size() -> int:
	var result
	if is_threaded():
		_workers.mutex.lock()
		result = _task_queue.size()
		_workers.mutex.unlock()
	else:
		result = _task_queue.size()
	return result


## Returns whether queue is empty, that is, there are no tasks queued.
func is_empty() -> bool:
	return size() <= 0


## Cancel pending Tasks, clearing the current queue.
## Tasks that are being processed will still run to completion.
func clear() -> void:
	if is_threaded():
		_workers.mutex.lock()
		_task_queue.clear()
		_workers.mutex.unlock()
	else:
		_task_queue.clear()


## Cancel pending Tasks, wait and release the used Threads.
## The queue now runs in synchronous mode, so that new tasks will run in the main thread.
## Call `create_serial` or `create_concurrent` to recreate the worker threads.
## This method is called automatically on `NOTIFICATION_PREDELETE`.
## It is safe to call this more than once.
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
