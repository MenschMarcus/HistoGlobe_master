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
  constructor: (@_id, geom=null, names={}) ->
    @_geom = @_validateGeom geom
    @_names = @_validateNames names
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
  # ensure that each geometry put into an HG.Area is valid for Leaflet
  # output: [[[]]]
  _validateGeom: (geom) ->
    # console.log geom
    geom


  # ============================================================================
  # ensure that each name put into an HG.Area has the valid form of
  # {'commonName': string, 'pos': {'lat': float, 'lng': float}}
  _validateNames: (names) ->
    # TODO
    names
