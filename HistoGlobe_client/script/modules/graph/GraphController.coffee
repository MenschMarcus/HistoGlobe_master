window.HG ?= {}

class HG.GraphController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onShowGraphNode"
    @addCallback "onHideGraphNode"
    @addCallback "onGraphLoaded"

    @addCallback "onShowGraphNodeConnection"
    @addCallback "onHideGraphNodeConnection"

    @_nodes = new Array()
    @_connections = []

    @_timeline = null
    @_now = null
    @_config = config

    @_visibleLabels = []

    @_countryCodes = []

  # ============================================================================
  hgInit: (hgInstance) ->

    hgInstance.graphController = @

    @_timeline = hgInstance.timeline

    @_now = @_timeline.getNowDate()

    @_timeline.onNowChanged @, (date) ->
      @_now = date
      # for key,node of @_nodes
      #   node.setDate date
      for c in @_connections
        c.setDate date

      nr_connections = @_connections.length
      for c in @_connections
        #draw changes asynchronously
        execute_async = (c) =>
         setTimeout () =>
           c.drawChanges()
           --nr_connections
           if nr_connections is 0 # performance: after all connections updated their nodes
              for key,node of @_nodes
                node.drawChanges()
         , 0

        execute_async c  # async


    @_areaController = hgInstance.areaController

    @_areaController.onLabelsLoaded @,() =>

      @_visibleLabels = @_areaController.getAllLabels()

      @_loadCountryCodesFromCSV(@_config.countryCodesPath)

      @loadGraphFromCSV @_config.alliancePath

    # @_areaController.onCountriesLoaded @,() =>

    #   @_visibleLabels = @_areaController.getActiveAreas()

    #   @loadGraphFromCSV @_config.csvPath

  # ============================================================================
  loadGraphFromCSV: (path) ->

    $.get(path, (data) =>

      csvval=data.split("\n")

      #remove first entry:
      csvval.shift()

      lastCountryA = null
      lastCountryB = null
      lastYearBegin = null
      lastYearEnd = null

      for line in csvval
        csvvalue=line.split(",")
        if csvvalue[7] > 1940

          defense = csvvalue[13] is "1"
          neutrality = csvvalue[14] is "1"
          nonaggression = csvvalue[15] is "1"
          entente = csvvalue[16] is "1"

          info = new Array();
          info["defense"] = defense
          info["neutrality"] = neutrality
          info["nonaggression"] = nonaggression
          info["entente"] = entente

          latlngA = null
          latlngB = null
          IdA = null
          IdB = null
          oldA = false
          oldB = false
          nameA = null
          nameB = null

          if @_nodes[csvvalue[1]]?
            oldA = true
          latlngA = @_countryCodes[csvvalue[1]]
          IdA = csvvalue[1]
          nameA = csvvalue[2].replace('"', '').replace('"', '')

          if @_nodes[csvvalue[3]]?
            oldB = true
          latlngB = @_countryCodes[csvvalue[3]]
          IdB = csvvalue[3]
          nameB = csvvalue[4].replace('"', '').replace('"', '')

          #both found:
          if latlngA isnt null and latlngB isnt null

            yearBegin = csvvalue[7]
            yearEnd = csvvalue[10]

            #just one pair per alliance
            unless IdA is lastCountryA and IdB is lastCountryB and yearEnd is lastYearEnd
            #yearBegin is lastYearBegin and yearEnd is lastYearEnd

              #connection:
              startTime = new Date(yearBegin, csvvalue[6]-1, csvvalue[5])
              endTime = new Date(yearEnd, csvvalue[9]-1, csvvalue[8])

              newConnection = new HG.GraphNodeConnection(latlngA,latlngB,startTime,endTime,info)
              #@notifyAll "onShowGraphNodeConnection" ,latlngA,latlngB
              #@notifyAll "onShowGraphNodeConnection" ,newConnection

              newConnection.onShow @,(connection) =>
                @notifyAll "onShowGraphNodeConnection",connection
              newConnection.onHide @,(connection) =>
                @notifyAll "onHideGraphNodeConnection",connection
              newConnection.setDate @_now

              @_connections.push newConnection 

              #nodes:
              unless oldA
                newNode = new HG.GraphNode nameA,latlngA
                newNode.addConnection newConnection#TO REMOVE
                newConnection.addLinkedNode newNode
                @_nodes[IdA] = newNode

              else
                @_nodes[IdA].increaseRadius()
                @_nodes[IdA].addConnection newConnection
                newConnection.addLinkedNode @_nodes[IdA]

              #nodes:
              unless oldB
                newNode = new HG.GraphNode nameB,latlngB
                newNode.addConnection newConnection
                newConnection.addLinkedNode newNode
                @_nodes[IdB] = newNode
              else
                @_nodes[IdB].increaseRadius()
                @_nodes[IdB].addConnection newConnection#TO REMOVE
                newConnection.addLinkedNode @_nodes[IdB]

            lastCountryA = IdA
            lastCountryB = IdB
            lastYearBegin = yearBegin
            lastYearEnd = yearEnd

      @notifyAll "onGraphLoaded"
    )

  # ============================================================================
  getAllGraphNodes:()->
    return @_nodes

  # ============================================================================
  getActiveGraphNodes:()->
    result = []
    for key,n of @_nodes
      if n.isActive()
        result.push n
    return result

  # ============================================================================
  getActiveGraphNodeConnections:()->
    result = []
    for c in @_connections
      if c._isActive()
        result.push c
    return result

  # ============================================================================
  _loadCountryCodesFromCSV:(path)->

    $.get(path, (data) =>

      csvval=data.split("\n")

      for line in csvval
        csvvalue=line.split("|")
        #id = csvvalue[0].replace(/\s+/g, '')
        latlng = csvvalue[2].split(",")
        @_countryCodes[csvvalue[1]] = 
          lat: parseFloat(latlng[0])
          lng: parseFloat(latlng[1])
    )