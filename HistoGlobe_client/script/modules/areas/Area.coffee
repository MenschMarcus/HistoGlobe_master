window.HG ?= {}

# ============================================================================
# MODEL class (DTO)
# contains data about each Area in the system
# names = {
#   'commonName': string,
#   'pos':        {'lat': float, 'lng': float}
# }

class HG.Area

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_id, @_geom=null, @_names={}) ->
    @_focused = no    # is area currently in focus (hovered)?
    @_selected = no   # is area currently selected?
    @_treated = no    # for edit mode: area has already been treated?

  # ============================================================================
  getId: () ->            @_id

  # ============================================================================
  setGeometry: (geom) ->  @_geom = geom
  setGeom: (geom) ->      @_geom = geom
  getGeometry: () ->      @_geom
  getGeom: () ->          @_geom

  # ============================================================================
  setNames: (names) ->    @_names = names
  getNames: () ->         @_names

  # ============================================================================
  deselect: () ->         @_selected = no
  select: () ->           @_selected = yes
  isSelected: () ->       @_selected

  # ============================================================================
  unfocus: () ->          @_focused = no
  focus: () ->            @_focused = yes
  isFocused: () ->        @_focused

  # ============================================================================
  treat: () ->            @_treated = yes
  untreat: () ->          @_treated = no
  isTreated: () ->        @_treated


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
