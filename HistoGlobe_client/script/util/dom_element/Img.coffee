window.HG ?= {}

# ============================================================================
# <img src=''> element, its DOM element and its object counterpart inside code
# arguments:
#   id        'id' in dom
#   classes   ['className1', 'className2', ...] (if many)
#   source    path_to_image
#   hidden    true (optional, if not stated, not hidden)

class HG.Img extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], source, hidden=false) ->
    super 'img', id, classes, [['src', source]], hidden