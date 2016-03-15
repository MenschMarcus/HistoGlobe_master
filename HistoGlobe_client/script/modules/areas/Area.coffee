window.HG ?= {}

# ============================================================================
# MODEL class
# DTO => direct access to memeber variables
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
        @_nameShort = null,
        @_nameFormal = null,
        @_geometry,
        @_representativePoint = null
        @_internationalStatus = 'F', # what is the international status of the area?
          # >1945: member of UN?
          # 'F' = full member,
          # 'O' = observer member,
          # 'P' = member of at least one specialized agency
          # 'N' = no UN member at all
        @_sovereigntyStatus = 'F',   # what is the status of its sovereignity?
          # 'F' = fully recognized by areas with international status 'F'
          # 'P' = partially recognized by at least one area with international status 'F'
          # 'N' = not recognized by area with international status 'F'
        @_territoryOf = null        # is the area (e.g. overseas) territory of another area?
      ) ->

    @_active = no               # is area currently on the map?
    @_selected = no             # is area currently selected?
    @_focused = no              # is area currently in focus (hovered)?
    @_inEdit = no               # is area in edit mode?


    @resetRepresentativePoint() unless @_representativePoint


  # ============================================================================
  setId: (id) ->                      @_id = id
  getId: () ->                        @_id

  # ----------------------------------------------------------------------------
  setGeometry: (geom) ->              @_geometry = geom
  getGeometry: () ->                  @_geometry
  hasGeometry: () ->                  @_geometry.isValid()

  # ----------------------------------------------------------------------------
  # TODO: überarbeiten
  setName: (name) ->                  @_name = name
  getName: () ->                      @_nameShort
  hasName: () ->                      @_name isnt null

  # ----------------------------------------------------------------------------
  resetRepresentativePoint: () ->     @_representativePoint = @_geometry.getCenter()
  setRepresentativePoint: (point) ->  @_representativePoint = point
  getRepresentativePoint: () ->       @_representativePoint

  # ----------------------------------------------------------------------------
  getStyle: () ->                     @_getStyle()

  # ============================================================================
  activate: () ->                     @_active = yes
  deactivate: () ->                   @_active = no
  isActive: () ->                     @_active

  # ----------------------------------------------------------------------------
  select: () ->                       @_selected = yes
  deselect: () ->                     @_selected = no
  isSelected: () ->                   @_selected

  # ----------------------------------------------------------------------------
  focus: () ->                        @_focused = yes
  unfocus: () ->                      @_focused = no
  isFocused: () ->                    @_focused

  # ----------------------------------------------------------------------------
  inEdit: (inEdit = no) ->            @_inEdit = inEdit
  isInEdit: () ->                     @_inEdit


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