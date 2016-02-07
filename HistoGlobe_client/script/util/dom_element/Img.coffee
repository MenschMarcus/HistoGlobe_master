window.HG ?= {}

# ============================================================================
# <div> element, its DOM element and its object counterpart inside code
# parameters:
#   id        'id' of div in dom
#   classes   ['className1', 'className2', ...] (if many)
#   source    path_to_image
#   hidden    true (optional, if not stated, not hidden)

class HG.Img extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], source, hidden=false) ->
    super 'img', id, classes, source, hidden