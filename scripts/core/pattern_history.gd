## pattern_history.gd
## Undo / redo stack for grid snapshots.
## Operates purely on data arrays; knows nothing about the UI.
class_name PatternHistory
extends RefCounted

const MAX_UNDO := 32

var _undo_stack: Array = []
var _redo_stack: Array = []


## Push the current state before a destructive action.
func push(snapshot: Array) -> void:
	_undo_stack.append(snapshot)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.remove_at(0)
	_redo_stack.clear()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


## Returns the state to restore. Pass the current snapshot so it can be
## pushed onto the redo stack. Returns [current_snapshot] unchanged if empty.
func undo(current_snapshot: Array) -> Array:
	if _undo_stack.is_empty():
		return current_snapshot
	_redo_stack.append(current_snapshot)
	return _undo_stack.pop_back()


func redo(current_snapshot: Array) -> Array:
	if _redo_stack.is_empty():
		return current_snapshot
	_undo_stack.append(current_snapshot)
	return _redo_stack.pop_back()
