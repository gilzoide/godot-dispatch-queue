# Dispatch Queue

> **Warning**
>
> This branch is only usable with Godot 3.X.
> For Godot 4.X support, check out the [main](https://github.com/gilzoide/godot-dispatch-queue/tree/main/) branch.

Threaded or synchronous Dispatch Queues for [Godot](https://godotengine.org/).

Threaded Dispatch Queues are also known as Thread Pools.

Available at the [Asset Library](https://godotengine.org/asset-library/asset/924).


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

# 3) Dispatch methods, optionally responding to tasks and task groups "finished" signal
# 3.a) Fire and forget style
dispatch_queue.dispatch(self, "method_name", ["optional", "method", "arguments"]).then(self, "result_callback")
dispatch_queue.dispatch_group([
  [self, "method_name1", ["optional", "arguments"]],
  [self, "method_name2"],
  [self, "method_name3"],
]).then_deferred(self, "group_results_callback")
# 3.b) Coroutine style
var task = dispatch_queue.dispatch(self, "mymethod")
var mymethod_result = yield(task, "finished")
var task_group = dispatch_queue.dispatch_group([ [self, "method1"], [self, "method2"] ])
var group_method_results = yield(task_group, "finished")

# 4) Optionally respond to the `all_tasks_finished` signal to know when all tasks have finished
# 4.a) Connect style
dispatch_queue.connect("all_tasks_finished", self, "_on_all_tasks_finished")
# 4.b) Coroutine style
yield(dispatch_queue, "all_tasks_finished")

# DispatchQueue extends Reference, so no need to worry about freeing it manually
```

There is a Node script ([addons/dispatch_queue/dispatch_queue_node.gd](addons/dispatch_queue/dispatch_queue_node.gd))
that wraps every aspect of dispatch queues. Useful for having a local queue in a scene or as an Autoload.

There is also a Resource script ([addons/dispatch_queue/dispatch_queue_resource.gd](addons/dispatch_queue/dispatch_queue_resource.gd))
that wraps every aspect of dispatch queues. Useful for sharing queues with multiple objects between scenes without resorting to Autoload.


## API
### **DispatchQueue** ([addons/dispatch_queue/dispatch_queue.gd](addons/dispatch_queue/dispatch_queue.gd)):

`signal all_tasks_finished()`
- Emitted when the last queued Task finishes.
  This signal is emitted deferred, so it is safe to call non
  [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/threads/thread_safe_apis.html).


`create_serial()`
- Creates a Thread of execution to process tasks.
  If threading is not supported, fallback to synchronous mode.
  If queue was already serial, this is a no-op, otherwise
  calls `shutdown` and create a new Thread.

`create_concurrent(thread_count: int = 1)`
- Creates `thread_count` Threads of execution to process tasks.
  If threading is not supported, fallback to synchronous mode.
  If queue was already concurrent with `thread_count` Threads,
  this is a no-op, otherwise calls `shutdown` and create new Threads.
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

`size() -> int`
- Returns the number of queued tasks.

`is_empty() -> bool`
- Returns whether queue is empty, that is, there are no tasks queued.

`clear()`
- Cancel pending Tasks, clearing the current queue.

`shutdown()`
- Cancel pending Tasks, wait and release the used Threads.
  This method is called automatically on `NOTIFICATION_PREDELETE`.
  It is safe to call this more than once.


### **Task** (inner class of DispatchQueue)

`signal finished(result)`
- Emitted after Task executes its method, passing the result as argument.
  The signal is emitted in the same Thread that executed the Task, so you
  need to connect with `CONNECT_DEFERRED` if you want to call non [Thread-safe
  APIs](https://docs.godotengine.org/en/stable/tutorials/threads/thread_safe_apis.html).

`then(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Helper method for connecting to the "finished" signal.	
  Always adds `CONNECT_ONESHOT` to flags.
	This enables the following pattern:
```gdscript
dispatch_queue.dispatch(object, method).then(signal_responder, method)
```

`then_deferred(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Alias for `then` that also adds `CONNECT_DEFERRED` to flags.


### **TaskGroup** (inner class of DispatchQueue)

`signal finished(results)`
- Emitted after all Tasks in the group finish, passing the results Array as argument.
  The signal is emitted in the same Thread that executed the last pending Task, so you
  need to connect with `CONNECT_DEFERRED` if you want to call non [Thread-safe
  APIs](https://docs.godotengine.org/en/stable/tutorials/threads/thread_safe_apis.html).

`then(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Helper method for connecting to the "finished" signal.	
  Always adds `CONNECT_ONESHOT` to flags.
	This enables the following pattern:
```gdscript
dispatch_queue.dispatch_group(task_list).then(signal_responder, method)
```

`then_deferred(signal_responder: Object, method: String, binds: Array = [], flags: int = 0)`
- Alias for `then` that also adds `CONNECT_DEFERRED` to flags.


### **DispatchQueueNode** ([addons/dispatch_queue/dispatch_queue_node.gd](addons/dispatch_queue/dispatch_queue_node.gd)):

Node that wraps a DispatchQueue.

Apart from creation, all DispatchQueue public methods and signals are supported.

Creates the Threads when entering tree and shuts down when exiting tree.

`export(int) var thread_count = -1`
- Number of Threads DispatchQueue will utilize.
  If `thread_count == 0`, runs queue in synchronous mode.
  If `thread_count < 0`, creates `OS.get_processor_count()` Threads.


### **DispatchQueueResource** ([addons/dispatch_queue/dispatch_queue_resource.gd](addons/dispatch_queue/dispatch_queue_resource.gd)):

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
