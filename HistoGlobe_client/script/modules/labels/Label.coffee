window.HG ?= {}

class HG.Label

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (json) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onShow"
    @addCallback "onHide"

    @_initMembers(json)

  # ============================================================================
  getName: ->
    "<p style='#{@_getStyle()}'>" + @_name + "</p>"

  # ============================================================================
  getLatLng: ->
    @_latLng

  # ============================================================================
  setDate: (newDate) ->

    oldDate = @_now
    @_now = newDate

    oldActive = @_active
    @_active = @_isActive()

    if @_active and not oldActive
      @notifyAll "onShow", @

    if not @_active and oldActive
      @notifyAll "onHide", @


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initMembers: (json) ->
    @_now       = new Date(2000, 1, 1)
    @_active    = false

    @_name      = json.label
    @_size      = json.size

    @_latLng = [json.lat, json.long]

    @_style =
      color:        "#666"
      weight:       1
      opacity:      1

    @_start_date = new Date(json.startYear, json.startMonth, json.startDay)
    @_end_date = new Date(json.endYear, json.endMonth, json.endDay)


  # ============================================================================
  _getStyle: () =>
    "font-size:#{@_size}em;" +
    "font-weight:normal;"

  # ============================================================================
  _isActive: () =>
    @_start_date < @_now and @_now < @_end_date

