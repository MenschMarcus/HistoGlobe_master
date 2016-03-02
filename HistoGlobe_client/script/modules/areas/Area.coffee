window.HG ?= {}

# ============================================================================
# MODEL class
# contains data about each Area in the system
# geom = geojson object
# name = string,
# representativePoint = {'lat': float, 'lng': float}

class HG.Area

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (
        @_id,
        @_geometry,
        @_name = null,
        @_representativePoint = {'lat': null, 'lng': null}
      ) ->

    @_selected = no     # is area currently selected?
    @_focused = no      # is area currently in focus (hovered)?
    @_inEdit = no       # is area in edit mode?

    @resetRepresentativePoint()


  # ============================================================================
  getId: () ->                      @_id

  # ----------------------------------------------------------------------------
  setGeometry: (geom) ->            @_geometry = geom
  getGeometry: () ->                @_geometry

  # ----------------------------------------------------------------------------
  setName: (name) ->                @_name = name
  getName: () ->                    @_name

  # ----------------------------------------------------------------------------
  resetRepresentativePoint: () ->   @_representativePoint = @_geometry.getCenter yes
  setRepresentativePoint: (pos) ->  @_representativePoint = pos
  getRepresentativePoint: () ->     @_representativePoint

  # ----------------------------------------------------------------------------
  getStyle: () ->                   @_getStyle()

  # ============================================================================
  deselect: () ->                   @_selected = no
  select: () ->                     @_selected = yes
  isSelected: () ->                 @_selected

  # ----------------------------------------------------------------------------
  unfocus: () ->                    @_focused = no
  focus: () ->                      @_focused = yes
  isFocused: () ->                  @_focused

  # ----------------------------------------------------------------------------
  inEdit: (inEdit = no) ->          @_inEdit = inEdit
  isInEdit: () ->                   @_inEdit


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

    # decision tree:        _________ inEdit? _________
    #                     1/                           \0
    #                 selected?                      selected?
    #             1/           \0                1/            \0
    #             |         focused?         focused?        focused?
    #             |       1/      \0       1/      \0      1/      \0
    #             x       x       x        x       x       x       x
    #           (ES)    (EF)     (E)     (NSF)   (NS)    (NF)     (N)


    if @_inEdit

      if @_selected
        # (ES)  in edit mode + selected + can not be focused => full active
        style.areaColor = HGConfig.color_active.val

      else # not selected

        if @_focused
          # (EF)  in edit mode + unselected + focused => full highlight
          style.areaColor = HGConfig.color_highlight.val

        else # not focused
          # (E)  in edit mode + unselected + not focused => half active
          style.areaColor = HGConfig.color_active.val
          style.areaOpacity = HGConfig.area_half_opacity.val

    else # not in edit

      if @_selected

        if @_focused
          # (NSF) normal area + selected + focused => full highlight
          style.areaColor = HGConfig.color_highlight.val

        else # not focused
          # (NS) normal area + selected + not focused => half active
          style.areaColor = HGConfig.color_active.val
          style.areaOpacity = HGConfig.area_half_opacity.val

      else # not selected

        if @_focused
          # (NF) normal area + unselected + focused => half highlight
          style.areaColor = HGConfig.color_highlight.val
          style.areaOpacity = HGConfig.area_half_opacity.val


        # else not focused
          # (N) normal area + unselected + not focused => initial configuration
          # => no change


    return style