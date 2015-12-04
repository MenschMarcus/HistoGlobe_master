window.HG ?= {}

class HG.HiventStory

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      hivents: []
      hiventPrefixes: undefined
      transitionTime: 0

    @_config = $.extend {}, defaultConfig, config

    @_timeline = null
    @_nowMarker = null
    @_hiventController = null
    @_categoryFilter = null
    @_hiventNames = @_config.hivents
    @_ignoredNames = []
    @_currentDate = null
    @_currentHivent = null
    @_needsSorting = true

  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.onAllModulesLoaded @, () =>

      @_timeline = hgInstance.timeline
      @_nowMarker = hgInstance.timeline.getNowMarker()
      @_hiventController = hgInstance.hiventController
      @_categoryFilter = hgInstance.categoryFilter
      @_hashSetter = hgInstance.hiventInfoAtTag

      @_currentDate = @_timeline.getNowDate()
      @_timeline.onNowChanged @, (date) =>
        @_currentDate = date
      # @_timeline.onIntervalChanged @, () =>
      #   @_ignoredNames = []

      if @_hiventNames.length is 0
        @_hiventController.getHivents @, (handle) =>
          id = handle.getHivent().id
          unless id in @_hiventNames
            push = false
            if @_config.hiventPrefixes?
              for prefix in @_config.hiventPrefixes
                if id.indexOf(prefix) is 0
                  push = true
                  break
            else push = true

            if push
              @_hiventNames.push id
              @_needsSorting = true

      @_nowMarker.clearButtons()

      @_backwardButton    = document.createElement "span"
      @_backwardButton.id = "hivent_story_backward_button"
      @_backwardButton.className = "fa fa-step-backward"
      @_nowMarker.addButton @_backwardButton, (e) =>
        @_jumpToNextHivent false

      @_forwardButton    = document.createElement "span"
      @_forwardButton.id = "hivent_story_forward_button"
      @_forwardButton.className = "fa fa-step-forward"
      @_nowMarker.addButton @_forwardButton, (e) =>
        @_jumpToNextHivent true

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _jumpToNextHivent: (forward=true)=>
    @_currentHivent?.unLinkAll()

    if @_needsSorting
      @_needsSorting = false
      @_hiventNames.sort (a, b) =>
        hiventA = @_hiventController.getHiventHandleById a
        hiventB = @_hiventController.getHiventHandleById b
        if hiventA? and hiventB?
          return hiventA.getHivent().startDate.getTime() - hiventB.getHivent().startDate.getTime()
        return 0

    hiventGetter = if forward then 'getNextHiventHandle' else 'getPreviousHiventHandle'

    nextHivent = @_hiventController[hiventGetter] @_currentDate, @_ignoredNames
    nextFound = false

    while not nextFound and nextHivent?
      @_currentHivent = nextHivent unless @_currentHivent?

      hivent = nextHivent.getHivent()
      unless hivent.id in @_hiventNames and (@_categoryFilter.getCurrentFilter().length is 0 or hivent.category in @_categoryFilter.getCurrentFilter())
        nextHivent = @_hiventController[hiventGetter] hivent.startDate, @_ignoredNames

      else
        nextFound = true
        if hivent.startDate.getTime() is @_currentHivent.getHivent().startDate.getTime()
          @_ignoredNames.push hivent.id
        else
          @_ignoredNames = []

    unless nextFound
      indices = if forward then [0...@_hiventNames.length] else [@_hiventNames.length-1..0]
      for i in indices
        check = @_hiventController.getHiventHandleById @_hiventNames[i]
        if check.getHivent().category in @_categoryFilter.getCurrentFilter()
          nextHivent = check
          nextFound = true
          @_ignoredNames = []
          break

    if nextFound
      @_currentDate = nextHivent.getHivent().startDate
      @_currentHivent = nextHivent
      @_ignoredNames.push @_currentHivent.getHivent().id
      @_hashSetter.setOption "event", "#{@_currentHivent.getHivent().id}"
      @_currentHivent.linkAll()


  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

