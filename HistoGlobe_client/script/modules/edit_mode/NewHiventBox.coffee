window.HG ?= {}

class HG.NewHiventBox

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onSubmit'

    ### SETUP UI ###

    @_box = new HG.Div 'new-hivent-box', null
    @_hgInstance._top_area.appendChild @_box.dom()

    ## 1) choose between select existing and create new hivent
    @_setupDecisionStep()

    ## 2.1) select existing hivent
    # TODO

    ## 2.2) create new hivent
    @_hgInstance.buttons.newHiventInBox.onClick @, () ->
      # cleanup box and repupulate with new form
      @_box.j().empty()
      @_setupNewHiventForm()



    # @_inputField = new HG.TextInput @_hgInstance, 'new-hivent-box-input', null
    # @_inputField.j().attr 'size', 1 # starts with minimum size of 1
    # @_box.appendChild @_inputField

    # @_okButton = new HG.Button @_hgInstance, 'addChangeOK', ['confirm-button'],
    # [
    #   {
    #     'iconFA':   'check'
    #   }
    # ]
    # @_box.appendChild @_okButton.dom()


    ### INTERACTION ###
    ## to other modules

    # click OK => submit name and position
    # @_okButton.onClick @, () =>
    #   @notifyAll 'onSubmit', @_inputField.j().val(), @_map.containerPointToLatLng center



  # ============================================================================
  destroy: () ->
    @_okButton.remove()
    @_box.remove()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # decision: select existing hivent OR create new one?
  _setupDecisionStep: () ->

    ## option A) select existing hivent

    selectExistingWrapper = new HG.Div null, ['new-hivent-box-selection-wrapper']
    @_box.appendChild selectExistingWrapper

    selectExistingText = new HG.Div null, ['new-hivent-box-text']
    selectExistingText.j().html "Select Existing Hivent"
    selectExistingWrapper.appendChild selectExistingText

    searchBox = new HG.TextInput @_hgInstance, 'selectExitingHivent', null
    searchBox.setPlaceholder "find existing hivent by name, date, location, ..."
    selectExistingWrapper.appendChild searchBox

    searchIcon = new HG.Button @_hgInstance, 'existingHiventSearch', ['button-no-background'],
      [
        {
          'id':         'normal',
          'tooltip':    "Search for Existing Hivent",
          'iconFA':     'search'
          'callback':   'onClick'
        }
      ]
    selectExistingWrapper.appendChild searchIcon.dom()


    ## OR
    orHalf = new HG.Div null, ['new-hivent-box-selection-center', 'new-hivent-box-text']
    orHalf.j().html "OR"
    @_box.appendChild orHalf


    ## option B) create new hivent

    createNewHiventWrapper = new HG.Div 'create-new-hivent', ['new-hivent-box-selection-wrapper']
    @_box.appendChild createNewHiventWrapper

    newHiventButton = new HG.Button @_hgInstance, 'newHiventInBox', null,
      [
        {
          'id':       'normal',
          'tooltip':  "Create New Hivent",
          'iconOwn':  @_hgInstance._config.graphicsPath + 'buttons/new_hivent.svg',
          'callback': 'onClick'
        }
      ]
    createNewHiventWrapper.appendChild newHiventButton.dom()

    createNewHiventText = new HG.Div null, ['new-hivent-box-text']
    createNewHiventText.j().html "create new Hivent"
    createNewHiventWrapper.appendChild createNewHiventText


  # ============================================================================
  # forms with Hivent information
  _setupNewHiventForm: () ->

    formWrapper = new HG.Div 'new-hivent-info-wrapper', ['new-hivent-box-selection-wrapper']
    @_box.appendChild formWrapper

    ## name
    hiventName = new HG.TextInput @_hgInstance, 'newHiventName', ['new-hivent-information']
    hiventName.setPlaceholder "Name of the Historical Event"
    formWrapper.appendChild hiventName.dom()

    ## date
    # TODO: bind to timeline
    hiventDate = new HG.TextInput @_hgInstance, 'newHiventDate', ['new-hivent-information']
    hiventDate.setPlaceholder "DD.MM.YYYY"
    formWrapper.appendChild hiventDate.dom()

    ## location
    # TODO: create marker on the map, get GPS coordinates from it
    # TODO: detect location name and put marker on the map
    hiventLocation = new HG.TextInput @_hgInstance, 'newHiventLocation', ['new-hivent-information']
    hiventLocation.setPlaceholder "Location (optional)"
    formWrapper.appendChild hiventLocation.dom()

    ## description
    # TODO: make multiple lines
    # TODO: detect location name and put marker on the map
    hiventDescription = new HG.TextInputArea @_hgInstance, 'newHiventDescription', ['new-hivent-information'], [null, 5]
    hiventDescription.setPlaceholder "Description of the Hivent (take your space...)"
    formWrapper.appendChild hiventDescription.dom()

    ## link
    # TODO: style nicely
    hiventLink = new HG.TextInput @_hgInstance, 'newHiventLink', ['new-hivent-information']
    hiventLink.setPlaceholder "Link to wikipedia article"
    formWrapper.appendChild hiventLink.dom()

    ## changes
    # TODO: put in information about current change
    # TODO: connect this with hg action language
    hiventChanges = new HG.Div 'newHiventChanges', ['new-hivent-information']
    hiventChanges.j().html "Horst" #@_stepData.inData.namedAreas[0].getId() + " was named :)"
    formWrapper.appendChild hiventChanges.dom()