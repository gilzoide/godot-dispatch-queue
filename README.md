# Dispatch Queue
Threaded or synchronous Dispatch Queues for [Godot](https://godotengine.org/).

Threaded Dispatch Queues are also known as Thread Pools.


## Usage
```gdscript
const DispatchQueue = preload("res://addons/dispatch_queue/dispatch_queue.gd")

# 1) Instantiate
var dispatch_queue = DispatchQueue.new()
# 2.a) Either create a serial...
dispatch_queue.create_serial()
# 2.b) ...or concurrent queue
dispatch_queue.create_concurrent(OS.get_processor_count())
# (if you do neither, DispatchQueue will run in synchronous mode)

# 3) Dispatch methods and optionally register callbacks, fire and forget style
dispatch_queue.dispatch(self, "method_name", ["method", "arguments"]).then(self, "result_callback")

# 4) Optionally connect to the `all_tasks_finished` signal to know when all tasks finished
dispatch_queue.connect("all_tasks_finished", self, "_on_all_tasks_finished")

# DispatchQueue extends Reference, so no need to worry about freeing it manually
```

There is a Node script ([addons/dispatch_queue/dispatch_queue_node.gd](addons/dispatch_queue/dispatch_queue_node.gd))
that wraps every aspect of dispatch queues. Useful for having a local queue in a scene or as an Autoload.

There is also a Resource script ([addons/dispatch_queue/dispatch_queue_resource.gd](addons/dispatch_queue/dispatch_queue_resource.gd))
that wraps every aspect of dispatch queues. Useful for sharing queues with multiple objects between scenes without resorting to Autoload.


## API
**DispatchQueue** ([addons/dispatch_queue/dispatch_queue.gd](addons/dispatch_queue/dispatch_queue.gd)):

`signal all_tasks_finished()`
- Emitted when there are no more tasks to process.

`create_serial()`
- Creates a Thread of execution to process tasks.
  If threading is not supported, fallback to synchronous mode.
  If there were previously allocated Threads, calls `shutdown`.

`create_concurrent(thread_count: int = 1)`
- Creates `thread_count` Threads of execution to process tasks.
  If threading is not supported, fallback to synchronous mode.
  If there were previously allocated Threads, calls `shutdown`.
  If `thread_count <= 1`, creates a serial queue.


`dispatch(object: Object, method: String, args: Array = []) -> Task`
- Create a Task for calling `method` on `object` with `args`.
  On threaded mode, the Task will be executed on a Thread when
  there is one available.
  On synchronous mode, the Task will be executed on the next frame.

`dispatch_group(task_list: Array) -> TaskGroup`
- Create all tasks in `task_list` by calling `dispatch` on each value,
  returning the TaskGroup associated with them.
  `task_list` should be an Array of Arrays, each of them containing the
  object, method and optional args Array, in this order.

`is_threaded() -> bool`
- Returns whether queue is threaded or synchronous.

`get_thread_count() -> int`
- Returns the current Thread count.
  Returns 0 on synchronous mode.

`clear()`
- Cancel pending Tasks, clearing the current queue.

`shutdown()`
- Cancel pending Tasks, wait and release the used Threads.
  This method is called automatically on `NOTIFICATION_PREDELETE`.
  It is safe to call this more than once.


**Task** (inner class of DispatchQueue)

`signal finished(result)`
- Emitted after Task executes its method, passing the result as argument.

`then(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Helper method for connecting to the "finished" signal.	
  Always adds `CONNECT_ONESHOT` to flags.
	This enables the following pattern:
```gdscript
dispatch_queue.dispatch(object, method).then(signal_responder, method)
```

`then_deferred(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Alias for `then` that also adds `CONNECT_DEFERRED` to flags.


**TaskGroup** (inner class of DispatchQueue)

`signal finished()`
- Emitted after all Tasks in the group finish.

`then(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Helper method for connecting to the "finished" signal.	
  Always adds `CONNECT_ONESHOT` to flags.
	This enables the following pattern:
```gdscript
dispatch_queue.dispatch_group(task_list).then(signal_responder, method)
```

`then_deferred(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Alias for `then` that also adds `CONNECT_DEFERRED` to flags.


**DispatchQueueNode** ([addons/dispatch_queue/dispatch_queue_node.gd](addons/dispatch_queue/dispatch_queue_node.gd)):

Node that wraps a DispatchQueue.

Apart from creation, all DispatchQueue public methods and signals are supported.

Creates the Threads when entering tree and shuts down when exiting tree.

`export(int) var thread_count = -1`
- Number of Threads DispatchQueue will utilize.
  If `thread_count == 0`, runs queue in synchronous mode.
  If `thread_count < 0`, creates `OS.get_processor_count()` Threads.


**DispatchQueueResource** ([addons/dispatch_queue/dispatch_queue_resource.gd](addons/dispatch_queue/dispatch_queue_resource.gd)):

Resource that wraps a DispatchQueue.

Apart from creation, all DispatchQueue public methods and signals are supported.

`export(int) var thread_count = -1`
- Number of Threads DispatchQueue will utilize.
  If `thread_count == 0`, runs queue in synchronous mode.
  If `thread_count < 0`, creates `OS.get_processor_count()` Threads.


## Credits
- Conveyor icon by [smalllikeart](https://www.flaticon.com/authors/smalllikeart): https://www.flaticon.com/free-icon/conveyor_888545


## Similar projects
- GODOThreadPOOL: https://github.com/zmarcos/godothreadpool
