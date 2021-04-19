# Dispatch Queue
Threaded or synchronous Dispatch Queues for [Godot](https://godotengine.org/).


## Usage
```gdscript
const DispatchQueue = preload("res://addons/dispatch_queue/dispatch_queue.gd")

var dispatch_queue = DispatchQueue.new()
# Either create a serial or concurrent queue
dispatch_queue.create_serial()
dispatch_queue.create_concurrent(OS.get_processor_count())
# Dispatch calls and optionally register callbacks
dispatch_queue.dispatch(self, "method_name", ["method", "arguments"]).then(self, "result_callback")

# DispatchQueue extends Reference, so no need to worry about freeing manually
```


## Similar projects
- GODOThreadPOOL: https://github.com/zmarcos/godothreadpool
