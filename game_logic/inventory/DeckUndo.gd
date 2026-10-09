## Undo stack for deck-table edits (GID-180 / TID-737). Every deck change
## auto-saves, so undo is the safety net that replaced the Save Deck button.
## Pure: snapshots are plain uid lists.
extends RefCounted

const CAP: int = 20

var _stack: Array = []


## Records the deck as it was before an edit. No-op when it equals the last snapshot.
func push(deck: Array[String]) -> void:
	if not _stack.is_empty() and (_stack.back() as Array) == Array(deck):
		return
	var snap: Array[String] = []
	snap.assign(deck)
	_stack.append(snap)
	if _stack.size() > CAP:
		_stack.pop_front()


func can_undo() -> bool:
	return not _stack.is_empty()


## The previous deck, or [] when there is nothing to undo.
func pop() -> Array[String]:
	var out: Array[String] = []
	if not _stack.is_empty():
		out.assign(_stack.pop_back() as Array)
	return out


func clear() -> void:
	_stack.clear()
