window.HG ?= {}

# ============================================================================
# <svg> element

class HG.Svg extends HG.DOMElement

  # ============================================================================
  constructor: (id=null, classes=[], dim=[]) ->
    super 'svg', id, classes, [['width',dim[0]], ['height',dim[1]]]