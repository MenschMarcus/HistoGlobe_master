window.HG ?= {}

class HG.PathController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    defaultConfig =
      pathCSVPaths: []
      delimiter: "|"
      ignoredLines: [] # line indices starting at 1
      indexMappings:
        "ID"              : 0
        "startHivent"     : 1
        "endHivent"       : 2
        "coordsInBetween" : 3
        "category"        : 4
        "type"            : 5
        "movingMarker"    : 6
        "startMarker"     : 7
        "endMarker"       : 8

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.pathController = @

    @_hiventController = hgInstance.hiventController

    unless @_hiventController?
      console.warn "Failed to init PathController: No hiventController module detected!"
      return

    @_timeline = hgInstance.timeline

    @_paths = []
    @_now = @_timeline.getNowDate()
    @_currentCategoryFilter = null

    # @_hiventController.onAllHiventsLoaded @, @_load

    @_timeline.onNowChanged @, (date) ->
      @_now = date
      @_filterPaths()
      for path in @_paths
        path.setDate date

  # ============================================================================
  setCategoryFilter: (categoryFilter) ->
    @_currentCategoryFilter = categoryFilter
    @_filterPaths()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _load: () =>
    parse_config =
      delimiter: @_config.delimiter
      header: false

    pathIndex = 0

    for f, i in @_config.pathCSVPaths

      load = (file, index) =>
        $.get file, (data) =>

          parse_result = $.parse data, parse_config

          for result, j in parse_result.results
            unless j+1 in @_config.ignoredLines
              console.log @_config.indexMappings[index], index

              startHiventHandle = @_hiventController.getHiventHandleById result[@_config.indexMappings[index]["startHivent"]]
              endHiventHandle = @_hiventController.getHiventHandleById result[@_config.indexMappings[index]["endHivent"]]

              startHivent = startHiventHandle.getHivent()
              endHivent = endHiventHandle.getHivent()

              console.log startHivent, endHivent

              unless startHivent.endDate.getTime() is endHivent.startDate.getTime()

                newPath = null
                if result[@_config.indexMappings[index]["type"]] is "ARC_PATH"
                  newPath = new HG.ArcPath2D startHiventHandle, endHiventHandle, result[@_config.indexMappings[index]["category"]], @_map, COLOR_MAP[result[@_config.indexMappings[index]["category"]]], result[@_config.indexMappings[index]["movingMarker"]], result[@_config.indexMappings[index]["startMarker"]], result[@_config.indexMappings[index]["endMarker"]], 0.2
                else if  result[@_config.indexMappings[index]["type"]] is "linearPath"
                  newPath = new HG.LinearPath2D startHiventHandle, endHiventHandle, result[@_config.indexMappings[index]["category"]], @_map, COLOR_MAP[result[@_config.indexMappings[index]["category"]]]
                else
                  console.error "Undefined path type \"#{result[@_config.indexMappings[index]["type"]]}\"!"

                if newPath?
                  @_paths.push newPath

                  console.log newPath

                  newPath.setDate @_now

            @_filterPaths()

      load f, i

  # ============================================================================
  _filterPaths: ->
    for path in @_paths
      isVisible = true

      if isVisible and @_currentCategoryFilter?
        isVisible = path.category in @_currentCategoryFilter

      if isVisible and @_now?
        isVisible = path._startHiventHandle.getHivent().startDate &lt; @_now

      if isVisible
        path.show(@_now)
      else if path.isVisible()
        path.hide()

  COLOR_MAP =
    "friedrich_naumann" : "#A9A01F"
    "hugo_preuss" : "#eba41d"
    "friedrich_ebert" : "#e72121"
    "maria_juchacz" : "#ca1d74"
    "konstantin_fehrenbach" : "#969696"
    "matthias_erzberger" : "#434343"
