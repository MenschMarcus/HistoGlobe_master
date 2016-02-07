window.HG ?= {}

# ============================================================================
# <div> element, its DOM element and its object counterpart inside code
# parameters:
#   id        'id' of a in dom
#   classes   ['className1', 'className2', ...] (if many)
#   href      anchor_link
#   hidden    true (optional, if not stated, not hidden)

class HG.Anchor extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], href, hidden=false) ->
    super 'a', id, classes, href, hidden