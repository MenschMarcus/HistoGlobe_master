window.HG ?= {}

class HG.AreaController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  TIME_LEAP_THRESHOLD = 20 # years -> how many years so that transition areas are not shown?

  # ============================================================================
  constructor: (config) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onAddArea"
    @addCallback "onRemoveArea"
    @addCallback "onUpdateAreaStyle"
    @addCallback "onFadeInArea"
    @addCallback "onFadeOutArea"
    @addCallback "onFadeInBorder"
    @addCallback "onFadeOutBorder"
    @addCallback "onAddLabel"
    @addCallback "onRemoveLabel"
    @addCallback "onUpdateLabelStyle"
    @addCallback "onLabelsLoaded"


    @_timeline        = null
    @_now             = null
    @_theme           = ''
    @_isHighContrast  = no

    defaultConfig =
      areaJSONPaths: undefined,
      labelJSONPaths: undefined,
      changeJSONPaths: undefined,
      transitionJSONPaths: undefined,

    conf = $.extend {}, defaultConfig, config

    # area handling
    @_areas = []        # set of all HG areas (id, geometry, ...)
    @_labels = []       # set of all HG labels (id, name, position, ...)
    @_changes = []      # set of all historic changes
    @_transitions = []   # set of all transition areas (id, type, geometry)

    # main queue, each element describes one area change
    @_changeQueue = new Queue()

    # initially load areas from input files
    @_areasLoaded = no
    @_labelsLoaded = no
    @_changesLoaded = no
    @_transitionsLoaded = yes
    @_loadAreasFromJSON conf
    @_loadLabelsFromJSON conf
    @_loadChangesFromJSON conf
    @_loadTransitionsFromJSON conf

    # problem: initially aloso transition areas and borders are shown, but that is not desired
    # -> introduce "initStatus"
    @_initStatus = yes

  # ============================================================================
  hgInit: (hgInstance) ->

    hgInstance.areaController = @

    @_aniTime = hgInstance._config.areaAniTime
    @_timeline = hgInstance.timeline
    @_now = new Date -5000, 0, 1  # horrible init start year hack

    @_styler = hgInstance.styler

    # main activity: what happens if now date changes?
    @_timeline.onNowChanged @, (date) ->
      if @_areasLoaded and @_labelsLoaded and @_changesLoaded and @_transitionsLoaded
        # update countries
        oldDate = @_now
        newDate = date
        @_updateCountries oldDate, newDate
        # update styles
        for area in @_areas
          @_updateAreaStyle area
        for label in @_labels
          @_updateLabelStyle label
        # update now date
        @_now = date

    hgInstance.onAllModulesLoaded @, () =>
      hgInstance.hivent_list_module?.onUpdateTheme @, (theme) =>
        @_theme = theme
        for area in @_areas
          @_updateAreaStyle area
        for label in @_labels
          @_updateLabelStyle label

    # toggle highContrast mode
    hgInstance.highcontrast_button.onEnterHighContrast @, () =>
      @_isHighContrast = yes
      for area in @_areas
        @notifyAll "onUpdateAreaStyle", area, @_isHighContrast
      for label in @_labels
        @notifyAll "onUpdateLabelStyle", label, @_isHighContrast

    hgInstance.highcontrast_button.onLeaveHighContrast @, () =>
      @_isHighContrast = no
      for area in @_areas
        @notifyAll "onUpdateAreaStyle", area, @_isHighContrast
      for label in @_labels
        @notifyAll "onUpdateLabelStyle", label, @_isHighContrast

    # infinite loop that executes all changes in the queue
    mainLoop = setInterval () =>    # => is important to be able to access global variables (compared to ->)
      @_doChanges()
    , 1000 # TODO: change back to 50

  # ============================================================================
  getAllAreas: () ->
    return @_areas

  # ============================================================================
  getAllLabels: () ->
    return @_labels

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # DYNAMICS
  # ============================================================================


  # ============================================================================
  # add all new and remove all old areas to map/globe
  # and emphasize transition areas (areas that move from one country to another)

  _updateCountries: (oldDate, newDate) ->

    # change direction: forwards (+1) or backwards (-1) ?
    # changes are sorted the other way!
    changeDir = 1
    if oldDate > newDate
      changeDir = -1
      # swap old and new date, so it can be assumed that always oldDate < newDate
      tempDate = oldDate
      oldDate = newDate
      newDate = tempDate

    timeLeap = Math.abs(oldDate.getFullYear() - newDate.getFullYear())

    # idea: go through all changes in (reversed) order
    # check if the change date is inside the change range from the old to the new date
    # as soon as one change is inside, all changes will be executed until  one change is outside the range
    # -> then termination of the loop
    enteredChangeRange = no
    for change in @_changes by changeDir
      if change.date >= oldDate and change.date < newDate

        hasTransition = no

        # fade-in transition area and border
        # but not in the initialisation of the countries
        # and not if scrolled too far
        if not @_initStatus and timeLeap < TIME_LEAP_THRESHOLD
          if change.trans_area?
            transArea = @_getTransitionById change.trans_area
            @notifyAll "onFadeInArea", transArea, yes
            hasTransition = yes

          if change.trans_border?
            transBorder = @_getTransitionById change.trans_border
            @notifyAll "onFadeInBorder", transBorder, yes
            hasTransition = yes

        # enqueue new change
        newChange =
          {
            timestamp   : null    # timestamp at wich changes shall be executed
            oldAreas    : []      # areas to be deleted
            newAreas    : []      # areas to be added
            oldLabels   : []      # labels to be deleted
            newLabels   : []      # labels to be added
            transArea   : null    # regions to be faded out when change is done
            transBorder : null    # borders to be faded out when change is done
          }

        ts = new Date()
        if hasTransition
          ts.setMilliseconds ts.getMilliseconds() + @_aniTime
        newChange.timestamp = ts

        for id in change.new_areas
          newChange.newAreas.push id if changeDir is 1
          newChange.oldAreas.push id if changeDir is -1

        for id in change.old_areas
          newChange.oldAreas.push id if changeDir is 1      # timeline moves forward => old areas are old areas
          newChange.newAreas.push id if changeDir is -1     # timeline moves backward => old areas are new areas

        for id in change.new_labels
          newChange.newLabels.push id if changeDir is 1
          newChange.oldLabels.push id if changeDir is -1

        for id in change.old_labels
          newChange.oldLabels.push id if changeDir is 1
          newChange.newLabels.push id if changeDir is -1

        if change.trans_area?
          newChange.transArea = change.trans_area

        if change.trans_border?
          newChange.transBorder = change.trans_border

        # remove duplicates -> all areas/labels that are both in new or old array
        # TODO: O(n²) in the moment -> does that get better?
        iNew = 0
        iOld = 0
        lenNew = newChange.newAreas.length
        lenOld = newChange.oldAreas.length
        while iNew < lenNew
          while iOld < lenOld
            if newChange.newAreas[iNew] == newChange.oldAreas[iOld]
              newChange.newAreas[iNew] = null
              newChange.oldAreas[iOld] = null
              break
            ++iOld
          ++iNew

        iNew = 0
        iOld = 0
        lenNew = newChange.newLabels.length
        lenOld = newChange.oldLabels.length
        while iNew < lenNew
          while iOld < lenOld
            if newChange.newLabels[iNew] == newChange.oldLabels[iOld]
              newChange.newLabels[iNew] = null
              newChange.oldLabels[iOld] = null
              break
            ++iOld
          ++iNew

        # finally enqueue distinct changes
        @_changeQueue.enqueue newChange

        enteredChangeRange = yes

      else break if enteredChangeRange

    # show transition areas and borders from now on
    @_initStatus = no


  # ============================================================================
  # updates the style values for one area

  _updateAreaStyle: (area) ->
    oldThemeClass = area.getActiveThemeClass()
    newThemeClass = 'normal'    # initially normal class, if not overwritten

    # if currently a theme active
    if @_theme?
      # check if area has a class in this theme
      themeClasses = area.getThemeClasses @_theme
      if themeClasses?
        for themeClass in themeClasses
          if @_now >= themeClass.startDate and @_now < themeClass.endDate
            newThemeClass = themeClass.className
            break

    if (oldThemeClass.localeCompare newThemeClass) != 0   # N.B.! this took so long to find out how to actually compare if two strings are NOT equal in CoffeeScript...
      area.setActiveThemeClass @_theme, newThemeClass

      # enqueue change in change queue
      newChange =
        {
          timestamp   : new Date()    # style change will be executed immediately
          updateArea  : area          # area to be style-changed
        }
      @_changeQueue.enqueue newChange

    return

  # ============================================================================
  # updates the style values for one area

  _updateLabelStyle: (label) ->
    oldThemeClass = label.getActiveThemeClass()
    newThemeClass = 'normal'    # initially normal class, if not overwritten

    # if currently a theme active
    if @_theme?
      # check if label has a class in this theme
      themeClasses = label.getThemeClasses @_theme
      if themeClasses?
        for themeClass in themeClasses
          if @_now >= themeClass.startDate and @_now < themeClass.endDate
            newThemeClass = themeClass.className
            break

    if (oldThemeClass.localeCompare newThemeClass) != 0   # N.B.! this took so long to find out how to actually compare if two strings are NOT equal in CoffeeScript...
      label.setActiveThemeClass @_theme, newThemeClass

      # enqueue change in change queue
      newChange =
        {
          timestamp   : new Date()    # style change will be executed immediately
          updateLabel : label          # area to be style-changed
        }
      @_changeQueue.enqueue newChange

    return

  # ============================================================================
  # find next ready area change and execute it (one at a time)
  _doChanges: () ->

    # execute change if it is ready
    while not @_changeQueue.isEmpty()

      # check if first element in queue is ready (timestamp is reached)
      break if @_changeQueue.peek().timestamp > new Date()

      # get next change
      change = @_changeQueue.dequeue()

      # add all new areas
      # -> update the style before, so it has the correct style in the mmoment it is on the map
      if change.newAreas?
        for id in change.newAreas
          area = @_getAreaById id
          if area?
            area.setActive()
            @_updateAreaStyle area
            @notifyAll "onAddArea", area

      # remove all old areas
      # -> update the style before, so it has the correct style in the mmoment it is on the map
      if change.oldAreas?
        for id in change.oldAreas
          area = @_getAreaById id
          if area?
            area.setInactive()
            # @_updateAreaStyle area
            @notifyAll "onRemoveArea", area

      # add all new labels
      if change.newLabels?
        for id in change.newLabels
          label = @_getLabelById id
          if label?
            label.setActive()
            @_updateLabelStyle label
            @notifyAll "onAddLabel", label

      # remove all old labels
      if change.oldLabels?
        for id in change.oldLabels
          label = @_getLabelById id
          if label?
            label.setInactive()
            # @_updateLabelStyle label
            @notifyAll "onRemoveLabel", label

      # fade-out transition area
      if change.transArea?
        @notifyAll "onFadeOutArea", @_getTransitionById change.transArea

      # fade-out transition border
      if change.transBorder?
        @notifyAll "onFadeOutBorder", @_getTransitionById change.transBorder

      # update style changes
      if change.updateArea? and change.updateArea.isActive()
        @notifyAll "onUpdateAreaStyle", change.updateArea, @_isHighContrast

      if change.updateLabel? and change.updateLabel.isActive()
        @notifyAll "onUpdateLabelStyle", change.updateLabel, @_isHighContrast


  # ============================================================================
  # PREPARATION
  # ============================================================================

  # ============================================================================
  _loadAreasFromJSON: (config) ->

    # parse each geojson file
    for file in config.areaJSONPaths
      $.getJSON file, (areas) =>
        numAreasToLoad = areas.features.length  # counter
        for area in areas.features

          # parse file asynchronously
          executeAsync = (area) =>
            setTimeout () =>

              # meta
              areaId    = area.properties.id
              type      = 'country'

              # get geometry
              geometry = @_geometryFromGeoJSONToLeaflet area

              # create HG area
              newArea = new HG.Area areaId, type, geometry, @_styler

              # set initial style
              if @_theme?
                # check if area has a class in this theme
                nowDate = @_timeline.getNowDate
                themeClasses = newArea.getThemeClasses @_theme
                if themeClasses?
                  for themeClass in themeClasses
                    if nowDate >= themeClass.startDate and nowDate < themeClass.endDate
                      newThemeClass = themeClass.className
                      break

              # fill areas array
              @_areas.push newArea

              # one less area to go
              numAreasToLoad--
              if numAreasToLoad is 0
                @_areasLoaded = yes

            , 0 # execute immediately

          executeAsync area

  # ============================================================================
  _loadLabelsFromJSON: (config) ->

    # parse each geojson file
    for file in config.labelJSONPaths
      $.getJSON file, (labels) =>
        numLabelsToLoad = labels.features.length  # counter

        for label in labels.features

          # parse file asynchronously
          executeAsync = (label) =>
            setTimeout () =>

              # if the label actually exists
              if label.geometry.coordinates[0]?

                id          = label.properties.id
                name        = label.properties.name
                prio        = label.properties.prio
                coordinates = label.geometry.coordinates

                newLabel = new HG.AreaLabel id, name, prio, coordinates, @_styler                        # styler

                # set initial style
                if @_theme?
                  # check if label has a class in this theme
                  nowDate = @_timeline.getNowDate
                  themeClasses = newLabel.getThemeClasses @_theme
                  if themeClasses?
                    for themeClass in themeClasses
                      if nowDate >= themeClass.startDate and nowDate < themeClass.endDate
                        newThemeClass = themeClass.className
                        break

                # fill labels array
                @_labels.push newLabel

              # one less label to go
              numLabelsToLoad--
              if numLabelsToLoad is 0
                @_labelsLoaded = yes
                @notifyAll "onLabelsLoaded"

            , 0 # execute immediately

          executeAsync label

  # ============================================================================
  _loadChangesFromJSON: (config) ->

    # parse each geojson file
    for file in config.changeJSONPaths
      $.getJSON file, (changes) =>
        numChangesToLoad = changes.features.length  # counter

        for change in changes.features

          # parse file asynchronously
          executeAsync = (change) =>
            setTimeout () =>

              # create JavaScript Date
              change.date = new Date change.date.toString()

              # fill labels array
              @_changes.push change

              # one less change to go
              numChangesToLoad--
              if numChangesToLoad is 0
                @_changesLoaded = yes

            , 0 # execute immediately

          executeAsync change


  # ============================================================================
  _loadTransitionsFromJSON: (config) ->

    # parse each geojson file
    for file in config.transitionJSONPaths
      $.getJSON file, (transitions) =>
        numTransitionsToLoad = transitions.features.length  # counter
        for transition in transitions.features

          # parse file asynchronously
          executeAsync = (transition) =>
            setTimeout () =>

              id        = transition.properties.id
              type      = transition.properties.type
              geometry  = @_geometryFromGeoJSONToLeaflet transition

              # creates new "area", even if transBorder is actually no "area" in a sense
              newTrans = new HG.Area id, type, geometry, @_styler, 'highlight'

              # fill areas array
              @_transitions.push newTrans

              # one less area to go
              numTransitionsToLoad--
              if numTransitionsToLoad is 0
                @_transitionsLoaded = yes

            , 0 # execute immediately

          executeAsync transition

  # ============================================================================
  # transform geometry from geojson into leaflet layer
  _geometryFromGeoJSONToLeaflet: (inGeoJSON) ->
    geometry = []

    # error handling: empty layer because of non-existing geometry
    if inGeoJSON.geometry.coordinates.length is 0
      geometry = [[]]

    else
      data = L.GeoJSON.geometryToLayer inGeoJSON
      if inGeoJSON.geometry.type is "Polygon" or inGeoJSON.geometry.type is "LineString"
        geometry.push data._latlngs
      else if inGeoJSON.geometry.type is "MultiPolygon" or inGeoJSON.geometry.type is "MultiLineString"
        for id, layer of data._layers
          geometry.push layer._latlngs

    geometry

  # ============================================================================
  # find area/label
  _getAreaById: (id) ->
    if id?
      for area in @_areas
        if area.getId() is id
          return area
    undefined

  _getTransitionById: (id) ->
    if id?
      for trans in @_transitions
        if trans.getId() is id
          return trans
    undefined

  _getLabelById: (id) ->
    if id?
      for label in @_labels
        if label.getId() is id
          return label
    undefined
