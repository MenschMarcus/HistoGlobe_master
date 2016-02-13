window.HG ?= {}

# DEVEL OPTION: tooltips are annoying... take care of styling them later
TOOLTIPS = no

class HG.Button

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # button object into constructor
  #   * = required, *A / *B = alternative -> either A or B have to be provided
  # {
  #       hgInstance
  #       id             buttonIdInCamelCase (!)
  #       classes       ['className1', 'className2', ...]
  #       stateConfigs:
  #         [
  #           {
  #             *   id:       id                must be unique
  #                 classes:  []                classes of DOM element
  #                 tooltip:  text
  #             *A  iconFA:   name_of_fa_icon   https://fortawesome.github.io/Font-Awesome/icons/
  #            *B  iconOwn:  path_to_own_file  (alternative to iconFA one of the two must be set = not null)
  #             *   callback: onCallbackName
  #           },
  #         ]
  # }
  #
  # usage
  #   @_hgInstance.buttons.buttonName.onCallbackName @, () =>
  # ============================================================================
  constructor: (@_hgInstance, id, classes=[], states) ->
    console.error 'no button id given' unless id?
    console.error 'no states of button given' unless Array.isArray(states)

    # add button to button object in HG instance
    @_hgInstance.buttons = {} unless @_hgInstance.buttons
    @_hgInstance.buttons[id] = @

    # init states (each state has a configuration file)
    @_states = new HG.ObjectArray
    for state in states
      defaultConfig =
        id:         'normal'
        classes:    []
        tooltip:    null
        iconFA:     null
        iconOwn:    null
        callback:   'onClick'
      @_states.push $.extend {}, defaultConfig, state

    # init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # add all callbacks of all states
    @_states.foreach (state) =>
      @addCallback state.callback

    # init variables
    @_state = @_states.getById 'normal' # initially start with first (= 'normal') state
    @_enabled = yes
    @_active = no

    # create button itself
    classes.unshift 'button'
    @_button = new HG.Div id, classes

    # set state-dependend properties of button
    @_updateState()


  # ============================================================================
  get: () -> @_button.dom()

  # ============================================================================
  changeState: (stateId) ->
    oldState = @_state                              # get old state
    @_state = @_states.getByPropVal 'id', stateId   # get new state
    @_updateState oldState                          # update new state

  # ============================================================================
  disable: () ->
    @_enabled = no
    @_setActivateAbleClasses()

  enable: () ->
    @_enabled = yes
    @_setActivateAbleClasses()

  # ============================================================================
  activate: () ->
    @_active = yes
    @_setActivateAbleClasses()

  deactivate: () ->
    @_active = no
    @_setActivateAbleClasses()

  # ============================================================================
  show: () ->           @_button.j().show()
  hide: () ->           @_button.j().hide()

  # ============================================================================
  destroy: () ->        @_button.j().remove()
  remove: () ->         @_button.j().remove()


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
  _setActivateAbleClasses: () ->
    ## 4 cases: none, button-disabled, button-active, button-disable-active
    # cleanup
    @_button.j().removeClass 'button-disabled'
    @_button.j().removeClass 'button-active'
    @_button.j().removeClass 'button-disabled-active'
    # setup
    if not @_enabled and @_active
      @_button.j().addClass 'button-disabled-active'
    else if not @_enabled and not @_active
      @_button.j().addClass 'button-disabled'
    else if @_enabled and @_active
      @_button.j().addClass 'button-active'

  # ============================================================================
  _updateState: (oldState) ->
    @_removeClasses oldState.classes if oldState
    @_setClasses()     # optional
    @_setTooltip()     # optional
    @_setIcon()        # one of the two must be givem
    @_setCallback()

  # ============================================================================
  _removeClasses: (oldClasses) ->
    if oldClasses
      @_button.j().removeClass cl for cl in oldClasses

  # ============================================================================
  _setClasses: () ->
    @_button.j().addClass cl for cl in @_state.classes

  # ============================================================================
  _setTooltip: () ->
    if @_state.tooltip and TOOLTIPS
      @_button.j().tooltip {
        title: @_state.tooltip,
        placement: 'right',
        container: 'body'
      }

  # ============================================================================
  _setIcon: () ->
    # remove old icon
    @_button.j().empty()
    icon = null

    # add new icon
    if @_state.iconFA           # 1. font awesome icon
      icon = new HG.Icon null, ['fa', 'fa-' + @_state.iconFA]

    else if @_state.iconOwn     # 2. own icon
      icon = new HG.Div '', 'own-button'
      icon.j().css 'background-image', 'url("' + @_state.iconOwn + '")'

    else                        # no icon
      console.error "No icon for button " + @_id + " set!"

    @_button.append icon if icon?

  # ============================================================================
  _setCallback: () ->
    # clear callbacks first to prevent multiple click handlers on same DOM element
    @_button.j().unbind 'click'
    # define new callback
    @_button.j().click () =>
      # callback = tell everybody that state has changed
      # hand button itself (@) into callback so everybody can operate on the button (e.g. change state)
      @notifyAll @_state.callback, @