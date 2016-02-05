window.HG ?= {}

class HG.Timeline

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onNowChanged"
    @addCallback "onIntervalChanged"
    @addCallback "onZoom"
    @addCallback "OnTopicsLoaded"

    # handle config
    defaultConfig =
      zoomButtons: true
      minZoom: 1
      maxZoom: 7
      startZoom: 2

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add timeline to HG instance
    @_hgInstance.timeline = @

    # get dimensions of timeline
    @_config.minYear = @_hgInstance.getMinMaxYear()[0]
    @_config.maxYear = @_hgInstance.getMinMaxYear()[1]
    @_config.nowYear = @_hgInstance.getStartYear()

    @_hgContainer = @_hgInstance.getContainer()

    # init members
    @_activeTopic     = null
    @_dragged         = false
    @_topicsLoaded    = false
    @_timelineClicked = false

    @_hgInstance.onAllModulesLoaded @, () =>

      @_hiventController = @_hgInstance.hiventController
      @notifyAll "onNowChanged", @_cropDateToMinMax @_now.date
      @notifyAll "onIntervalChanged", @_getTimeFilter()

      ### LISTENERS ###

      # zoom
      @_hgInstance.zoomButtonsTimeline?.onZoomIn @, () =>
        @_zoom(1)

      @_hgInstance.zoomButtonsTimeline?.onZoomOut @, () =>
        @_zoom(-1)

      # minimize UI
      @_hgInstance.minGUIButton?.onRemoveGUI @, () ->
        @_hideCategories()

      @_hgInstance.minGUIButton?.onOpenGUI @, () ->
        @_showCategories()

      # now marker changing
      @_hgInstance.timeline?.onNowChanged @, (date) =>
        @_now.dateField.innerHTML = date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS

      # show or hide topic
      # @_hgInstance.categoryFilter?.onFilterChanged @, (categoryFilter) =>
      #   @_unhighlightTopics()
      #   for topic in @_config.topics
      #     if categoryFilter[0] is topic.id
      #       @_switchTopic(topic)
      #       break


    ### UI ELEMENTS ###
    @_parentDiv = @_addUiElement "timeline-area", "timeline-area", @_hgContainer

    @_uiElements =
      tl:           @_addUiElement "tl", "swiper-container", @_parentDiv
      tl_wrapper:   @_addUiElement "tl_wrapper", "swiper-wrapper", tl
      tl_slide:     @_addUiElement "tl_slide", "swiper-slide", tl_wrapper
      dateMarkers:  []

    # now marker
    # TODO: use real HG.NowMarker
    @_now =
      date: @_yearToDate(@_config.nowYear)
      marker: @_addUiElement "now_marker_arrow_bottom", null, @_hgContainer
      dateField: @_addUiElement "now_date_field", null, @_hgContainer

    # drag timeline
    # = transition of timeline container with swiper.js
    @_timeline_swiper ?= new Swiper '#tl',
      mode:'horizontal'
      freeMode: true
      momentumRatio: 0.5
      scrollContainer: true

      onTouchStart: =>
        @_dragged = false
        @_timelineClicked = true
        @_moveDelay = 0

      onTouchMove: =>
        @_dragged = true
        @_updateNowDate @_moveDelay++ % 10 == 0
        @_updateDateMarkers()

      onTouchEnd: =>
        @_timelineClicked = false

      onSetWrapperTransition: (s, d) =>
        update_iteration_obj = setInterval =>
          @_updateNowDate true
          @_updateDateMarkers()
        , 50
        setTimeout =>
          clearInterval update_iteration_obj
        , d

    # zoom timeline
    @_uiElements.tl.addEventListener "mousewheel", (e) =>
      e.preventDefault()
      @_zoom e.wheelDelta, e

    @_uiElements.tl.addEventListener "DOMMouseScroll", (e) =>
      e.preventDefault()
      @_zoom -e.detail, e

    # resize window
    $(window).resize  =>
      @_updateLayout()
      @_updateDateMarkers()
      # @_updateTopics()
      @_updateNowDate()

    ### START TIMELINE ###
    @_updateLayout()
    @_updateDateMarkers()
    @_updateNowDate()


  # ============================================================================
  # GETTER

  getNowDate: ->      @_now.date
  getParentDiv: ->    @_parentDiv
  getSlider: ->       @_uiElements.tl_slide

  # TODO: sort out
  getNowMarker: ->    @_now.marker




  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _moveToDate: (date, delay=0, successCallback=undefined) ->
    if @_yearToDate(@_config.minYear).getTime() > date.getTime()
      @_moveToDate @_yearToDate(@_config.minYear), delay, successCallback
    else if @_yearToDate(@_config.maxYear).getTime() < date.getTime()
      @_moveToDate @_yearToDate(@_config.maxYear), delay, successCallback
    else
      dateDiff = @_yearToDate(@_config.minYear).getTime() - date.getTime()
      @_uiElements.tl_wrapper.style.transition =  delay + "s"
      @_uiElements.tl_wrapper.style.transform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.webkitTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.MozTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.MsTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_uiElements.tl_wrapper.style.oTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"

      @_now.date = @_cropDateToMinMax date

      @notifyAll "onNowChanged", @_now.date
      @notifyAll "onIntervalChanged", @_getTimeFilter()

      setTimeout(successCallback, delay * 1000) if successCallback?


  # ============================================================================
  _getTimeFilter: ->
    timefilter = []
    if @_activeTopic?
      timefilter.end = @_activeTopic.endDate
      timefilter.start = @_activeTopic.startDate
    else
      timefilter.end = @_maxVisibleDate()
      timefilter.start = @_minVisibleDate()
    timefilter.now = @_now.date
    timefilter


  # ============================================================================
  _millisPerPixel: ->
    mpp = (@_yearsToMillis(@_config.maxYear - @_config.minYear) / window.innerWidth) / @_config.startZoom

  _minVisibleDate: ->
    d = new Date(@_now.date.getTime() - (@_millisPerPixel() * window.innerWidth / 2))

  _maxVisibleDate: ->
    d = new Date(@_now.date.getTime() + (@_millisPerPixel() * window.innerWidth / 2))

  _timelineLength: ->
    @_yearsToMillis(@_config.maxYear - @_config.minYear) / @_millisPerPixel()

  _timeInterval: (i) ->
    x = Math.floor(i/3)
    if i % 3 == 0
      return @_yearsToMillis(Math.pow(10, x))
    if i % 3 == 1
      return @_yearsToMillis(2 * Math.pow(10, x))
    if i % 3 == 2
      return @_yearsToMillis(5 * Math.pow(10, x))


  # ============================================================================
  # helper functions: calculations date and position
  _dateToPosition: (date) ->
    dateDiff = date.getTime() - @_yearToDate(@_config.minYear).getTime()
    pos = (dateDiff / @_millisPerPixel()) + window.innerWidth/2

  _yearToDate: (year) ->
    date = new Date(0)
    date.setFullYear year
    date.setMonth 0
    date.setDate 1
    date.setHours 0
    date.setMinutes 0
    date.setSeconds 0
    date

  _yearsToMillis: (year) ->
    millis = year * 365.25 * 24 * 60 * 60 * 1000

  _monthsToMillis: (months) ->
    millis = months * 30 * 24 * 60 * 60 * 1000

  _yearsToMonths: (years) ->
    months = Math.round(years * 12)

  _millisToYears: (millis) ->
    year = millis / 1000 / 60 / 60 / 24 / 365.25

  _millisToMonths: (millis) ->
    months = Math.round(millis / 1000 / 60 / 60 / 24 / 365.25 / 12)

  _daysToMillis: (days) ->
    millis = days * 24 * 60 * 60 * 1000

  _millisToDays: (millis) ->
    days = millis / 1000 / 60 / 60 / 24

  _stringToDate: (string) ->
    res = (string + "").split(".")
    i = res.length
    d = new Date(1900, 0, 1)
    if i > 0
        d.setFullYear(res[i - 1])
    else
        alert "Error: were not able to convert string to date."
    if i > 1
        d.setMonth(res[i - 2] - 1)
    if i > 2
        d.setDate(res[i - 3])
    d


  _cropDateToMinMax: (date) ->
    if date.getFullYear() <= @_config.minYear
      date = @_yearToDate @_config.minYear+1
    if date.getFullYear() > @_config.maxYear
      date = @_yearToDate @_config.maxYear
    date

  # ============================================================================
  # move and zoom
  _zoom: (delta, e=null, layout=true) =>
    zoomed = false
    if delta > 0
      if @_millisToDays(@_maxVisibleDate().getTime()) - @_millisToDays(@_minVisibleDate().getTime()) > @_config.maxZoom
        @_config.startZoom *= 1.1
        zoomed = true
    else
      if @_config.startZoom > @_config.minZoom
        @_config.startZoom /= 1.1
        zoomed = true

    if zoomed
      if layout
        @_updateLayout()
      @_updateTopics()
      @_updateDateMarkers()
      @_updateTextInTopics()
      @notifyAll "onZoom"
    zoomed


  # ============================================================================
  # UI
  _addUiElement: (id, className, parentDiv, type="div") ->
    container = document.createElement(type)
    container.id = id
    container.className = className if className?

    # hack to disable text select on timeline
    container.classList.add "no-text-select"

    parentDiv.appendChild container if parentDiv?
    container

  #update
  _updateLayout: ->
    @_uiElements.tl.style.width       = window.innerWidth + "px"
    @_uiElements.tl_slide.style.width = (@_timelineLength() + window.innerWidth) + "px"
    @_now.marker.style.left           = (window.innerWidth / 2) + "px"
    @_now.dateField.style.left        = (window.innerWidth / 2) + "px"
    @_moveToDate(@_now.date, 0)
    @_timeline_swiper.reInit()

  _updateNowDate: (fireCallbacks = true) ->
    @_now.date = @_cropDateToMinMax new Date(@_yearToDate(@_config.minYear).getTime() + (-1) * @_timeline_swiper.getWrapperTranslate("x") * @_millisPerPixel())
    @_now.dateField.innerHTML = @_now.date.toLocaleDateString DATE_LOCALE, DATE_OPTIONS
    if fireCallbacks
      @notifyAll "onNowChanged", @_now.date
      @notifyAll "onIntervalChanged", @_getTimeFilter()

  _updateDateMarkers: ->
    # get interval
    intervalIndex = MIN_INTERVAL_INDEX
    while @_timeInterval(intervalIndex) <= window.innerWidth * @_millisPerPixel() * INTERVAL_SCALE
      intervalIndex++
    interval = @_timeInterval(intervalIndex)

    # scale datemarker
    $(".tl_datemarker").css({"max-width": Math.round(interval / @_millisPerPixel()) + "px"})

    max_year = @_maxVisibleDate().getFullYear()
    min_year = @_minVisibleDate().getFullYear()

    # for every year on timeline check if datemarker is needed
    # or can be removed.
    for i in [0..@_config.maxYear - @_config.minYear]
      year = @_config.minYear + i

      # fits year to interval?
      if year % @_millisToYears(interval) == 0 and
      year >= min_year and
      year <= max_year

        # show datemarker
        if !@_uiElements.dateMarkers[i]?

          # create new
          @_uiElements.dateMarkers[i] =
            div: document.createElement("div")
            year: year
            months: []
          @_uiElements.dateMarkers[i].div.id = "tl_year_" + year
          @_uiElements.dateMarkers[i].div.className = "tl_datemarker"
          @_uiElements.dateMarkers[i].div.innerHTML = year + '<div class="tl_months"></div>'
          @_uiElements.dateMarkers[i].div.style.left = @_dateToPosition(@_yearToDate(year)) + "px"
          #@_uiElements.dateMarkers[i].div.style.display = "none"
          @getSlider().appendChild @_uiElements.dateMarkers[i].div

          # show and create months
          if @_millisToYears(interval) == 1
            for month_name, key in MONTH_NAMES
              month =
                div: document.createElement("div")
                startDate: new Date()
                endDate: new Date()
                name: month_name
              month.startDate.setFullYear(year, key, 1)
              month.endDate.setFullYear(year, key + 1, 0)
              month.div.className = "tl_month"
              month.div.innerHTML = month.name
              month.div.style.left = ((month.startDate.getTime() - @_yearToDate(year).getTime()) / @_millisPerPixel()) + "px"
              month.div.style.width = (@_dateToPosition(month.endDate) - @_dateToPosition(month.startDate)) + "px"
              $("#tl_year_" + year + " > .tl_months" ).append month.div
              @_uiElements.dateMarkers[i].months[key] = month

          # hide and delete months
          else
            for months in @_uiElements.dateMarkers[i].months
              $(month.div).fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
            @_uiElements.dateMarkers[i].months.length = 0
          $(@_uiElements.dateMarkers[i].div).fadeIn(FADE_ANIMATION_TIME)
        else

          # update existing datemarker and his months
          @_uiElements.dateMarkers[i].div.style.left = @_dateToPosition(@_yearToDate(year)) + "px"
          if @_millisToYears(interval) == 1

            # show months, create new month divs
            if @_uiElements.dateMarkers[i].months.length == 0
              for month_name, key in MONTH_NAMES
                month =
                  div: document.createElement("div")
                  startDate: new Date()
                  endDate: new Date()
                  name: month_name
                month.startDate.setFullYear(year, key, 1)
                month.endDate.setFullYear(year, key + 1, 0)
                month.div.className = "tl_month"
                month.div.innerHTML = month.name
                month.div.style.left = ((month.startDate.getTime() - @_yearToDate(year).getTime()) / @_millisPerPixel()) + "px"
                month.div.style.width = (@_dateToPosition(month.endDate) - @_dateToPosition(month.startDate)) + "px"
                $("#tl_year_" + year + " > .tl_months" ).append month.div
                @_uiElements.dateMarkers[i].months[key] = month

            # update existing month divs
            else
              for month in @_uiElements.dateMarkers[i].months
                month.div.style.left = ((month.startDate.getTime() - @_yearToDate(year).getTime()) / @_millisPerPixel()) + "px"
                month.div.style.width = (@_dateToPosition(month.endDate) - @_dateToPosition(month.startDate)) + "px"

          # hide and delete months
          else
            for month in @_uiElements.dateMarkers[i].months
              $(month.div).fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
            @_uiElements.dateMarkers[i].months.length = 0

      # hide and delete datemarker and their months
      else
        if @_uiElements.dateMarkers[i]?
          @_uiElements.dateMarkers[i].div.style.left = @_dateToPosition(@_yearToDate(year)) + "px"
          #$(@_uiElements.dateMarkers[i].div).fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
          $(@_uiElements.dateMarkers[i].div).remove()
          @_uiElements.dateMarkers[i] = null


  ##############################################################################
  #                            STATIC CONSTANTS                                #
  ##############################################################################

  MIN_INTERVAL_INDEX = 0      # 0 = 1 Year | 1 = 2 Year | 2 = 5 Years | 3 = 10 Years | ...
  INTERVAL_SCALE = 0.05       # higher value makes greater intervals between datemarkers
  FADE_ANIMATION_TIME = 200   # fade in time for datemarkers and so

  MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]

  DATE_LOCALE = 'de-DE'
  DATE_OPTIONS = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }

