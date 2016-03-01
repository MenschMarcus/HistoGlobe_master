window.HG ?= {}

# ============================================================================
# MODEL class
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

  # ----------------------------------------------------------------------------
  getStyle: () ->               @_getStyle()

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

  # ============================================================================
  # one function does all the coloring depending on the state of the area
  # this was SO hard to come up with. Please no major changes
  # -> it will be a pain in the ***
  _getStyle: () ->

    ## initial style configuration

    # NB! different vocabulary for leaflet layers and svg paths (animated by d3)
    #   property          leaflet       svg (d3)
    #   ------------------------------------------------
    #   areaColor         fillColor     fill
    #   areaOpacity       fillOpacity   fill-opacity
    #   borderColor       color         stroke
    #   borderOpacity     opacity       stroke-opacity
    #   bordeWidth        weight        stroke-width

    style = {
      'areaColor' :      HGConfig.color_white.val
      'areaOpacity' :    HGConfig.area_full_opacity.val
      'borderColor' :    HGConfig.color_bg_dark.val
      'borderOpacity' :  HGConfig.border_opacity.val
      'borderWidth' :    HGConfig.border_width.val
    }


    ## change certain style properties based on the area status

    # decision tree:        ___ selected? ___
    #                     1/                 \0
    #                treated?                |
    #             1/         \0              |
    #             |       focused?        focused?
    #             |      1/      \0      1/      \0
    #            (T)   (UTF)    (UT)    (NF)     (N)

    if @_selected

      if @_treated
        # (T)
        style.areaColor = HGConfig.color_active.val

      else  # not treated
        if @_focused
          # (UTF)
          style.areaColor = HGConfig.color_highlight.val

        else # not focused
          # (UT)
          style.areaColor = HGConfig.color_active.val
          style.areaOpacity = HGConfig.area_half_opacity.val

    else  # not selected
      if @_focused
        # (NF)
        style.areaColor = HGConfig.color_highlight.val
        style.areaOpacity = HGConfig.area_half_opacity.val

      # else not focused
        # (N) => initial configuration => no change

    return style