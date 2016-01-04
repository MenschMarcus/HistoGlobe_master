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
  #   *B  parentArea:   name_of_button_area
  #       groupName:    name_of_button_group_in_button_area
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
    @_states = new HG.ObjectArray @_buttonConfig.states
    @_state = @_states.getById 0 # initially start with first (= 'normal') state

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
      @_buttonConfig.parentDiv.appendChild @_button, @_buttonConfig.groupName
    else if @_buttonConfig.parentArea
      @_buttonConfig.parentArea.addButton @_button, @_buttonConfig.groupName


  # ============================================================================
  changeState: (stateId) ->
    oldState = @_state
    # find new state
    @_state = @_states.getByPropVal 'id', stateId
    # update old state to new state
    @_updateState oldState


  # ============================================================================
  disable: () ->      @_buttonDOM.addClass 'button-disabled'
  enable: () ->       @_buttonDOM.removeClass 'button-disabled'
  activate: () ->     @_buttonDOM.addClass 'button-active'
  deactivate: () ->   @_buttonDOM.removeClass 'button-active'

  # ============================================================================
  show: () ->         @_buttonDOM.show()
  hide: () ->         @_buttonDOM.hide()

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
        @_buttonDOM.removeClass c

  # ============================================================================
  _setClasses: () ->
    if @_state.classes
      for c in @_state.classes
        @_buttonDOM.addClass c

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
    # clear callbacks first to prevent multiple click handlers on same DOM element
    @_buttonDOM.unbind 'click'
    # define new callback
    @_buttonDOM.click () =>
      # callback = tell everybody that state has changed
      # hand button itself (@) into callback so everybody can operate on the button (e.g. change state)
      @notifyAll @_state.callback, @

      # tooltip
      # if c? and c.icon? and c.tooltip?
      #   c = $.extend {}, defaultConfig, c
      #   config = c
      #   icon.className = "fa " + config.icon
      #   $(button).attr('title', config.tooltip).tooltip('fixTitle').tooltip('show');
