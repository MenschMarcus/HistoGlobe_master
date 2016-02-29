window.HG ?= {}

# ============================================================================
# <a> element

class HG.Anchor extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], [href, text], existElem=null) ->
    super 'a', id, classes, [['href', href]], existElem
    # set text
    @_j.html text

