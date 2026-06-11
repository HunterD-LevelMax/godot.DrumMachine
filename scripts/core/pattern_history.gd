## pattern_history.gd
## Undo / redo stack for complete pattern snapshots.
class_name PatternHistory
extends RefCounted

const MAX_UNDO := 32

var _undo_stack: Array[PatternState] = []
var _redo_stack: Array[PatternState] = []


func push(snapshot: PatternState) -> void:
	_undo_stack.append(snapshot.duplicate_state())
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.remove_at(0)
	_redo_stack.clear()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo(current_snapshot: PatternState) -> PatternState:
	if _undo_stack.is_empty():
		return current_snapshot
	_redo_stack.append(current_snapshot.duplicate_state())
	return _undo_stack.pop_back()


func redo(current_snapshot: PatternState) -> PatternState:
	if _redo_stack.is_empty():
		return current_snapshot
	_undo_stack.append(current_snapshot.duplicate_state())
	return _redo_stack.pop_back()


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
