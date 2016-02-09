window.HG ?= {}

# DEVEL OPTION: tooltips are annoying... take care of styling them later
TOOLTIPS = no

class HG.Button

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # TODO
  # as parent div, accept HG.Div, jQuery object or normal JS object

  # ============================================================================
  # button object into constructor
  #   * = required, *A / *B = alternative -> either A or B have to be provided
  # {
  #   *A  parentDiv:    $(DOM_element)
  #   *B  parentArea:   name_of_button_area
  #       groupName:    name_of_button_group_in_button_area
  #   *   id:           buttonIdInCamelCase (!)
  #       hide:         bool (yes = hidden, no = shown)
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
  #
  # usage
  #   @_hgInstance.buttons.buttonName.onCallbackName @, () =>
  # ============================================================================
  constructor: (@_hgInstance, @_config) ->

    # add button to button object in HG instance
    unless @_hgInstance.buttons
      @_hgInstance.buttons = {}  # initially add object to hgInstance

    @_hgInstance.buttons[@_config.id] = @

    # init state
    @_states = new HG.ObjectArray @_config.states
    @_state = @_states.getByIdx 0 # initially start with first (= 'normal') state
    @_enabled = yes

    # init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # add all callbacks of all states in the very beginning
    for state in @_config.states
      @addCallback state.callback

    # create button itself
    @_button = new HG.Div @_config.id, ['button'], @_config.hide

    # set state-dependend properties of button
    @_updateState()

    # finally add button either to parent div or to button area
    if @_config.parentDiv
      # TODO accept HG.Div, jQuery object or normal JS object
      @_config.parentDiv.appendChild @_button.obj()
    else if @_config.parentArea
      @_config.parentArea.addButton @_button, @_config.groupName


  # ============================================================================
  changeState: (stateId) ->
    oldState = @_state
    # find new state
    @_state = @_states.getByPropVal 'id', stateId
    # update old state to new state
    @_updateState oldState


  # ============================================================================
  disable: () ->
    @_button.dom().addClass 'button-disabled'
    @_enabled = no

  enable: () ->
    @_button.dom().removeClass 'button-disabled'
    @_enabled = yes

  activate: () ->
    if @_enabled    # case: button enabled and active
      @_button.dom().addClass 'button-active'
    else            # case: button disabled and active
      @_button.dom().removeClass 'button-disabled'
      @_button.dom().addClass 'button-disabled-active'

  deactivate: () ->
    if @_enabled    # case: button enabled and active
      @_button.dom().removeClass 'button-active'
    else            # case: button disabled and active
      @_button.dom().removeClass 'button-disabled-active'
      @_button.dom().addClass 'button-disabled'

  # ============================================================================
  show: () ->         @_button.dom().show()
  hide: () ->         @_button.dom().hide()

  # ============================================================================
  remove: () ->       @_button.dom().remove()

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
        @_button.dom().removeClass c

  # ============================================================================
  _setClasses: () ->
    if @_state.classes
      for c in @_state.classes
        @_button.dom().addClass c

  # ============================================================================
  _setTooltip: () ->
    if @_state.tooltip and TOOLTIPS
      @_button.dom().tooltip {
        title: @_state.tooltip,
        placement: 'right',
        container: 'body'
      }

  # ============================================================================
  _setIcon: () ->
    # remove old icon
    @_button.dom().empty()
    icon = null

    # add new icon
    if @_state.iconFA           # 1. font awesome icon
      icon = new HG.Icon null, ['fa', 'fa-' + @_state.iconFA]

    else if @_state.iconOwn     # 2. own icon
      icon = new HG.Div '', 'own-button'
      icon.dom().css 'background-image', 'url("' + @_state.iconOwn + '")'

    else                # no icon
      console.error "No icon for button " + @_id + " set!"

    @_button.append icon if icon?

  # ============================================================================
  _setCallback: () ->
    # clear callbacks first to prevent multiple click handlers on same DOM element
    @_button.dom().unbind 'click'
    # define new callback
    @_button.dom().click () =>
      # callback = tell everybody that state has changed
      # hand button itself (@) into callback so everybody can operate on the button (e.g. change state)
      @notifyAll @_state.callback, @