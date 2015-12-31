window.HG ?= {}

class HG.Button

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # button object into constructor
  #   * = required, *A / *B = alternative -> either A or B have to be provided
  # {
  #   *   hgInstance:   hgInstance,
  #   *A  parentDiv:    $(DOM_element)
  #   *B  parentGroup:  button_group
  #   *   id:           buttonIdInCamelCase (!)
  #   *   states:
  #       [
  #         {
  #           *   id:       id                must be unique
  #               classes:  []                classes of DOM element
  #               tooltip:  text
  #           *A  iconFA:   name_of_fa_icon   https://fortawesome.github.io/Font-Awesome/icons/
  #           *B  iconOwn:  path_to_own_file  (alternative to iconFA one of the two must be set = not null)
  #           *   callback: onCallbackName
  #         },
  #       ]
  # }
  # ============================================================================
  constructor: (@_hgInstance, @_buttonConfig) ->

    # add button to button object in HG instance
    unless @_hgInstance.buttons
      @_hgInstance.buttons = {}  # initially add object to hgInstance
    @_hgInstance.buttons[@_buttonConfig.id] = @

    # init state
    @_state = @_buttonConfig.states[0]

    # init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # add all callbacks of all states in the very beginning
    for state in @_buttonConfig.states
      @addCallback state.callback

    # create button itself
    @_button = document.createElement 'div'
    @_buttonDOM = $(@_button)
    if @_buttonConfig.id
      @_button.id = @_buttonConfig.id
    else
      console.error "No id for button given!"
    @_button.className = 'button'

    # set state-dependend properties of button
    @_updateState()

    # finally add button either to parent div or to button area
    if @_buttonConfig.parentDiv
      @_buttonConfig.parentDiv.appendChild @_button
    else if @_buttonConfig.parentGroup
      @_buttonConfig[parentGroup].addButton @_button


  # ============================================================================
  changeState: (stateId) ->
    oldState = @_state
    # find new state
    state = $.grep @_buttonConfig.states, (state) ->
      state.id == stateId
    @_state = state[0]
    # update old state to new state
    @_updateState oldState


  # ============================================================================
  disable: () ->      @_buttonDOM.addClass 'button-disabled'
  enable: () ->       @_buttonDOM.removeClass 'button-disabled'
  setActive: () ->    @_buttonDOM.addClass 'button-active'
  setInactive: () ->  @_buttonDOM.removeClass 'button-active'

  # ============================================================================
  remove: () ->       @_buttonDOM.remove()


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
  _updateState: (oldState) ->
    @_removeClasses oldState.classes if oldState
    @_setClasses()     # optional
    @_setTooltip()     # optional
    @_setIcon()        # one of the two must be givem
    @_setCallback()

  # ============================================================================
  _removeClasses: (oldClasses) ->
    # remove old class(es)
    if oldClasses
      for c in oldClasses
        @_button.removeClass c

  # ============================================================================
  _setClasses: (oldClasses) ->
    if @_state.classes
      for c in @_state.classes
        @_button.addClass c

  # ============================================================================
  _setTooltip: () ->
    if @_state.tooltip
      @_buttonDOM.tooltip {
        title: @_state.tooltip,
        placement: 'right',
        container: 'body'
      }

  # ============================================================================
  _setIcon: () ->
    # remove old icon
    @_buttonDOM.empty()
    icon = null

    # add new icon
    if @_state.iconFA           # 1. font awesome icon
      icon = document.createElement 'i'
      icon.className = 'fa fa-' + @_state.iconFA

    else if @_state.iconOwn     # 2. own icon
      icon = document.createElement 'div'
      icon.className = 'own-button'
      $(icon).css 'background-image', 'url("' + @_state.iconOwn + '")'

    else                # no icon
      console.error "No icon for button " + @_id + " set!"

    @_button.appendChild icon if icon

  # ============================================================================
  _setCallback: () ->
    @_buttonDOM.click () =>
      @notifyAll @_state.callback
