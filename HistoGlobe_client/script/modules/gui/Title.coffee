window.HG ?= {}

# ==============================================================================
# VIEW class
# set up and handle title + background at the top
# TODO: make this more generic... but no need to do this now ;)
# ==============================================================================

class HG.Title

  # ============================================================================
  constructor: (@_hgInstance, text=null) ->

    # add to HG instance
    @_hgInstance.editTitle = @

    # create transparent title bar (insert as second child!, so it is background of everything)
    @_titleBar = new HG.Div 'titlebar', null
    @_hgInstance._top_area.insertBefore @_titleBar.dom(), @_hgInstance._top_area.firstChild.nextSibling

    # create actual title bar (insert as third child!, so it does not cover buttons)
    @_title = new HG.Div 'title', null
    @_title.j().html text if text?
    @_hgInstance._top_area.insertBefore @_title.dom(), @_hgInstance._top_area.firstChild.nextSibling.nextSibling

    @resize()

    # resize automatically
    $(window).on 'resize', @resize

  # ============================================================================
  set: (txt) ->   @_title.j().html txt
  clear: () ->    @_title.j().html ''

  # ============================================================================
  resize: () =>
    width = $(window).width() -
      2 * HGConfig.element_window_distance.val -
      2 * HGConfig.title_distance_horizontal.val -
      HGConfig.logo_width.val -
      $('#editButtons').width()
    # PAIN IN THE AAAAAAAAAAASS!
    @_title.dom().style.width = width + 'px'
    @_hgInstance._onResize()


  # ============================================================================
  destroy: () ->
    @_titleBar?.j().empty()
    @_titleBar?.j().remove()
    delete @_titleBar?
    @_title?.j().empty()
    @_title?.j().remove()
    delete @_title?