window.HG ?= {}

class HG.ButtonArea

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor : (position, orientation) ->
    @_position = position
    @_orientation = if orientation is 'horizontal' then 'horizontal' else 'vertical'
    @_groups = []

  # ============================================================================
  hgInit: (hgInstance) ->
    @_hgInstance = hgInstance
    @_hgInstance.button_area = @

    @_container = document.createElement "div"
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
      name = groupName
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
  _addGroup: (name) ->
    # if group exists, take it
    group = $.grep @_groups, (g) ->
      g.id == name
    if group.length > 0
      return group[0]
    else
      # if group does not exist, create it
      group = document.createElement 'div'
      group.id = name if name?  # in order to delete buttons when leaving edit mode
      group.className = 'buttons-group'
      if @_orientation is 'horizontal'
        group.className += ' buttons-group-horizontal'
      @_container.appendChild group
      @_groups.push group
      return group

  # ============================================================================
  _removeGroup: (name) ->
    # TODO: remove from list

    # remove from UI
    groupDOM = document.getElementById name
    groupDOM.parentNode.removeChild group
