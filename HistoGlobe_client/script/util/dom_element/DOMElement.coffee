window.HG ?= {}


class HG.DOMElement

  # ============================================================================
  constructor: (elemType, id=null, classes=[], src=null, hidden=false) ->

    # error handling: if only one class as string given, make it an array
    classes = [classes] if typeof classes is 'string'

    @_obj = document.createElement elemType         # creates element
    @_obj.id = id if id                             # sets id
    @_obj.classList.add c for c in classes          # adds all classes
    @_obj.src = src if src and elemType is 'img'    # sets img source
    @_obj.href = src if src and elemType is 'a'     # sets anchor link
    @_dom = $(@_obj)                                # saves DOM element
    @_dom.hide() if hidden                          # hides element if given

  # ============================================================================
  append: (child) ->    @_obj.appendChild child.obj()
  prepend: (child) ->   @_obj.insertBefore child.obj(), @_obj.firstChild

  # ============================================================================
  obj: () ->            @_obj
  dom: () ->            @_dom