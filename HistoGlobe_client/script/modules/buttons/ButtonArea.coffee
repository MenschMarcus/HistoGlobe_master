window.HG ?= {}

class HG.ButtonArea

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor : (@_id,                #
      positionX,                      # center, right or left
      positionY,                      # center, top or bottom
      orientation,                    # horizontal or vertical
      direction                       # append or prepend
    ) ->

    @_positionX = new HG.StateVar ['center', 'right', 'left']
    @_positionX.set positionX

    @_positionY = new HG.StateVar ['center', 'top', 'bottom']
    @_positionY.set positionY

    @_orientation = new HG.StateVar ['horizontal', 'vertical']
    @_orientation.set orientation

    @_direction = new HG.StateVar   ['append', 'prepend']
    @_direction.set direction

    @_groups = new HG.ObjectArray()

  # ============================================================================
  hgInit: (@_hgInstance) ->

    @_container = document.createElement 'div'
    @_container.id = @_id
    @_container.className = 'buttons-' + @_positionY.get() + '-' + @_positionX.get()

    @_domElem = $(@_container)

    @_hgInstance._top_area.appendChild @_container

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
