window.HG ?= {}


class HG.Button

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # button object into constructor
  #   * = required, *A / *B = alternative -> either A or B have to be provided
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
  #
  # usage
  #   @_hgInstance.buttons.buttonName.onCallbackName @, () =>
  # ============================================================================

  constructor: (@_hgInstance, id, classes=[], states, existParent=null) ->
    unless id?
      return console.error 'no button id given'
    unless Array.isArray(states)
      return console.error 'no states of button given'


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

    # make button generically accessible by CSS
    classes.unshift 'button'

    # create button itself
    unless existParent
      @_button = new HG.Div id, classes
    else  # if parent div already given, take it
      @_button = existParent
      # add all classes before
      @_button.j().addClass cl for cl in classes

    # set state-dependend properties of button
    @_updateState()

    # manually hide tooltip after clicking the button
    # HACK: bruteforce method: find tooltip among the first children of body
    # and delete it
    @_button.j().click () =>
      $('body > .tooltip').remove()


  # ============================================================================
  dom: () -> @_button.dom()

  # ============================================================================
  changeState: (stateId) ->
    oldState = @_state                              # get old state
    @_state = @_states.getByPropVal 'id', stateId   # get new state
    @_updateState oldState                          # update new state

  # ============================================================================
  disable: () ->
    @_enabled = no
    @_resetClasses()

  # ----------------------------------------------------------------------------
  enable: () ->
    @_enabled = yes
    @_resetClasses()

  # ----------------------------------------------------------------------------
  isEnabled: () ->
    @_enabled

  # ============================================================================
  activate: () ->
    @_active = yes
    @_resetClasses()

  # ----------------------------------------------------------------------------
  deactivate: () ->
    @_active = no
    @_resetClasses()

  # ----------------------------------------------------------------------------
  isActive: () ->
    @_active

  # ============================================================================
  show: () ->           @_button.j().show()
  hide: () ->           @_button.j().hide()

  # ============================================================================
  destroy: () ->        @_button.j().remove()
  remove: () ->         @destroy()
  delete: () ->         @destroy()


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
  _resetClasses: () ->
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

    # remove old classes
    if oldState
      @_button.j().removeClass cl for cl in oldState.classes

    # set new classes
    @_button.j().addClass cl for cl in @_state.classes

    # set tooltip
    # N.B: BOOTSTRAP tooltips, not jQuery UI Tooltips!
    # http://www.w3schools.com/bootstrap/bootstrap_ref_js_tooltip.asp
    if @_state.tooltip

      @_button.j().tooltip {
          title:      @_state.tooltip
          container:  'body'          # is that necessary?
          placement:  (context, source) ->
            return 'top'    if $(source).hasClass 'tooltip-top'
            return 'bottom' if $(source).hasClass 'tooltip-bottom'
            return 'left'   if $(source).hasClass 'tooltip-left'
            return 'right'  # fallback
          animation:  yes
        }

      # return 'top'    if $(source).hasClass 'tooltip-top'
      # return 'bottom' if $(source).hasClass 'tooltip-bottom'
      # return 'left'   if $(source).hasClass 'tooltip-left'
      # return 'right'  if $(source).hasClass 'tooltip-right'

    # remove old icon
    @_button.j().empty()
    icon = null

    # add new icon
    if @_state.iconFA           # 1. font awesome icon
      icon = new HG.Icon null, ['fa', 'fa-' + @_state.iconFA]

    else if @_state.iconOwn     # 2. own icon
      icon = new HG.Div '', 'own-button'
      icon.j().css 'background-image', 'url("' + @_state.iconOwn + '")'
      icon.j().hover ((e) =>
          a = @_state.iconOwn
          b = '-hover'
          pos = (@_state.iconOwn.length)-4
          $(e.target).css 'background-image', 'url("' + [a.slice(0,pos), b, a.slice(pos)].join('') + '")'
        ), (e) =>
          $(e.target).css 'background-image', 'url("' + @_state.iconOwn + '")'

    else                        # no icon
      console.error "No icon for button " + @_id + " set!"

    @_button.appendChild icon if icon?

    # clear old callbacks
    # -> prevent multiple click handlers on same DOM element
    @_button.j().unbind 'click'

    # set new callback
    @_button.j().click () =>
      # callback = tell everybody that state has changed
      # hand button itself (@) into callback so everybody can operate on the button (e.g. change state)
      @notifyAll @_state.callback, @



  # ============================================================================
  # just in case it is ever needed again...
  _calculateTooltipPosition: (context, source) ->
    sourceElement = {
      top:    $(source).offset().top
      left:   $(source).offset().left
      bottom: $(source).offset().top  + $(source).height()
      right:  $(source).offset().left + $(source).width()
    }
    viewport = {
      top:    0
      left:   0
      bottom: $(window).height()
      right:  $(window).width()
    }
    tooltipSpace = {
      top:    sourceElement.top  - viewport.top
      left:   sourceElement.left - viewport.left
      bottom: viewport.bottom    - sourceElement.bottom
      right:  viewport.right     - sourceElement.right
    }
    minDistance = 250

    console.log tooltipSpace

    # 1. priority: right
    if tooltipSpace.right > minDistance
      return 'right'

    # 2. priority: bottom
    if tooltipSpace.bottom > minDistance
      return 'bottom'

    # 3. priority: left
    if tooltipSpace.left > minDistance
      return 'left'

    # 4. priority: top
    if tooltipSpace.top > minDistance
      return 'top'

    # if nothing works, do what you want!
    return 'auto'