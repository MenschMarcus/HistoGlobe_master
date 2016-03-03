window.HG ?= {}

class HG.NewNameTool

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, initName, posLatLng) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onChangeName'
    @addCallback 'onSubmit'

    # setup variables
    @_map = @_hgInstance.map._map
    @_histoGraph = @_hgInstance.histoGraph
    @_viewCenter = @_map.getCenter()


    ### SETUP UI ###

    # PROBLEM:
    # I need a text field with the following three characterstics:
    # 1. it needs to be in the coordinate system of the world
    # 2. it needs to be draggable
    # 3. its text needs to be editable

    # POSSIBLE SOLUTIONS:
    # A) use Leaflet element
    #   (+) in coordinate system
    #   (-) no element is both draggable and editable
    # => not possible without reimplementation of leaflet features!
    # B) use HTML text input in the view point
    #   (+) draggable and editable
    #   (-) not in coordinate system
    #   (-) position does not update on zoom / pan of the map
    # => possible, but hard...

    @_wrapper = new HG.Div 'new-name-wrapper', null
    @_hgInstance._top_area.appendChild @_wrapper.dom()

    @_inputField = new HG.TextInput @_hgInstance, 'new-name-input', null
    if initName   # set either the text that is given (to just accept it)
      @_inputField.setText initName
    else          # or have only a placeholder
      @_inputField.setPlaceholder 'name'
    @_inputField.j().attr 'size', NAME_MIN_SIZE
    @_wrapper.appendChild @_inputField

    # set position of wrapper = center of country
    posPx = @_map.latLngToContainerPoint posLatLng
    @_wrapper.j().css 'left', posPx.x
    @_wrapper.j().css 'top',  posPx.y
    @_recenter()

    @_okButton = new HG.Button @_hgInstance,
      'newNameOK', ['confirm-button'],
      [
        {
          'iconFA':   'check'
        }
      ]
    @_wrapper.appendChild @_okButton.dom()


    ### INTERACTION ###
    ## to other modules

    # seamless interaction
    @_makeDraggable()
    @_inputField.j().on 'keydown keyup click each', @_resize
    @_map.on 'drag',    @_respondToMapDrag
    @_map.on 'zoomend', @_respondToMapZoom

    # type name => change name
    @_inputField.j().on 'keyup mouseup', (e) =>
      @notifyAll 'onChangeName', @_inputField.j().val()

    # click OK => submit name and position
    @_okButton.onClick @, () =>
      # get center coordinates
      # offset = @_wrapper.j().position()
      # width = @_wrapper.j().width()
      # height = @_wrapper.j().height()
      # center = L.point offset.left + width / 2, offset.top + height / 2
      center = new L.Point @_wrapper.j().position().left, @_wrapper.j().position().top
      #                      common name             label position
      @notifyAll 'onSubmit', @_inputField.j().val(), @_map.containerPointToLatLng center

    ## from other modules



  # ============================================================================
  destroy: () ->
    # detach event handlers from map
    @_map.off 'zoomend', @_respondToMapZoom
    @_map.off 'drag',    @_respondToMapDrag
    # remove UI elements + their interaction
    @_okButton.remove()
    @_inputField.remove()
    @_wrapper.remove()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _recenter: () ->
    @_wrapper.j().css 'margin-top', -(@_wrapper.j().height() / 2)
    @_wrapper.j().css 'margin-left', -(@_wrapper.j().width() / 2)

  # ============================================================================
  # preparation functions

  # ============================================================================
  _makeDraggable: () ->
    # make input field draggable
    # this code snippet does MAGIC !!!
    # credits to: A. Wolff
    # http://stackoverflow.com/questions/22814073/how-to-make-an-input-field-draggable
    # http://jsfiddle.net/9SPvQ/2/
    @_wrapper.j().draggable start: (event, ui) ->
      $(this).data 'preventBehaviour', true

    @_inputField.j().on 'mousedown', (e) =>
      mdown = document.createEvent 'MouseEvents'
      mdown.initMouseEvent 'mousedown', true, true, window, 0, e.screenX, e.screenY, e.clientX, e.clientY, true, false, false, true, 0, null
      @_wrapper.dom().dispatchEvent mdown
      return # for some reason this has to be there ?!?

    @_inputField.j().on 'click', (e) =>
      if @_wrapper.j().data 'preventBehaviour'
        e.preventDefault()
        @_wrapper.j().data 'preventBehaviour', false
      return # for some reason this has to be there ?!?

  # ============================================================================
  _resize: (e) =>
    # TODO: set actual width, independent from font-size
    # TODO: animate to the new width -> works not with 'size' but only with 'width' (size is not a CSS property)
    #                ensures width >= 1                             magic factor to scale width with increasing size
    width = Math.max NAME_MIN_SIZE, (@_inputField.j().val().length)*SIZE_TO_WIDTH_FACTOR
    @_inputField.j().attr 'size', width
    @_recenter()

  # ============================================================================
  _respondToMapDrag: (e) =>
    # this is probably more complicated than necessary - but it works :)
    # get movement of center of the map (as reference)
    mapOld = @_viewCenter
    mapNew = @_map.getCenter()
    ctrOld = @_map.latLngToContainerPoint mapOld
    ctrNew = @_map.latLngToContainerPoint mapNew
    ctrDist = [
      (ctrNew.x - ctrOld.x),
      (ctrNew.y - ctrOld.y)
    ]
    # project movement to wrapper
    inputOld = @_wrapper.j()
    inputNew = L.point(
      (inputOld.position().left) - ctrDist[0], # x
      (inputOld.position().top) - ctrDist[1]  # y
    )
    @_wrapper.j().css 'left', inputNew.x
    @_wrapper.j().css 'top', inputNew.y
    # refresh
    @_viewCenter = mapNew

  # ============================================================================
  _respondToMapZoom: (e) =>
    @_viewCenter = @_map.getCenter() # to prevent jumping label on drag after zoom
    # TODO: get to work
    # zoomCenter = @_map.latLngToContainerPoint e.target._initialCenter
    # zoomFactor = @_map.getScaleZoom()
    # windowCenterStart = @_inputCenter

    # windowCenterEnd = L.point(
    #   zoomCenter.x - ((zoomCenter.x - windowCenterStart.x) / zoomFactor),
    #   zoomCenter.y - ((zoomCenter.y - windowCenterStart.y) / zoomFactor)
    # )

    # console.log e
    # console.log zoomCenter
    # console.log zoomFactor
    # console.log windowCenterStart
    # console.log windowCenterEnd


  # ============================================================================
  NAME_MIN_SIZE = 4
  SIZE_TO_WIDTH_FACTOR = 1.15   # magical factor to translate from text input size to its width
