# Changelog
## [Unreleased](https://github.com/gilzoide/godot-dispatch-queue/compare/1.0.0...HEAD)
### Added
- Support for task priority by passing an optional priority to `DispatchQueue.dispatch` and `DispatchQueue.dispatch_group`.
  Tasks with lower priority are dispatched first.
  The default priority value is 0.


## [1.0.0](https://github.com/gilzoide/godot-dispatch-queue/releases/tag/1.0.0)
### Added
- `DispatchQueue` RefCouted class with support for synchronized, serial and concurrent queues.
  + Queue Callables using `DispatchQueue.dispatch`.
    The returned `DispatchQueue.Task` can be used to invoke continuation callables using its `then` or `then_deferred` methods after the task finishes executing, or by awaiting for its `finished` signal.
  + Queue a group of Callables using `DispatchQueue.dispatch_group`.
    The returned `DispatchQueue.TaskGroup` can be used to invoke continuation callables using its `then` or `then_deferred` methods after all tasks finished executing, or by awaiting for its `finished` signal.
- `DispatchQueueNode` Node class that wraps a `DispatchQueue`.
  All methods of `DispatchQueue` are available with the same parameters.
- `DispatchQueueResource` Resource class that wraps a `DispatchQueue`.
  All methods of `DispatchQueue` are available with the same parameters.
