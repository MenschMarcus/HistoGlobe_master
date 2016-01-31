window.HG ?= {}

class HG.ButtonArea

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor : (@_id, @_position, orientation) ->
    @_orientation = if orientation is 'horizontal' then 'horizontal' else 'vertical'
    @_groups = new HG.ObjectArray()

  # ============================================================================
  hgInit: (hgInstance) ->
    @_hgInstance = hgInstance
    @_hgInstance.button_area = @

    @_container = document.createElement "div"
    @_container.id = @_id
    @_container.className = "buttons-" + @_position

    @_hgInstance._top_area.appendChild @_container

    @_hgInstance.onTopAreaSlide @, (t) =>
      if @_hgInstance.isInMobileMode()
        @_container.style.left = "#{t*0.5}px"
      else
        @_container.style.left = "0px"

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

  # ============================================================================
  removeButtonGroup: (name) ->
    @_removeGroup name

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
      if @_orientation is 'horizontal'
        group.className += ' buttons-group-horizontal'
      @_container.appendChild group
      # add to group list
      @_groups.push group
      return group

  # ============================================================================
  _removeGroup: (id) ->
    # remove from group list
    @_groups.remove 'id', id
    # remove from UI
    $('#'+id+'-group').remove()
