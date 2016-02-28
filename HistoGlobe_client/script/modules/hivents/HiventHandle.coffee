window.HG ?= {}

# ==============================================================================
# HiventHandle encapsulates states that are necessary for and triggered by the
# interaction with Hivents through map, timeline, sidebar and so on. Other
# objects may register listeners for changes and/or trigger state changes.
# Every HiventHandle is responsible for exactly one Hivent.
# ==============================================================================
class HG.HiventHandle

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # Constructor
  # Initializes member data and stores a reference to the passed Hivent object.
  # ============================================================================
  constructor: (hivent) ->

    @_hivent = hivent

    # Internal states
    @_activated = false
    @_marked = false
    @_linked = false
    @_focussed = false
    @_age = 0.0

    @_state = 0
    # 0 --> invisible
    # 1 --> visiblePast
    # 2 --> visibleFuture

    @sortingIndex = -1

    # Add callbac functionality
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # Add callbacks for all states. These are triggered by the corresponding
    # function specified below.
    @addCallback "onActive"
    @addCallback "onInActive"
    @addCallback "onMark"
    @addCallback "onUnMark"
    @addCallback "onLink"
    @addCallback "onUnLink"
    @addCallback "onFocus"
    @addCallback "onUnFocus"
    @addCallback "onDestruction"
    @addCallback "onAgeChanged"

    @addCallback "onVisiblePast"
    @addCallback "onVisibleFuture"
    @addCallback "onInvisible"

  # ============================================================================
  # Returns the assigned Hivent.
  # ============================================================================
  getHivent: ->
    @_hivent

  # ============================================================================
  # Notifies all listeners that the HiventHandle is now active. Usually, this is
  # triggered when a map or timeline icon belonging to a Hivent is being
  # clicked. "mousePixelPosition" may be passed and should be the click's
  # location in device coordinates.
  # ============================================================================
  activeAll: (mousePixelPosition) ->
    @_activated = true
    ACTIVE_HIVENTS.push(@)
    if @regionMarker?
      @regionMarker.makeVisible()
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
    if @regionMarker?
      @regionMarker.makeVisible()
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
    if @regionMarker?
      @regionMarker.makeInvisible()
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
    if @regionMarker?
      @regionMarker.makeInvisible()
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
  # All linking functions are used for similar purposes as the mark functions.
  # Hower, in the past they were designed to differenciate between showing
  # tooltips on hover and just highlighting an icon.
  # TODO: Clean up and remove one type of methods if possible.
  # ============================================================================
  linkAll: (mousePixelPosition) ->
    if window.LINKED_HIVENT!=0
      window.LINKED_HIVENT.unLinkAll 0
    window.LINKED_HIVENT=@

    #window.hgInstance.hivent_list_module.activateElement(@_hivent.id)
    unless @_linked
      @_linked = true
      @notifyAll "onLink", mousePixelPosition, @

  link: (obj, mousePixelPosition) ->
    if window.LINKED_HIVENT.unLink!=0
      window.LINKED_HIVENT.unLinkAll obj, 0
    window.LINKED_HIVENT=@
    #window.hgInstance.hivent_list_module.activateElement(@_hivent.id)
    unless @_linked
      @_linked = true
      @notify "onLink", obj, mousePixelPosition, @

  unLinkAll: (mousePixelPosition) ->

    window.LINKED_HIVENT=0
    #window.hgInstance.hivent_list_module.deactivateElement(@_hivent.id)
    if @_linked
      @_linked = false
      @notifyAll "onUnLink", mousePixelPosition, @

  unLink: (obj, mousePixelPosition) ->

    LINKED_HIVENT=0
    #window.hgInstance.hivent_list_module.deactivateElement(@_hivent.id)
    if @_linked
      @_linked = false
      @notify "onUnLink", obj, mousePixelPosition, @

  # ============================================================================
  # Notifies all listeners to focus on the Hivent associated with the
  # HiventHandle.
  # "mousePixelPosition" is very likely to be useless here and may be removed
  # in future code cleaning sessions ;)
  # ============================================================================
  focusAll: (mousePixelPosition) ->
    @_focussed = true

    @notifyAll "onFocus", mousePixelPosition

  # ============================================================================
  # Notifies a specific listener (obj) to focus on the Hivent associated with
  # the HiventHandle.
  # "mousePixelPosition" is very likely to be useless here and may be removed
  # in future code cleaning sessions ;)
  # ============================================================================
  focus: (obj, mousePixelPosition) ->
    @_focussed = true
    @notify "onFocus", obj, mousePixelPosition

  # ============================================================================
  # Notifies all listeners that the Hivent associated with the HiventHandle
  # shall no longer be focussed.
  # "mousePixelPosition" is very likely to be useless here and may be removed
  # in future code cleaning sessions ;)
  # ============================================================================
  unFocusAll: (mousePixelPosition) ->
    @_focussed = false

    @notifyAll "onUnFocus", mousePixelPosition

  # ============================================================================
  # Notifies a specific listener (obj) that the Hivent associated with the
  # HiventHandle shall no longer be focussed.
  # "mousePixelPosition" is very likely to be useless here and may be removed
  # in future code cleaning sessions ;)
  # ============================================================================
  unFocus: (obj, mousePixelPosition) ->
    @_focussed = false
    @notify "onUnFocus", obj, mousePixelPosition

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

  # # ============================================================================
  # show: (obj) ->
  #   @_visible = true
  #   @notify "onShow", obj, @

  # # ============================================================================
  # showAll: () ->
  #   @_visible = true
  #   @notifyAll "onShow", @

  # # ============================================================================
  # hide: (obj) ->
  #   @_visible = false
  #   @notify "onHide", obj, @

  # # ============================================================================
  # hideAll: () ->
  #   @_visible = false
  #   @notifyAll "onHide", @

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
  ACTIVE_HIVENTS = []

  @DEACTIVATE_ALL_HIVENTS: ->

    for hivent in ACTIVE_HIVENTS
      hivent?.inActiveAll {x:0, y:0}

    ACTIVE_HIVENTS = []

  @DEACTIVATE_ALL_OTHER_HIVENTS: (handle)->

    for hivent in ACTIVE_HIVENTS
      unless hivent is handle
        hivent?.inActiveAll {x:0, y:0}

    ACTIVE_HIVENTS = $.grep ACTIVE_HIVENTS, (value) ->
      return value == handle

  window.LINKED_HIVENT=0
