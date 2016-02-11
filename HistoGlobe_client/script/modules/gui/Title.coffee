window.HG ?= {}

class HG.Title

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, txt='') ->

    @_div = new HG.Div 'hg-title'
    @_hgInstance._top_area.appendChild @_div.dom()

    # elements to calculate width of
    @_window = $(window)
    @_editButtons = $('#editButtons')

    $(window).on 'resize', @resize
    @resize()
    @set txt

  # ============================================================================
  set: (txt) ->   @_div.j().html txt
  clear: () ->    @_div.j().html ''

  # ============================================================================
  resize: () =>
    width = @_window.width() -
      2 * HGConfig.element_window_distance.val -
      2 * HGConfig.title_distance_horizontal.val -
      HGConfig.logo_width.val -
      @_editButtons.width()
    # PAIN IN THE AAAAAAAAAAASS!
    @_div.dom().style.width = width + 'px'
    @_hgInstance._onResize()

