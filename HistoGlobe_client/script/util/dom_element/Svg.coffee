window.HG ?= {}

# ============================================================================
# <div> element, its DOM element and its object counterpart inside code
# parameters:
#   id        'id' of div in dom
#   classes   ['className1', 'className2', ...] (if many)
#   hidden    true (optional, if not stated, not hidden)

class HG.Svg extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], hidden=false) ->
    super 'svg', id, classes, null, hidden