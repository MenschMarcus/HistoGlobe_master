window.HG ?= {}

# ==============================================================================
# describe here what the class / its objects are responsible for
# the more detailed, the better it is to fully understand, maintain and extend it
# ==============================================================================

class HG.ClassName

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # creates an object of the class and manages all its configs, variables, ...
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onCallbackName"

    # handle config
    defaultConfig =
      property: 'value',

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  # hgInit is only needed when it is a module stated in the modules.json
  # it will receive the hgInstance from the HistoGlobe.coffee
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.className = @

    # init variables
    @_myMemberVariable = null

    # start!
    @_hgInstance.onAllModulesLoaded @, () =>
      #ä

  # ============================================================================
  publicMemberFunction: () ->


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # use comments, please :)
  _privateMemberFunction: (parameter...) ->

  # ----------------------------------------------------------------------------
  _anotherPrivateMemberFunction: (parameter...) ->