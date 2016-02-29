window.HG ?= {}

# ============================================================================
# <a> element

class HG.Anchor extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], href, existElem=null) ->
    super 'a', id, classes, [['href', href]], existElem