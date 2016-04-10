window.HG ?= {}

# ==============================================================================
# AreaHandle encapsulates states that are necessary for and triggered by the
# interaction with Areas through Map, HistoGraph and so on. Other
# objects may register listeners for changes and/or trigger state changes.
# Every AreaHandle is responsible for exactly one Area.
# ==============================================================================
class HG.AreaHandle

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # Constructor
  # Initializes member data and stores a reference to the passed Hivent object.
  # ============================================================================
  constructor: (@_area) ->

    # Internal states
    @_visible = no    # is area currently on the map?
    @_active = no     # is area currently active/selected?
    @_focused = no    # is area currently in focus (hovered)?
    @_inEdit = no     # is area in edit mode?

    @sortingIndex = -1

    # Add callback functionality
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # Add callbacks for all states. These are triggered by the corresponding
    # function specified below.


  # ============================================================================
  # Get the Area
  # ============================================================================
  getArea: ->       @_area


  # ============================================================================
  # Get start / end of the Area
  # ============================================================================
  getStartDate: () -> @startHivent.getHivent().effectDate # startHivent must be given
  getEndDate: () ->   if @endHivent then @endHivent.getHivent().effectDate else moment()

  # ============================================================================
  # Get the state of the Area
  # ============================================================================
  isVisble: () ->   @_visible
  isActive: () ->   @_active
  isFocused: () ->  @_focused
  isInEdit: () ->   @_inEdit


  # ============================================================================
  # Notifies listeners that the AreaHandle is now active. Usually, this is
  # triggered when a map or timeline icon belonging to a Hivent is being
  # clicked. "mousePixelPosition" may be passed and should be the click's
  # location in device coordinates.
  # ============================================================================
  activeAll: (mousePixelPosition) ->
    @_active = true
    ACTIVE_HIVENTS.push @
    @notifyAll "onActive", mousePixelPosition, @

  # ----------------------------------------------------------------------------
  active: (obj, mousePixelPosition) ->
    @_active = true
    ACTIVE_HIVENTS.push @
    @notify "onActive", obj, mousePixelPosition, @


  # ============================================================================
  # Notifies all listeners that the AreaHandle is now inactive. Usually, this
  # is triggered when a map or timeline icon belonging to a Hivent is being
  # clicked. "mousePixelPosition" may be passed and should be the click's
  # location in device coordinates.
  # ============================================================================
  inActiveAll: (mousePixelPosition) ->
    @_active = false
    index = $.inArray(@, ACTIVE_HIVENTS)
    if index >= 0 then delete ACTIVE_HIVENTS[index]
    @notifyAll "onInActive", mousePixelPosition, @

  # ----------------------------------------------------------------------------
  inActive: (obj, mousePixelPosition) ->
    @_active = false
    index = $.inArray(@, ACTIVE_HIVENTS)
    if index >= 0 then delete ACTIVE_HIVENTS[index]
    @notify "onInActive", obj, mousePixelPosition, @


  # ============================================================================
  # Toggles the AreaHandle's active state and notifies all listeners according
  # to the new value of "@_active".
  # ============================================================================
  toggleActiveAll: (mousePixelPosition) ->
    @_active = not @_active
    if @_active
      @activeAll mousePixelPosition
    else
      @inActiveAll mousePixelPosition

  # ----------------------------------------------------------------------------
  toggleActive: (obj, mousePixelPosition) ->
    @_active = not @_active
    if @_active
      @active obj, mousePixelPosition
    else
      @inActive obj, mousePixelPosition


  # ============================================================================
  # Notifies all listeners that the AreaHandle is now marked. Usually, this is
  # triggered when a map or timeline icon belonging to a Hivent is being
  # hovered. "mousePixelPosition" may be passed and should be the mouse's
  # location in device coordinates.
  # ============================================================================
  markAll: (mousePixelPosition) ->
    unless @_marked
      @_marked = true
      @notifyAll "onMark", mousePixelPosition

  # ----------------------------------------------------------------------------
  mark: (obj, mousePixelPosition) ->
    unless @_marked
      @_marked = true
      @notify "onMark", obj, mousePixelPosition


  # ============================================================================
  # Notifies all listeners that the AreaHandle is no longer marked. Usually,
  # this is triggered when a map or timeline icon belonging to a Hivent is being
  # hovered. "mousePixelPosition" may be passed and should be the mouse's
  # location in device coordinates.
  # ============================================================================
  unMarkAll: (mousePixelPosition) ->
    if @_marked
      @_marked = false
      @notifyAll "onUnMark", mousePixelPosition

  # ----------------------------------------------------------------------------
  unMark: (obj, mousePixelPosition) ->
    if @_marked
      @_marked = false
      @notify "onUnMark", obj, mousePixelPosition


  # ============================================================================
  # Notifies all listeners to focus on the Hivent associated with the
  # AreaHandle.
  # ============================================================================
  focusAll: () ->
    @_focused = true
    @notifyAll "onFocus"

  # ----------------------------------------------------------------------------
  focus: (obj) ->
    @_focused = true
    @notify "onFocus", obj


  # ============================================================================
  # Notifies all listeners that the Hivent associated with the AreaHandle
  # shall no longer be focussed.
  # ============================================================================
  unFocusAll: () ->
    @_focused = false
    @notifyAll "onUnFocus"

  # ----------------------------------------------------------------------------
  unFocus: (obj) ->
    @_focused = false
    @notify "onUnFocus", obj


  # ============================================================================
  # Notifies listeners that the Hivent the AreaHandle is destroyed. This
  # is used to allow for proper clean up.
  # ============================================================================
  destroyAll: ->
    @notifyAll "onDestruction"
    @_destroy()

  # ----------------------------------------------------------------------------
  destroy: (obj) ->
    @notify "onDestruction", obj
    @_destroy()


  # ============================================================================
  # Return the current style of the area based on its status
  # this one function that does all the coloring was SO hard to come up with.
  # Please no major changes, it will be a f***ing p*in *n the a**
  # ============================================================================

  getStyle: () ->

    # --------------------------------------------------------------------------
    #   different vocabulary for leaflet layers and svg paths (animated by d3)
    #   property          leaflet       svg (d3)
    #   ------------------------------------------------
    #   areaColor         fillColor     fill
    #   areaOpacity       fillOpacity   fill-opacity
    #   borderColor       color         stroke
    #   borderOpacity     opacity       stroke-opacity
    #   bordeWidth        weight        stroke-width
    # --------------------------------------------------------------------------

    ## initial style configuration

    style = {
      'areaColor' :      HGConfig.color_white.val
      'areaOpacity' :    HGConfig.area_full_opacity.val
      'borderColor' :    HGConfig.color_bg_dark.val
      'borderOpacity' :  HGConfig.border_opacity.val
      'borderWidth' :    HGConfig.border_width.val
    }


    ## change certain style properties based on the area status

    # --------------------------------------------------------------------------
    # decision tree:        _________ inEdit? _________
    #                     1/                           \0
    #                 selected?                      selected?
    #             1/           \0                1/            \0
    #             |         focused?         focused?        focused?
    #             |       1/      \0       1/      \0      1/      \0
    #             x       x       x        x       x       x       x
    #           (ES)    (EF)     (E)     (NSF)   (NS)    (NF)     (N)
    # --------------------------------------------------------------------------

    if @_inEdit

      if @_selected
        # (ES)  in edit mode + selected + can not be focused => full active
        style.areaColor = HGConfig.color_active.val

      else # not selected

        if @_focused
          # (EF)  in edit mode + unselected + focused => full highlight
          style.areaColor = HGConfig.color_highlight.val

        else # not focused
          # (E)  in edit mode + unselected + not focused => half active
          style.areaColor = HGConfig.color_active.val
          style.areaOpacity = HGConfig.area_half_opacity.val

    else # not in edit

      if @_selected

        if @_focused
          # (NSF) normal area + selected + focused => full highlight
          style.areaColor = HGConfig.color_highlight.val

        else # not focused
          # (NS) normal area + selected + not focused => half active
          style.areaColor = HGConfig.color_active.val
          style.areaOpacity = HGConfig.area_half_opacity.val

      else # not selected

        if @_focused
          # (NF) normal area + unselected + focused => half highlight
          style.areaColor = HGConfig.color_highlight.val
          style.areaOpacity = HGConfig.area_half_opacity.val

        # else not focused
          # (N) normal area + unselected + not focused => initial configuration
          # => no change

    return style

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _destroy: ->
    @_onActiveCallbacks = []
    @_onInActiveCallbacks = []
    @_onMarkCallbacks = []
    @_onUnMarkCallbacks = []
    @_onLinkCallbacks = []
    @_onUnLinkCallbacks = []
    @_onUnFocusCallbacks = []
    @_onFocusCallbacks = []
    @_onUnFocusCallbacks = []

    @_onDestructionCallbacks = []

    delete @
    return


  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  VISIBLE_AREAS = []    # areas currently visible in the view
  ACTIVE_AREAS = []     # areas currently active / selected in the view
