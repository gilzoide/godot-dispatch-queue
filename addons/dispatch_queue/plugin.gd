tool
extends EditorPlugin

const DispatchQueueNode = preload("res://addons/dispatch_queue/dispatch_queue_node.gd")


func _enter_tree() -> void:
	add_custom_type("DispatchQueueNode", "Node", DispatchQueueNode, null)


func _exit_tree() -> void:
	remove_custom_type("DispatchQueueNode")
