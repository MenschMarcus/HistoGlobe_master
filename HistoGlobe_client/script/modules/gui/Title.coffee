window.HG ?= {}

class HG.Title

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, txt='') ->

    @_div = document.createElement 'div'
    @_div.id = 'hg-title'
    @_hgInstance._top_area.appendChild @_div

    @_domElem = $(@_div)[0]

    # elements to calculate width of
    @_window = $(window)
    @_editButtons = $('#editButtons')

    $(window).on 'resize', @resize
    @resize()
    @set txt

  # ============================================================================
  set: (txt) ->
    @_domElem.innerHTML = txt

  # ============================================================================
  clear: () ->
    @_domElem.innerHTML = ''

  # ============================================================================
  resize: () =>
    width = @_window.width() -
      2 * HGConfig.element_window_distance.val -
      HGConfig.logo_width.val -
      @_editButtons.width()
    # PAIN IN THE AAAAAAAAAAASS!
    @_domElem.style.width = width + 'px'
    @_hgInstance._onResize()

