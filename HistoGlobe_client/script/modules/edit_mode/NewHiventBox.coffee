window.HG ?= {}

class HG.NewHiventBox

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, @_operationDescription) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onReady'
    @addCallback 'onUnready'

    # include
    @_domElemCreator = new HG.DOMElementCreator

    ### SETUP UI ###

    @_hiventBox = @_domElemCreator.create 'div', 'new-hivent-box', null
    @_hgInstance.getTopArea().appendChild @_hiventBox

    ## 1) choose between select existing and create new hivent
    @_makeDecisionStep()

    ## 2.1) select existing hivent
    @_hgInstance.buttons.existingHiventSearch.onClick @, () ->
      # TODO: write id into out data and be ready :-)

    ## 2.2) create new hivent
    @_hgInstance.buttons.newHiventInBox.onClick @, () ->
      # cleanup box and repupulate with new form
      $(@_hiventBox).empty()
      @_makeNewHiventForm()


  # ============================================================================
  destroy: () ->
    @_hiventBox.remove()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # decision: select existing hivent OR create new one?
  _makeDecisionStep: () ->

    ## option A) select existing hivent

    selectExistingWrapper = @_domElemCreator.create 'div', null, ['new-hivent-box-selection-wrapper']
    @_hiventBox.appendChild selectExistingWrapper

    selectExistingText = @_domElemCreator.create 'div', null, ['new-hivent-box-text']
    $(selectExistingText).html "Select Existing Historical Event"
    selectExistingWrapper.appendChild selectExistingText

    searchBox = new HG.TextInput @_hgInstance, 'selectExitingHivent', ['new-hivent-input']
    searchBox.setPlaceholder "find existing hivent by name, date, location, ..."
    selectExistingWrapper.appendChild searchBox.getDOMElement()

    searchIcon = new HG.Button @_hgInstance,
      'existingHiventSearch', ['button-no-background'],
      [
        {
          'id':         'normal',
          'iconFA':     'search'
          'callback':   'onClick'
        }
      ]
    selectExistingWrapper.appendChild searchIcon.getDOMElement()


    ## OR
    orHalf = @_domElemCreator.create 'div', null, ['new-hivent-box-selection-center', 'new-hivent-box-text']
    $(orHalf).html "OR"
    @_hiventBox.appendChild orHalf


    ## option B) create new hivent

    createNewHiventWrapper = @_domElemCreator.create 'div', 'create-new-hivent', ['new-hivent-box-selection-wrapper']
    @_hiventBox.appendChild createNewHiventWrapper

    newHiventButton = new HG.Button @_hgInstance,
      'newHiventInBox', ['tooltip-bottom'],
      [
        {
          'id':       'normal',
          'tooltip':  "Create New Hivent",
          'iconOwn':  @_hgInstance.config.graphicsPath + 'buttons/new_hivent.svg',
          'callback': 'onClick'
        }
      ]
    createNewHiventWrapper.appendChild newHiventButton.getDOMElement()

    createNewHiventText = @_domElemCreator.create 'div', null, ['new-hivent-box-text']
    $(createNewHiventText).html "create new Historical Event"
    createNewHiventWrapper.appendChild createNewHiventText


  # ============================================================================
  # forms with Hivent information
  _makeNewHiventForm: () ->

    ### SETUP UI ###

    formWrapper = @_domElemCreator.create 'div', 'new-hivent-info-wrapper', ['new-hivent-box-selection-wrapper']
    @_hiventBox.appendChild formWrapper

    ## name
    hiventName = new HG.TextInput @_hgInstance, 'newHiventName', ['new-hivent-information']
    hiventName.setPlaceholder "Name of the Historical Event"
    formWrapper.appendChild hiventName.getDOMElement()

    ## date
    hiventDate = new HG.TextInput @_hgInstance, 'newHiventDate', ['new-hivent-information']
    hiventDate.setValue @_hgInstance.timeController.getNowDate().format(@_hgInstance.config.dateFormat)
    formWrapper.appendChild hiventDate.getDOMElement()

    ## location
    # TODO: create marker on the map, get GPS coordinates from it
    # TODO: detect location name and put marker on the map
    hiventLocation = new HG.TextInput @_hgInstance, 'newHiventLocation', ['new-hivent-information']
    hiventLocation.setPlaceholder "Location (optional)"
    formWrapper.appendChild hiventLocation.getDOMElement()

    ## description
    hiventDescription = new HG.TextInputArea @_hgInstance, 'newHiventDescription', ['new-hivent-information'], [null, 5]
    hiventDescription.setPlaceholder "Description of the Hivent (take your space...)"
    formWrapper.appendChild hiventDescription.getDOMElement()

    ## link
    # TODO: style nicely
    hiventLink = new HG.TextInput @_hgInstance, 'newHiventLink', ['new-hivent-information']
    hiventLink.setPlaceholder "Link to wikipedia article"
    formWrapper.appendChild hiventLink.getDOMElement()

    ## changes
    # TODO: put in information about current change
    # TODO: connect this with hg action language
    hiventChanges = @_domElemCreator.create 'div', 'newHiventChanges', ['new-hivent-information']
    $(hiventChanges).html @_operationDescription
    formWrapper.appendChild hiventChanges


    ## buttons
    # TODO: are the buttons really necessary or can't I reuse the buttons from the workflow window?
    # is against "direct manipulation" paradigm, but kind of makes sense
    # -> no! I should include them
    # abortButton = new HG.Button @_hgInstance,
        # 'addChangeAbort', ['button-abort'],
    #   [
    #     {
    #       'iconFA':   'times'
    #       'callback': 'onClick'
    #     }
    #   ]
    # formWrapper.appendChild abortButton.getDOMElement()

    # okButton = new HG.Button @_hgInstance,
        # 'addChangeOK', null,
    #   [
    #     {
    #       'iconFA':   'check'
    #       'callback': 'onClick'
    #     }
    #   ]
    # formWrapper.appendChild okButton.getDOMElement()


    ### INTERACTION ###

    ## name done => ready to submit
    hiventName.onChange @, (name) ->
      # save to data
      @_stepData.outData.hiventInfo.name = name
      # tell everyone: "I am done"
      if name isnt ''
        @notifyAll 'onReady'
      else
        @notifyAll 'onUnready'

    ## synchronize hivent date with timeline
    # timeline -> hivent box
    @_hgInstance.timeController.onNowChanged @, (date) ->
      hiventDate.setValue date.format(@_hgInstance.config.dateFormat)
      @_stepData.outData.hiventInfo.start_date = date.format()  # RFC 3339

    # timeline <- hivent box
    hiventDate.onChange @, (dateString) ->
      console.log dateString
      date = moment(dateString, @_hgInstance.config.dateFormat)
      @_hgInstance.timeController.setNowDate @, date
      @_stepData.outData.hiventInfo.start_date = date.format()  # RFC 3339

    # hack: it is possible to finish this step without changing the date
    # => date has to be initially written into output
    @_stepData.outData.hiventInfo.start_date = @_hgInstance.timeController.getNowDate().format()

    ## convert location to lat/lng coordinates
    # TODO: geocoding
    hiventLocation.onChange @, (location) ->
      @_stepData.outData.hiventInfo.location_name = location

    ## save the description
    hiventDescription.onChange @, (description) ->
      @_stepData.outData.hiventInfo.description = description

    ## save the link
    hiventLink.onChange @, (link) ->
      @_stepData.outData.hiventInfo.link_url = link