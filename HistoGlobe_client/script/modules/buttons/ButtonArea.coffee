window.HG ?= {}

class HG.ButtonArea

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor : (@_hgInstance, config) ->

    # handle config
    defaultConfig =
      id:                 null                    # id of the DOM element (no underscore)
      classes:            null                    # ['className'] array
      parentDiv:          @_hgInstance._top_area  # div to which area will be added to
      absolutePosition:   true                    # false = relative position
      positionX:          'center'                # 'left', 'right' or 'center'
      positionY:          'center'                # 'top', bottom' or 'center'
      orientation:        'horizontal'            # 'horizontal' (default) or 'vertical'
      direction:          'append'                # 'append' (to back) or 'prepend' (to front)
                                                  #   (next button added to the area will be
                                                  #   appended to the back or prepended to the front)
    @_config = $.extend {}, defaultConfig, config

    # variables (read from config)
    @_positionX = new HG.StateVar ['center', 'right', 'left']
    @_positionX.set @_config.positionX

    @_positionY = new HG.StateVar ['center', 'top', 'bottom']
    @_positionY.set @_config.positionY

    @_orientation = new HG.StateVar ['horizontal', 'vertical']
    @_orientation.set @_config.orientation

    @_direction = new HG.StateVar ['append', 'prepend']
    @_direction.set @_config.direction

    @_groups = new HG.ObjectArray()
    @_spacerCtr = 1

    # make button area
    classes = ['button-area']
    classes.push 'button-area-abs' if @_config.absolutePosition
    classes.push 'button-area-' + @_positionY.get()
    classes.push 'button-area-' + @_positionX.get()
    if @_config.classes
      classes.push c for c in @_config.classes

    @_div = new HG.Div @_config.id, classes
    @_config.parentDiv.appendChild @_div.elem()

    # listen to slider
    @_hgInstance.onTopAreaSlide @, (t) =>
      if @_hgInstance.isInMobileMode()
        @_div.elem().style.left = '#{t*0.5}px'
      else
        @_div.elem().style.left = '0px'

  # ============================================================================
  # add button solo: leave out groupName (null) => will be put in single unnamed group
  # add button to group: set groupName
  # ============================================================================

  addButton: (button, groupName) ->
    # select group name
    name = null
    if groupName        # takes group if group name given
      name = groupName + '-group'
    else                # sets group name manually if no group name
      name = button.elem().id + '-group'

    # create button in group
    group = @_addGroup name
    group.appendChild button.elem()

  # ============================================================================
  addButtonGroup: (name) ->
    group = @_addGroup name

  removeButtonGroup: (name) ->
    @_removeGroup name

  # ============================================================================
  # usage 1: I want a spacer between two button groups =>   myButtonArea.addSpacer()
  # usage 2: I want a spacer inside a button group =>       myButtonArea.addSpacer 'group-name'
  addSpacer: (groupName) ->
    if groupName?
      group = @_addGroup groupName
    else
      group = @_addGroup 'spacer'+@_spacerCtr
    spacer = new HG.Div null, ['spacer']
    group.appendChild spacer.elem()
    @_spacerCtr++

  # ============================================================================
  moveVertical: (dist) ->
    if @_positionY.get() is 'top'
      @_div.jq().animate {'top': '+=' + dist}
    else if @_positionY.get() is 'bottom'
      @_div.jq().animate {'bottom': '+=' + dist}

  moveHorizontal: (dist) ->
    if @_positionX.get() is 'left'
      @_div.jq().animate {'left': '+=' + dist}
    else if @_positionX.get() is 'right'
      @_div.jq().animate {'right': '+=' + dist}

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addGroup: (id) ->
    # if group exists, take it
    group = (@_groups.getByPropVal 'id', id)
    if group
      return group
    # if group does not exist, create it
    else
      # add to UI
      classes = ['buttons-group']
      classes.push 'buttons-group-horizontal' if @_orientation.get() is 'horizontal'
      group = new HG.Div id, classes

      # append or prepend button (given in configuration of ButtonArea)
      if @_direction.get() is 'append'
        @_div.append group
        @_groups.append group.elem()

      else if @_direction.get() is 'prepend'
        @_div.prepend group
        @_groups.prepend group.elem()

      # add to group list
      return group.elem()

  # ============================================================================
  _removeGroup: (id) ->
    # remove from group list
    @_groups.remove 'id', id
    # remove from UI
    $('#'+id+'-group').remove()
