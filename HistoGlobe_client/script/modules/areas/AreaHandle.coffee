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
  # Returns the assigned Area.
  # ============================================================================
  getArea: -> @_area



  # ============================================================================
  # Notifies listeners that the HiventHandle is now active. Usually, this is
  # triggered when a map or timeline icon belonging to a Hivent is being
  # clicked. "mousePixelPosition" may be passed and should be the click's
  # location in device coordinates.
  # ============================================================================
  activeAll: (mousePixelPosition) ->
    @_activated = true
    ACTIVE_HIVENTS.push @
    @notifyAll "onActive", mousePixelPosition, @

  # ============================================================================
  # Notifies a specific listener (obj) that the HiventHandle is now active.
  # Usually, this is triggered when a map or timeline icon belonging to a Hivent
  # is being clicked. "mousePixelPosition" may be passed and should be the
  # click's location in device coordinates.
  # ============================================================================
  active: (obj, mousePixelPosition) ->
    @_activated = true
    ACTIVE_HIVENTS.push @
    @notify "onActive", obj, mousePixelPosition, @

  # ============================================================================
  # Returns whether or not the HiventHandle is active.
  # ============================================================================
  isActive: () ->
    @_activated

  # ============================================================================
  # Notifies all listeners that the HiventHandle is now inactive. Usually, this
  # is triggered when a map or timeline icon belonging to a Hivent is being
  # clicked. "mousePixelPosition" may be passed and should be the click's
  # location in device coordinates.
  # ============================================================================
  inActiveAll: (mousePixelPosition) ->
    @_activated = false
    index = $.inArray(@, ACTIVE_HIVENTS)
    if index >= 0 then delete ACTIVE_HIVENTS[index]
    @notifyAll "onInActive", mousePixelPosition, @

  # ============================================================================
  # Notifies a specific listener (obj) that the HiventHandle is now inactive.
  # Usually, this is triggered when a map or timeline icon belonging to a Hivent
  # is being clicked. "mousePixelPosition" may be passed and should be the
  # click's location in device coordinates.
  # ============================================================================
  inActive: (obj, mousePixelPosition) ->
    @_activated = false
    index = $.inArray(@, ACTIVE_HIVENTS)
    if index >= 0 then delete ACTIVE_HIVENTS[index]
    @notify "onInActive", obj, mousePixelPosition, @

  # ============================================================================
  # Toggles the HiventHandle's active state and notifies all listeners according
  # to the new value of "@_activated".
  # ============================================================================
  toggleActiveAll: (mousePixelPosition) ->
    @_activated = not @_activated
    if @_activated
      @activeAll mousePixelPosition
    else
      @inActiveAll mousePixelPosition

  # ============================================================================
  # Toggles the HiventHandle's active state and notifies a specific listener
  # (obj) according to the new value of "@_activated".
  # ============================================================================
  toggleActive: (obj, mousePixelPosition) ->
    @_activated = not @_activated
    if @_activated
      @active obj, mousePixelPosition
    else
      @inActive obj, mousePixelPosition



  # ============================================================================
  # Notifies all listeners that the HiventHandle is now marked. Usually, this is
  # triggered when a map or timeline icon belonging to a Hivent is being
  # hovered. "mousePixelPosition" may be passed and should be the mouse's
  # location in device coordinates.
  # ============================================================================
  markAll: (mousePixelPosition) ->
    unless @_marked
      @_marked = true
      @notifyAll "onMark", mousePixelPosition

  # ============================================================================
  # Notifies a specific listener (obj) that the HiventHandle is now marked.
  # Usually, this is triggered when a map or timeline icon belonging to a Hivent
  # is being hovered. "mousePixelPosition" may be passed and should be the
  # mouse's location in device coordinates.
  # ============================================================================
  mark: (obj, mousePixelPosition) ->
    unless @_marked
      @_marked = true
      @notify "onMark", obj, mousePixelPosition

  # ============================================================================
  # Notifies all listeners that the HiventHandle is no longer marked. Usually,
  # this is triggered when a map or timeline icon belonging to a Hivent is being
  # hovered. "mousePixelPosition" may be passed and should be the mouse's
  # location in device coordinates.
  # ============================================================================
  unMarkAll: (mousePixelPosition) ->
    if @_marked
      @_marked = false
      @notifyAll "onUnMark", mousePixelPosition

  # ============================================================================
  # Notifies a specific listener (obj) that the HiventHandle no longer marked.
  # Usually, this is triggered when a map or timeline icon belonging to a Hivent
  # is being hovered. "mousePixelPosition" may be passed and should be the
  # mouse's location in device coordinates.
  # ============================================================================
  unMark: (obj, mousePixelPosition) ->
    if @_marked
      @_marked = false
      @notify "onUnMark", obj, mousePixelPosition



  # ============================================================================
  # Notifies all listeners to focus on the Hivent associated with the
  # HiventHandle.
  # ============================================================================
  focusAll: () ->
    @_focused = true
    @notifyAll "onFocus"

  # ============================================================================
  # Notifies a specific listener (obj) to focus on the Hivent associated with
  # the HiventHandle.
  # ============================================================================
  focus: (obj) ->
    @_focused = true
    @notify "onFocus", obj

  # ============================================================================
  # Notifies all listeners that the Hivent associated with the HiventHandle
  # shall no longer be focussed.
  # ============================================================================
  unFocusAll: () ->
    @_focused = false
    @notifyAll "onUnFocus"

  # ============================================================================
  # Notifies a specific listener (obj) that the Hivent associated with the
  # HiventHandle shall no longer be focussed.
  # ============================================================================
  unFocus: (obj) ->
    @_focused = false
    @notify "onUnFocus", obj



  # ============================================================================
  # Notifies all listeners that the Hivent the HiventHandle is destroyed. This
  # is used to allow for proper clean up.
  # ============================================================================
  destroyAll: ->
    @notifyAll "onDestruction"
    @_destroy()

  # ============================================================================
  # Notifies a specific listener (obj) that the Hivent the HiventHandle is
  # destroyed. This is used to allow for proper clean up.
  # ============================================================================
  destroy: (obj) ->
    @notify "onDestruction", obj
    @_destroy()


  # ============================================================================
  # Sets the HiventHandle's visibility state.
  # ============================================================================
  setState: (state) ->
    if @_state isnt state

      if state is 0
        @notifyAll "onInvisible", @, @_state
      else if state is 1
        @notifyAll "onVisiblePast", @, @_state
      else if state is 2
        @notifyAll "onVisibleFuture", @, @_state
      else
        console.warn "Failed to set HiventHandle state: invalid state #{state}!"

      @_state = state


  # ============================================================================
  # Sets the HiventHandle's age.
  # what is the age?
  # ============================================================================
  setAge: (age) ->
    if @_age isnt age
      @_age = age
      @notifyAll "onAgeChanged", age, @


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
