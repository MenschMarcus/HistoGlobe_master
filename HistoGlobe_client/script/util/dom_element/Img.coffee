window.HG ?= {}

# ============================================================================
# <img src=''>

class HG.Img extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], source) ->
    super 'img', id, classes, [['src', source]]