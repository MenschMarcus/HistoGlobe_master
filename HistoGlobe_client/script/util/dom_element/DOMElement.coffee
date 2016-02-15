window.HG ?= {}

class HG.DOMElement

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (elemType, id=null, classes=[], attr=[], existElem=null) ->

    # error handling: if only one class as string given, make it an array
    classes = [classes] if typeof classes is 'string'

    unless existElem
      @_elem = document.createElement elemType        # creates element
      @_elem.id = id if id                            # sets id
      @_elem.classList.add c for c in classes         # adds all classes
      @_elem.setAttribute a[0], a[1] for a in attr    # adds all attributes + values
    else  # take existing element, if given
      @_elem = existElem

    @_j = $(@_elem)                                   # jQuery object

  # ============================================================================
  # append / prepend elements as children to DOM element
  # receive either HG.DOMElement or real DOM element
  appendChild: (child) ->   @_elem.appendChild (@_getDom child)
  prependChild: (child) ->  @_elem.insertBefore (@_getDom child), @_elem.firstChild

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


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _getDom: (elem) ->
    if elem instanceof HG.DOMElement
      return elem.dom()
    else if elem instanceof HTMLElement
      return elem
    else
      console.error "The element you want to append/prepend is neither a HG.DOMElement nor a HTML Element"


