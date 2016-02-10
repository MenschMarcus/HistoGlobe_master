window.HG ?= {}

# ============================================================================
# <a> element, its DOM element and its object counterpart inside code
# arguments:
#   id        'id' in dom
#   classes   ['className1', 'className2', ...] (if many)
#   href      anchor_link
#   hidden    true (optional, if not stated, not hidden)

class HG.Anchor extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], href, hidden=false) ->
    super 'a', id, classes, [['href', href]], hidden