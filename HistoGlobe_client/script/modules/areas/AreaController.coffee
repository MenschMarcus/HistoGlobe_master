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

    @addCallback 'onCreateArea'
    @addCallback 'onCreateAreaGeometry'
    @addCallback 'onCreateAreaName'
    @addCallback 'onUpdateAreaGeometry'
    @addCallback 'onUpdateAreaName'
    @addCallback 'onUpdateAreaStatus'
    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'
    @addCallback 'onRemoveArea'
    @addCallback 'onRemoveAreaName'


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
      areaViewer.push @_hgInstance.areasOnMap     if @_hgInstance.areasOnMap?
      areaViewer.push @_hgInstance.areasOnGlobe   if @_hgInstance.areasOnGlobe?

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
            @notifyAll 'onCreateArea', newArea


      ### INTERFACE ###

      # ========================================================================
      ## listen to each viewer (have the same interface)
      for view in areaViewer

        # ----------------------------------------------------------------------
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
            @notifyAll 'onUpdateAreaStatus', area


        # ----------------------------------------------------------------------
        # unhover areas => unfocus!
        view.onUnfocusArea @, (area) ->
          if area.isFocused()
            area.unfocus()
            @notifyAll 'onUpdateAreaStatus', area

        # ----------------------------------------------------------------------
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
              if @_singleSelectedArea
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


      # ========================================================================
      ## listen to Edit Mode

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEnableMultiSelection @, (num) ->
        # enable multi-selection mode
        @_maxSelections = num
        # make currently selected area from single-selection mode the first selected areas
        if @_singleSelectedArea?
          @_multiSelectedAreas.push @_singleSelectedArea
          # tell the SelectOldAreas step, so it can add it to its internal list
          @notify 'onSelectArea', @_hgInstance.areasOnMap, @_singleSelectedArea

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableMultiSelection @, () ->
        # enable single-selection mode
        @_maxSelections = 1
        # deselect each area
        # -> except for the initially selected one one from last single-selection mode
        for area in @_multiSelectedAreas
          if not (@_singleSelectedArea? and area.getId() is @_singleSelectedArea.getId())
            area.deselect()
            # N.B. do not notify selectOldAreas step, because that would remove the areas from their internal array
            @notifyAllBut 'onDeselectArea', @_hgInstance.selectOldAreasStep, area
        # reset selected areas
        @_multiSelectedAreas = []

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onStartAreaEdit @, () ->
        @_areaEditMode = on

      @_hgInstance.editMode.onFinishAreaEdit @, () ->
        @_areaEditMode = off
        area.untreat() for area in @_activeAreas

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onCreateArea @, (id, geometry, names, treated=no) ->
        newArea = new HG.Area id, geometry, names
        newArea.select()
        newArea.treat() if treated
        @_activeAreas.push newArea
        if names
          @notifyAll 'onCreateArea', newArea
        else
          @notifyAll 'onCreateAreaGeometry', newArea

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaGeommetry @, (id, geometry) ->
        area = @getArea id
        if area
          area.setGeometry geometry
          @notifyAll 'onUpdateAreaGeometry', area

      # ------------------------------------------------------------------------
      # TODO: better name handling
      @_hgInstance.editMode.onUpdateAreaName @, (id, names=null, position=null) ->
        area = @getArea id
        hadNameBefore = area.getNames().commonName?
        if area
          if names
            area.setNames names
            area.setLabelPosition position if position
            if not hadNameBefore
              @notifyAll 'onCreateAreaName', area
            else
              @notifyAll 'onUpdateAreaName', area
          else # if name empty
            @notifyAll 'onRemoveAreaName', area

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaStatus @, (id, treated=no) ->
        area = @getArea id
        if area
          area.select()
          if treated is yes then area.treat() else area.untreat()
          @notifyAll 'onUpdateAreaStatus', area

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRemoveArea @, (id) ->
        area = @getArea id
        if area
          @_activeAreas.splice (@_activeAreas.indexOf area), 1
          @notifyAll 'onRemoveArea', area

      # ------------------------------------------------------------------------


  # ============================================================================
  getAreas: () -> @_activeAreas

  # ----------------------------------------------------------------------------
  getArea: (id) ->
    for area in @_activeAreas
      if area.getId() is id
        return area
        break
    return null

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################