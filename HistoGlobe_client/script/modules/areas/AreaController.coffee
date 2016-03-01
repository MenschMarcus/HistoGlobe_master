window.HG ?= {}

class HG.AreaController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onAddArea'
    @addCallback 'onUpdateAreaGeommetry'
    @addCallback 'onUpdateAreaName'
    @addCallback 'onRemoveArea'

    @addCallback 'onFocusArea'
    @addCallback 'onUnfocusArea'
    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'


    # handle config
    defaultConfig =
      JSONPaths: undefined,

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.areaController = @


    @_activeAreas = []            # set of all HG.Area's (id, geometry, name)

    @_maxSelections = 1           # 1 = single-selection mode, n = multi-selection mode
    @_singleSelectedArea = null   # single-selection mode: currently selected area (only 1!)
    @_multiSelectedAreas = []     # multi-selection mode: array of all currently active areas
    @_areaEditMode = off          # mode in which no area but the untreated ones can be focussed / selected


    @_hgInstance.onAllModulesLoaded @, () =>

      # get area view (currently active viewers for the area)
      areaViewer = []             # all viewer classes manipulating and viewing areas
      areaViewer.push @_hgInstance.areasOnMap?
      areaViewer.push @_hgInstance.areasOnGlobe?

      ### INIT AREAS ###
      # initially load them from file
      # TODO: exchange with real fetcching from the database
      geometryReader = new HG.GeometryReader

      for file in @_config.JSONPaths
        $.getJSON file, (areas) =>
          for area in areas.features
            id = area.id
            geometry = geometryReader.read area.geometry
            # TODO: better name handling
            names = {'commonName': area.properties.name}
            newArea = new HG.Area id, geometry, names
            @_activeAreas.push newArea
            @notifyAll 'onAddArea', newArea


    ### INTERFACE ###

    # ==========================================================================
    ## listen to each viewer (have the same interface)
    for view in areaViewer

      # ------------------------------------------------------------------------
      # hover areas => focus?
      view.onFocusArea @, (area) ->
        if (
          (not area.isFocused()) and              # area has to be unfocused
          (                                       # AND either
            (@_areaEditMode is off) or            # in normal mode (each area can be focussed)
            (                                     # OR
              (@_areaEditMode is on) and          # in edit mode (only the untreated selected ones can be focussed)
              (area.isSelected()) and
              (not area.isTreated())
            )
          )
        ) # focus it!
          area.focus()
          @notifyAll 'onFocusArea', area


      # ------------------------------------------------------------------------
      # unhover areas => unfocus!
      view.onUnfocusArea @, (area) ->
        if area.isFocused()
          area.unfocus()
          @notifyAll 'onUnfocusArea', area

      # ------------------------------------------------------------------------
      # click area => (de)select
      view.onSelectArea @, (area) ->

        if @_maxSelections is 1   # single-selection mode

          # area is selected => deselect
          if area.isSelected()
            area.deselect()
            @notifyAll 'onDeselectArea', area
            # update selected area
            @_singleSelectedArea = null

          # area is deselected => toggle currently selected area <-> new selection
          else
            # deselect currently selected area
            @_singleSelectedArea.deselect()
            @notifyAll 'onDeselectArea', @_singleSelectedArea
            # select newly selected area
            area.select()
            @notifyAll 'onSelectArea', area
            # update selected area
            @_singleSelectedArea = area

        else                      # multi-selection mode

          # area is selected => deselect
          if area.isSelected()
            area.deselect()
            @notifyAll 'onDeselectArea', area
            # update selected area
            @_multiSelectedAreas.splice (@_multiSelectedAreas.indexOf area), 1

          # if maximum number of selections not reached => select it
          else if @_multiSelectedAreas.length < @_maxSelections
            area.select()
            @notifyAll 'onSelectArea', area
            # update selected areas
            @_multiSelectedAreas.push area


    # ==========================================================================
    ## listen to Edit Mode

    # --------------------------------------------------------------------------
    @_hgInstance.editMode.onEnableMultiSelection @, (num) ->
      # enable multi-selection mode
      @_maxSelections = num
      # make currently selected area from single-selection mode the first selected areas
      @_multiSelectedAreas.push @_singleSelectedArea if @_singleSelectedArea?

    # --------------------------------------------------------------------------
    @_hgInstance.editMode.onDisableMultiSelection @, () ->
      # enable single-selection mode
      @_maxSelections = 1
      # deselect each area
      # -> except for the initially selected one one from last single-selection mode
      for area in @_multiSelectedAreas
        if not (@_singleSelectedArea? and area.getId() is @_singleSelectedArea.getId())
          area.deselect()
          @notifyAll 'onDeselectArea', area
      # reset selected areas
      @_multiSelectedAreas = []

    # --------------------------------------------------------------------------
    @_hgInstance.editMode.onStartAreaEdit @, () ->
      @_areaEditMode = on

    @_hgInstance.editMode.onFinishAreaEdit @, () ->
      @_areaEditMode = off

    # --------------------------------------------------------------------------
    @_hgInstance.editMode.onAddArea @, (area) ->
      @_activeAreas.push area

    @_hgInstance.editMode.onRemoveArea @, (area) ->
      @_activeAreas.splice (@_activeAreas.indexOf area), 1



  # ============================================================================
  getAreas: () -> @_activeAreas

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################