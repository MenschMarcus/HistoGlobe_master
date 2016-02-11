window.HG ?= {}

# ============================================================================
# <div> element

class HG.Div extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[]) ->
    super 'div', id, classes, []