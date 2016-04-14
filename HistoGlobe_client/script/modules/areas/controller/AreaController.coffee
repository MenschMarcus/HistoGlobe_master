window.HG ?= {}

# debug output?
DEBUG = no

class HG.AreaController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onCreateArea'


    # handle config
    defaultConfig = {}

    @_config = $.extend {}, defaultConfig, config


    # init members
    @_areaHandles = []            # all areas in HistoGlobe ((in)visible, (un)selected, ...)
    @_maxSelections = 1           # 1 = single-selection mode, n = multi-selection mode


    ############################################################################
    # TRASHCAN

    # to AreaHandle?
    @_visibleAreas = []            # set of all HG.AreaHandle's currently visible
    @_selectedAreas = []          # array of all currently visible areas
    @_invisibleAreas = []          # set of all HG.AreaHandle's currently invisible


    # @_hgInstance.editMode.onCreateArea @, (id, geometry) ->
    # @_hgInstance.editMode.onUpdateAreaGeometry @, (id, geometry) ->
    # @_hgInstance.editMode.onUpdateAreaRepresentativePoint @, (id, reprPoint=null) ->
    # @_hgInstance.editMode.onAddAreaName @, (id, shortName, formalName) ->
    # @_hgInstance.editMode.onUpdateAreaName @, (id, shortName, formalName) ->
    # @_hgInstance.editMode.onRemoveAreaName @, (id) ->
    # @_hgInstance.editMode.onRemoveArea @, (id) ->
    # @_hgInstance.editMode.onShowArea @, (id) ->
    # @_hgInstance.editMode.onHideArea @, (id) ->
    # @_hgInstance.editMode.onStartEditArea @, (id) ->
    # @_hgInstance.editMode.onEndEditArea @, (id) ->
    # @_hgInstance.editMode.onSelectArea @, (id) ->
    # @_hgInstance.editMode.onDeselectArea @, (id) ->

    ############################################################################


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.areaController = @



  # ============================================================================
  # Receive a new AreaHandle (from EditMode and DatabaseInterface) and add it to
  # the list and tell the view about it
  # ============================================================================

  addAreaHandle: (areaHandle) ->
    @_areaHandles.push areaHandle
    @notifyAll 'onCreateArea', areaHandle

    # listen to destruction callback and tell everybody about it
    areaHandle.onDestroy @, () =>
      @_areaHandles.splice(@_areaHandles.indexOf(areaHandle), 1)

    @_DEBUG_OUTPUT 'CREATE AREA'


  # ============================================================================
  # set / get Single- and Multi-Selection Mode
  # -> how many areas can be selected at the same time?
  # ============================================================================

  getMaxNumOfSelections: () -> @_maxSelections

  # ------------------------------------------------------------------------
  enableMultiSelection: (num) ->

    # error handling: must be a number and can not be smaller than 1
    if (num < 1) or (isNaN num)
      return console.error "There can not be less than 1 area selected"

    # set maximum number of selections
    @_maxSelections = num

    # if there has been an area already selected in single-selection mode
    # it will still be in the @_selectedAreas array and can stay there,
    # since it will never be deselected

    @_DEBUG_OUTPUT 'ENABLE MULTI SELECTION'

  # ------------------------------------------------------------------------
  disableMultiSelection: () ->

    # restore single-selection mode
    @_maxSelections = 1

    # is it necessary to clean the selected areas or should that be the
    # task of the edit mode?
    # areaHandle.deselect() for areaHandle in @_areaHandles

    @_DEBUG_OUTPUT 'DISABLE MULTI SELECTION'


  # ============================================================================
  # GETTER for areas
  # ============================================================================

  getAreaHandle: (id) ->
    for areaHandle in @_areaHandles
      area = areaHandle.getArea()
      if area.id is id
        return areaHandle
    return null

  # ----------------------------------------------------------------------------
  getAreaHandles: () ->
    @_areaHandles



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _DEBUG_OUTPUT: (id) ->

    return if not DEBUG

    sel = []
    sel.push a.getId() + " (" + a.getShortName() + ")" for a in @_selectedAreas
    edi = []
    edi.push a.getId() + " (" + a.getShortName() + ")" for a in @_editAreas

    console.log id
    console.log "areas (act+inact=all): ", @_visibleAreas.length, "+", @_invisibleAreas.length, "=", @_visibleAreas.length + @_invisibleAreas.length
    console.log "max selections + areas:", @_maxSelections, ":", sel.join(', ')
    console.log "areas (act+inact=all): ", @_activeAreas.length, "+", @_inactiveAreas.length, "=", @_activeAreas.length + @_inactiveAreas.length
    console.log "=============================================================="
