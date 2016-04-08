window.HG ?= {}

# ============================================================================
# MODEL class
# contains data about each Area in the system
# ============================================================================

class HG.Area

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_id) ->

    # dictionary for all names
    @_name = {}

    # status of its sovereignity?
    # 'F' = recognized by all fully sovereign states (default)
    # 'P' = partially recognized by at least one fully sovereign state
    # 'N' = not recognized by any fully sovereign state
    @_sovereigntyStatus = new HG.StateVar ['F', 'P', 'N']

    # hivents that created the area
    @_startHivent = null
    @_endHivent = null

    # area status properties
    @_active = no    # is area currently on the map?
    @_selected = no  # is area currently selected?
    @_focused = no   # is area currently in focus (hovered)?
    @_inEdit = no    # is area in edit mode?


  # ============================================================================
  setId: (id) ->                      @_id = id
  getId: () ->                        @_id

  # ----------------------------------------------------------------------------
  setGeometry: (geom) ->              @_geometry = geom
  getGeometry: () ->                  @_geometry
  hasGeometry: () ->                  @_geometry?.isValid()

  # ----------------------------------------------------------------------------
  resetRepresentativePoint: () ->     @_representativePoint = @_geometry.getCenter()
  setRepresentativePoint: (point) ->  @_representativePoint = point
  getRepresentativePoint: () ->       @_representativePoint

  # ----------------------------------------------------------------------------
  setShortName: (name) ->             @_name.short = name
  getShortName: () ->                 @_name.short

  setFormalName: (name) ->            @_name.formal = name
  getFormalName: () ->                @_name.formal

  removeName: () ->                   @_name = {}
  hasName: () ->                      @_name.short?

  # ----------------------------------------------------------------------------
  setSovereigntyStatus: (status) ->   @_sovereigntyStatus.set status
  getSovereigntyStatus: () ->         @_sovereigntyStatus.get()

  # ----------------------------------------------------------------------------
  setTerritoryOf: (area) ->           @_territoryOf = area
  getTerritoryOf: () ->               @_territoryOf


  # ============================================================================

  setStartHivent: (hivent) ->         @_startHivent = hivent
  getStartHivent: () ->               @_startHivent
  getStartDate: () ->                 @_startHivent.getHivent().effectDate

  setEndHivent: (hivent) ->           @_endHivent = hivent
  getEndHivent: () ->                 @_endHivent
  getEndDate: () ->                   if @_endHivent then @_endHivent.getHivent().effectDate else moment()

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

  # ============================================================================
  # one function does all the coloring depending on the state of the area
  # this was SO hard to come up with. Please no major changes
  # -> it will be a pain in the ***
  getStyle: () ->

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

        # check if internationally recognized
        if @_sovereigntyStatus.get() is 'P'
          style.areaColor = HGConfig.color_disabled.val
        if @_sovereigntyStatus.get() is 'N'
          style.areaColor = HGConfig.color_disabled_active.val


    return style