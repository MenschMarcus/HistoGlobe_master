window.HG ?= {}

# ============================================================================
# <i> element

class HG.Icon extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[]) ->
    super 'i', id, classes, []