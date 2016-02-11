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

    @_hgInstance.onAllModulesLoaded @, () =>

      @_hiventController = @_hgInstance.hiventController
      @notifyAll "onNowChanged", @_cropDateToMinMax @_nowDate
      @notifyAll "onIntervalChanged", @_getTimeFilter()

      ### LISTENERS ###

      # zoom
      @_hgInstance.buttons.timelineZoomIn.onClick @, () =>
        @_zoom(1)

      @_hgInstance.buttons.timelineZoomOut.onClick @, () =>
        @_zoom(-1)

      # minimize UI
      @_hgInstance.minGUIButton?.onRemoveGUI @, () ->
        @_hideCategories()

      @_hgInstance.minGUIButton?.onOpenGUI @, () ->
        @_showCategories()

      # now marker changing
      @_hgInstance.timeline?.onNowChanged @, (date) =>
        @_nowMarker.upDate date


    ### UI ELEMENTS ###

    # parent, wrapper, slider, date markers
    @_parentDiv = new HG.Div 'timeline-area', ['no-text-select']
    @_hgContainer.appendChild @_parentDiv.dom()

    @_tl = new HG.Div 'tl', ['swiper-container', 'no-text-select']
    @_parentDiv.append @_tl

    @_tlWrapper = new HG.Div 'tl_wrapper', ['swiper-wrapper', 'no-text-select']
    @_tl.append @_tlWrapper

    @_tlSlider = new HG.Div 'tl_slide', ['swiper-slide', 'no-text-select']
    @_tlWrapper.append @_tlSlider

    @_dateMarkers = []

    # now marker
    @_nowDate = @_yearToDate @_config.nowYear
    @_nowMarker = new HG.NowMarker @_parentDiv

    # zoom buttons
    new HG.ZoomButtonsTimeline @_hgInstance if @_config.zoomButtons

    # drag timeline
    # = transition of timeline container with swiper.js
    @_timeline_swiper ?= new Swiper '#tl',
      mode:'horizontal'
      freeMode: true
      momentumRatio: 0.5
      scrollContainer: true

      onTouchStart: =>
        @_dragged = false
        @_moveDelay = 0

      onTouchMove: =>
        @_dragged = true
        @_updateNowDate @_moveDelay++ % 10 == 0
        @_updateDateMarkers()

      onTouchEnd: =>

      onSetWrapperTransition: (s, d) =>
        update_iteration_obj = setInterval =>
          @_updateNowDate true
          @_updateDateMarkers()
        , 50
        setTimeout =>
          clearInterval update_iteration_obj
        , d

    # zoom timeline
    @_tl.dom().addEventListener "mousewheel", (e) =>
      e.preventDefault()
      @_zoom e.wheelDelta, e

    @_tl.dom().addEventListener "DOMMouseScroll", (e) =>
      e.preventDefault()
      @_zoom -e.detail, e

    # resize window
    $(window).resize  =>
      @_updateLayout()
      @_updateDateMarkers()
      @_updateNowDate()

    ### START TIMELINE ###
    @_updateLayout()
    @_updateDateMarkers()
    @_updateNowDate()


  # ============================================================================
  # GETTER

  getNowDate: ->      @_nowDate
  getParentDiv: ->    @_parentDiv
  getSlider: ->       @_tlSlider

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
      @_tlWrapper.dom().style.transition =  delay + "s"
      @_tlWrapper.dom().style.transform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_tlWrapper.dom().style.webkitTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_tlWrapper.dom().style.MozTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_tlWrapper.dom().style.MsTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"
      @_tlWrapper.dom().style.oTransform = "translate3d(" + dateDiff / @_millisPerPixel() + "px ,0px, 0px)"

      @_nowDate = @_cropDateToMinMax date

      @notifyAll "onNowChanged", @_nowDate
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
    timefilter.now = @_nowDate
    timefilter


  # ============================================================================
  _millisPerPixel: ->
    mpp = (@_yearsToMillis(@_config.maxYear - @_config.minYear) / window.innerWidth) / @_config.startZoom

  _minVisibleDate: ->
    d = new Date(@_nowDate.getTime() - (@_millisPerPixel() * window.innerWidth / 2))

  _maxVisibleDate: ->
    d = new Date(@_nowDate.getTime() + (@_millisPerPixel() * window.innerWidth / 2))

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
      @_updateDateMarkers()
      @notifyAll "onZoom"
    zoomed


  # ============================================================================
  # UI
  _updateLayout: ->
    @_tl.dom().style.width = window.innerWidth + "px"
    @_tlSlider.dom().style.width = (@_timelineLength() + window.innerWidth) + "px"
    @_nowMarker.resetPos (window.innerWidth / 2) + "px"
    @_moveToDate @_nowDate, 0
    @_timeline_swiper.reInit()

  _updateNowDate: (fireCallbacks = true) ->
    @_nowDate = @_cropDateToMinMax new Date(@_yearToDate(@_config.minYear).getTime() + (-1) * @_timeline_swiper.getWrapperTranslate("x") * @_millisPerPixel())
    @_nowMarker.upDate @_nowDate
    if fireCallbacks
      @notifyAll "onNowChanged", @_nowDate
      @notifyAll "onIntervalChanged", @_getTimeFilter()

  _updateDateMarkers: ->
    # get interval
    intervalIndex = MIN_INTERVAL_INDEX
    while @_timeInterval(intervalIndex) <= window.innerWidth * @_millisPerPixel() * INTERVAL_SCALE
      intervalIndex++
    interval = @_timeInterval(intervalIndex)

    # scale datemarker
    $(".tl_datemarker").css({"max-width": Math.round(interval / @_millisPerPixel()) + "px"})

    # for every year on timeline check if datemarker is needed
    # or can be removed.
    for i in [0..@_config.maxYear - @_config.minYear]
      year = @_config.minYear + i

      # fits year to interval?
      if year % @_millisToYears(interval) == 0 and
      year >= @_minVisibleDate().getFullYear() and
      year <= @_maxVisibleDate().getFullYear()

        # show datemarker
        if !@_dateMarkers[i]?

          # create new
          @_dateMarkers[i] =
            div: new HG.Div 'tl_year_' + year, 'tl_datemarker'
            year: year
            months: []
          @_dateMarkers[i].div.dom().innerHTML = year + '<div class="tl_months"></div>'
          @_dateMarkers[i].div.dom().style.left = @_dateToPosition(@_yearToDate(year)) + "px"

          @_tlSlider.append @_dateMarkers[i].div

          # show and create months
          if @_millisToYears(interval) == 1
            for month_name, key in MONTH_NAMES
              month =
                div: new HG.Div null, 'tl_month'
                startDate: new Date()
                endDate: new Date()
                name: month_name
              month.startDate.setFullYear(year, key, 1)
              month.endDate.setFullYear(year, key + 1, 0)
              month.div.dom().innerHTML = month.name
              month.div.dom().style.left = ((month.startDate.getTime() - @_yearToDate(year).getTime()) / @_millisPerPixel()) + "px"
              month.div.dom().style.width = (@_dateToPosition(month.endDate) - @_dateToPosition(month.startDate)) + "px"
              $("#tl_year_" + year + " > .tl_months" ).append month.div.dom()
              @_dateMarkers[i].months[key] = month

          # hide and delete months
          else
            for months in @_dateMarkers[i].months
              month.div.j().fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
            @_dateMarkers[i].months.length = 0
          @_dateMarkers[i].div.j().fadeIn FADE_ANIMATION_TIME
        else

          # update existing datemarker and his months
          @_dateMarkers[i].div.dom().style.left = @_dateToPosition(@_yearToDate(year)) + "px"
          if @_millisToYears(interval) == 1

            # show months, create new month divs
            if @_dateMarkers[i].months.length == 0
              for month_name, key in MONTH_NAMES
                month =
                  div: new HG.Div null, 'tl_month'
                  startDate: new Date()
                  endDate: new Date()
                  name: month_name
                month.startDate.setFullYear(year, key, 1)
                month.endDate.setFullYear(year, key + 1, 0)
                month.div.dom().innerHTML = month.name
                month.div.dom().style.left = ((month.startDate.getTime() - @_yearToDate(year).getTime()) / @_millisPerPixel()) + "px"
                month.div.dom().style.width = (@_dateToPosition(month.endDate) - @_dateToPosition(month.startDate)) + "px"
                $("#tl_year_" + year + " > .tl_months" ).append month.div.dom()
                @_dateMarkers[i].months[key] = month

            # update existing month divs
            else
              for month in @_dateMarkers[i].months
                month.div.dom().style.left = ((month.startDate.getTime() - @_yearToDate(year).getTime()) / @_millisPerPixel()) + "px"
                month.div.dom().style.width = (@_dateToPosition(month.endDate) - @_dateToPosition(month.startDate)) + "px"

          # hide and delete months
          else
            for month in @_dateMarkers[i].months
              month.div.j().fadeOut(FADE_ANIMATION_TIME, `function() { $(this).remove(); }`)
            @_dateMarkers[i].months.length = 0

      # hide and delete datemarker and their months
      else
        if @_dateMarkers[i]?
          @_dateMarkers[i].div.dom().style.left = @_dateToPosition(@_yearToDate(year)) + "px"
          @_dateMarkers[i].div.j().remove()
          @_dateMarkers[i] = null


  ##############################################################################
  #                            STATIC CONSTANTS                                #
  ##############################################################################

  MIN_INTERVAL_INDEX = 0      # 0 = 1 Year | 1 = 2 Year | 2 = 5 Years | 3 = 10 Years | ...
  INTERVAL_SCALE = 0.05       # higher value makes greater intervals between datemarkers
  FADE_ANIMATION_TIME = 200   # fade in time for datemarkers and so

  MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]