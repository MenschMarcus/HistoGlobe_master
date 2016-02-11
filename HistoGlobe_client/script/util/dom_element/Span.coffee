window.HG ?= {}

# ============================================================================
# <span> element

class HG.Span extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[]) ->
    super 'span', id, classes, []