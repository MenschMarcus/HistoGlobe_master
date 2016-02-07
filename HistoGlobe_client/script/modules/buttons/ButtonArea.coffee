window.HG ?= {}

##############################################################################
# creates a button area, requires a config with the following information:
# {
#   'id':            id of the DOM element (no underscore)
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

    @_direction = new HG.StateVar   ['append', 'prepend']
    @_direction.set config.direction

    @_groups = new HG.ObjectArray()

    # make button area
    @_container = document.createElement 'div'
    @_container.id = config.id
    @_container.className =   'button-area'
    @_container.className += ' button-area-abs' if config.position is 'abs'
    @_container.className += ' button-area-' + @_positionY.get()
    @_container.className += ' button-area-' + @_positionX.get()
    @_container.className += ' ' + config.classes if config.classes


    @_domElem = $(@_container)

    @_hgInstance._top_area.appendChild @_container

    # listen to slider
    @_hgInstance.onTopAreaSlide @, (t) =>
      if @_hgInstance.isInMobileMode()
        @_container.style.left = '#{t*0.5}px'
      else
        @_container.style.left = '0px'

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
      @_domElem.animate {'top': '+=' + dist}
    else if @_positionY.get() is 'bottom'
      @_domElem.animate {'bottom': '+=' + dist}

  moveHorizontal: (dist) ->
    if @_positionX.get() is 'left'
      @_domElem.animate {'left': '+=' + dist}
    else if @_positionX.get() is 'right'
      @_domElem.animate {'right': '+=' + dist}

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addGroup: (id) ->
    # if group exists, take it
    group = @_groups.getByPropVal 'id', id
    if group
      return group
    # if group does not exist, create it
    else
      # add to UI
      group = document.createElement 'div'
      group.id = id if id?  # in order to delete buttons when leaving edit mode
      group.className = 'buttons-group'
      if @_orientation.get() is 'horizontal'
        group.className += ' buttons-group-horizontal'

      # append or prepend button (given in configuration of ButtonArea)
      if @_direction.get() is 'append'
        @_container.appendChild group
        @_groups.append group

      else if @_direction.get() is 'prepend'
        @_container.insertBefore group, @_container.firstChild
        @_groups.prepend group

      # add to group list
      return group

  # ============================================================================
  _removeGroup: (id) ->
    # remove from group list
    @_groups.remove 'id', id
    # remove from UI
    $('#'+id+'-group').remove()
