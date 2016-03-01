window.HG ?= {}

# ============================================================================
# MODEL class (DTO)
# contains data about each Area in the system
# geom = geojson object
# names = {
#   'commonName': string,
#   'pos':        {'lat': float, 'lng': float}
# }

class HG.Area

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_id, @_geometry, @_names={}) ->
    @_selected = no     # is area currently selected?
    @_focused = no      # is area currently in focus (hovered)?
    @_treated = no      # for edit mode: area has already been treated?

    @resetLabelPosition()


  # ============================================================================
  getId: () ->                  @_id

  # ----------------------------------------------------------------------------
  setGeometry: (geom) ->        @_geometry = geom
  setGeom: (geom) ->            @_geometry = geom
  getGeometry: () ->            @_geometry
  getGeom: () ->                @_geometry

  # ----------------------------------------------------------------------------
  resetLabelPosition: () ->     @_labelPosition = @_geometry.getCenter(yes)
  setLabelPosition: (pos) ->    @_labelPosition = pos
  getLabelPosition: () ->       @_labelPosition

  # ----------------------------------------------------------------------------
  setNames: (names) ->          @_names = names
  getNames: () ->               @_names
  getCommonName: () ->          @_names.commonName

  # ============================================================================
  deselect: () ->               @_selected = no
  select: () ->                 @_selected = yes
  isSelected: () ->             @_selected

  # ----------------------------------------------------------------------------
  unfocus: () ->                @_focused = no
  focus: () ->                  @_focused = yes
  isFocused: () ->              @_focused

  # ----------------------------------------------------------------------------
  treat: () ->                  @_treated = yes
  untreat: () ->                @_treated = no
  isTreated: () ->              @_treated


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################