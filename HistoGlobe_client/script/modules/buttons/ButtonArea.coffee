window.HG ?= {}

##############################################################################
# creates a button area, requires a config with the following information:
# {
#   'id':            id of the DOM element (no underscore)
#   'classes':      additional classes in ['className'] array
#   'position':     'abs' (absolute, at the corners of the UI) or
#                   'rel' (relative, inside the currentdiv)
#   'positionX':    'left', 'right' or 'center' (default)
#   'positionY':    'top', bottom' or 'center' (default)
#   'orientation':  'horizontal' (default) or 'vertical'
#   'direction':    'append' (default) or 'prepend'
#                   (next button added to the area will be
#                   appended to the back or prepended to the front)
# }


class HG.ButtonArea

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor : (@_hgInstance, config) ->

    # variables (read from config)
    @_positionX = new HG.StateVar ['center', 'right', 'left']
    @_positionX.set config.positionX

    @_positionY = new HG.StateVar ['center', 'top', 'bottom']
    @_positionY.set config.positionY

    @_orientation = new HG.StateVar ['horizontal', 'vertical']
    @_orientation.set config.orientation

    @_direction = new HG.StateVar ['append', 'prepend']
    @_direction.set config.direction

    @_groups = new HG.ObjectArray()

    # make button area
    classes = ['button-area']
    classes.push 'button-area-abs' if config.position is 'abs'
    classes.push 'button-area-' + @_positionY.get()
    classes.push 'button-area-' + @_positionX.get()
    if config.classes
      classes.push c for c in config.c

    @_div = new HG.Div config.id, classes
    @_hgInstance._top_area.appendChild @_div.obj()

    # listen to slider
    @_hgInstance.onTopAreaSlide @, (t) =>
      if @_hgInstance.isInMobileMode()
        @_div.obj().style.left = '#{t*0.5}px'
      else
        @_div.obj().style.left = '0px'

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
      name = button.id + '-group'

    # create button in group
    group = @_addGroup name
    group.appendChild button

  # ============================================================================
  addButtonGroup: (name) ->
    group = @_addGroup name

  removeButtonGroup: (name) ->
    @_removeGroup name


  # ============================================================================
  moveVertical: (dist) ->
    if @_positionY.get() is 'top'
      @_div.dom().animate {'top': '+=' + dist}
    else if @_positionY.get() is 'bottom'
      @_div.dom().animate {'bottom': '+=' + dist}

  moveHorizontal: (dist) ->
    if @_positionX.get() is 'left'
      @_div.dom().animate {'left': '+=' + dist}
    else if @_positionX.get() is 'right'
      @_div.dom().animate {'right': '+=' + dist}

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
        @_groups.append group.obj()

      else if @_direction.get() is 'prepend'
        @_div.prepend group
        @_groups.prepend group.obj()

      # add to group list
      return group.obj()

  # ============================================================================
  _removeGroup: (id) ->
    # remove from group list
    @_groups.remove 'id', id
    # remove from UI
    $('#'+id+'-group').remove()
