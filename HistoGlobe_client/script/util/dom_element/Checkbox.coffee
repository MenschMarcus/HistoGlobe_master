window.HG ?= {}

# ============================================================================
# <input type='checkbox'> element, its DOM element and its object counterpart inside code
# arguments:
#   id        'id' in dom
#   classes   ['className1', 'className2', ...] (if many)
#   hidden    true (optional, if not stated, not hidden)

class HG.Checkbox extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], hidden=false) ->
    super 'input', id, classes, [['type', 'checkbox'], ['name', id]], hidden