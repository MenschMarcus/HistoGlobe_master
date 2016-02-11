window.HG ?= {}

class HG.DOMElement

  # ============================================================================
  constructor: (elemType, id=null, classes=[], attr=[]) ->

    # error handling: if only one class as string given, make it an array
    classes = [classes] if typeof classes is 'string'

    @_elem = document.createElement elemType       # creates element
    @_elem.id = id if id                           # sets id
    @_elem.classList.add c for c in classes        # adds all classes
    @_elem.setAttribute a[0], a[1] for a in attr   # adds all attributes + values

    @_j = $(@_elem)                                # jQuery object

  # ============================================================================
  # append / prepend elements to DOM element
  # receive either HG.DOMElement or real DOM element
  append: (child) ->    @_elem.appendChild child.dom()
  prepend: (child) ->   @_elem.insertBefore child.dom(), @_elem.firstChild

  appendChild: (child) ->    @append child
  prependChild: (child) ->   @prepend child

  # ============================================================================
  show: () ->           @_j.show()
  hide: () ->           @_j.hide()

  # ============================================================================
  destroy: () ->        @_j.remove()
  remove: () ->         @_j.remove()

  # ============================================================================
  # return DOM element:     myObj.dom()
  #   or   jQuery element:  myObj.j()
  dom: () ->            @_elem
  j: () ->              @_j
