window.HG ?= {}


class HG.DOMElement

  # ============================================================================
  constructor: (elemType, id=null, classes=[], attr=[], hidden=false) ->

    # error handling: if only one class as string given, make it an array
    classes = [classes] if typeof classes is 'string'

    @_elem = document.createElement elemType       # creates element
    @_elem.id = id if id                           # sets id
    @_elem.classList.add c for c in classes        # adds all classes
    @_elem.setAttribute a[0], a[1] for a in attr   # adds all attributes + values
    $(@_elem).hide() if hidden                     # hides element if given

    return @elem()

  # ============================================================================
  append: (child) ->    @_elem.appendChild child.elem()
  prepend: (child) ->   @_elem.insertBefore child.elem(), @_elem.firstChild

  # ============================================================================
  elem: () -> @_elem
