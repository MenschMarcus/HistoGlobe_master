window.HG ?= {}

# fix swiper / d3 issue
SVGAnimatedString.prototype.indexOf = (e) -> @baseVal.indexOf(e)

class HG.StatisticsWidget extends HG.Widget

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      icon: ""
      name: ""
      title: ""
      yDomain: [0,0]
      xLableTicks: 0
      yLableTicks: 0
      yCaption: ""
      lines : [
        dataPath: ""
        color: ""
        width: ""
        smooth: false
        xAttributeName: ""
        yAttributeName: ""
        label: ""
      ]

    @_config = $.extend {}, defaultConfig, config
    @_canvas = null
    @_canvasWidth = 0
    @_canvasHeight = 0
    @_minDate = 0
    @_maxDate = 0
    @_nowMarker = null

    @_tooltips = []
    @_min_dist = 99999999

    @_timeline = null
    @_data = []
    @_dataLoadedCallback = undefined

    dsv = d3.dsv "|", "text/plain"
    parseDate = d3.time.format("%d.%m.%Y").parse

    lineIndex = 0
    for l in @_config.lines
      dsv l.dataPath, (error, data) =>
        config = @_config.lines[lineIndex]
        data.forEach (d) =>
          d[config.xAttributeName] = parseDate(d[config.xAttributeName])
          d[config.yAttributeName] = +d[config.yAttributeName]

        @_data.push
          config : config
          data : data

        if lineIndex == @_config.lines.length - 1
          if @_dataLoadedCallback?
            @_dataLoadedCallback()

        lineIndex++

    HG.Widget.call @, @_config

  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    @_timeline = hgInstance.timeline

    @setName @_config.name
    @setIcon @_config.icon

    @_sidebar.onWidthChanged @, (width) =>
      @_drawStatistics()
    @_drawStatistics() # just quickhack!!!!!!!!!



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################



  # ============================================================================
  _initNowMarker: ->

    @_nowMarker = @_canvas.append("rect")
          .attr("class", "statistics-widget-now-marker")
          .attr("x", @_dateToXCoordinate @_timeline.getNowDate())
          .attr("y", 0)
          .attr("width", 2)
          .attr("height", @_canvasHeight)

    @_timeline.onNowChanged @, (date) =>
      @_setNowMarkerPosition @_dateToXCoordinate date

  # ============================================================================
  _onDataLoaded: (callback) =>
    @_dataLoadedCallback = callback

    if @_data.length > 0
      @_dataLoadedCallback()

  # ============================================================================
  _drawStatistics: () =>

    @_onDataLoaded () =>
      if @_canvas?
        d3.select(@_canvas).remove()

      @content = document.createElement "div"
      @content.className = "statistics-widget swiper-no-swiping"

      if @_config.title?
        title = document.createElement "div"
        title.className = "statistics-widget statistics-widget-title"
        title.innerHTML = @_config.title
        @content.appendChild title

      if @_config.subtitle?
        subtitle = document.createElement "div"
        subtitle.className = "statistics-widget statistics-widget-subtitle"
        subtitle.innerHTML = @_config.subtitle
        @content.appendChild subtitle

      @setContent @content
      width = $(@content).width()
      height = Math.max width * 9/16, HGConfig.statistics_widget_min_height.val

      @_canvasWidth = width - HGConfig.statistics_widget_margin_left.val - HGConfig.statistics_widget_margin_right.val
      @_canvasHeight = height - HGConfig.statistics_widget_margin_top.val - HGConfig.statistics_widget_margin_bottom.val

      x = d3.time.scale()
          .range([0, @_canvasWidth])

      y = d3.scale.linear()
          .range([@_canvasHeight, 0])

      xAxis = d3.svg.axis()
          .scale(x)
          .orient("bottom")
          .ticks(@_config.xLableTicks, "")

      yAxis = d3.svg.axis()
          .scale(y)
          .orient("left")
          .ticks(@_config.yLableTicks, "")

      @_canvas = d3.select(@content).append("svg")
          .attr("width", width)
          .attr("height", height)
          .append("g")
          .attr("transform", "translate(" + HGConfig.statistics_widget_margin_left.val + "," + HGConfig.statistics_widget_margin_top.val + ")")

      count = 0
      for entry in @_data
        ++count
        line = d3.svg.line()
          .x((d) => return x(d[entry.config.xAttributeName]) )
          .y((d) => return y(d[entry.config.yAttributeName]) )

        line.interpolate("monotone") if entry.config.smooth

        x.domain(d3.extent(entry.data, (d) => return d[entry.config.xAttributeName] ))
        y.domain(@_config.yDomain)

        @_minDate = d3.min(entry.data, (d) => return d[entry.config.xAttributeName])
        @_maxDate = d3.max(entry.data, (d) => return d[entry.config.xAttributeName])

        @_svg = @_canvas.append("path")
          .datum(entry.data)
          .attr("class", "line")
          .attr("id", "line#{count}")
          .attr("d", line)
          .attr("stroke", "#{entry.config.color}")
          .attr("stroke-width", "#{entry.config.width}")

          #.on("mousemove", @_showTooltip)
          #.on("mouseout", @_hideTooltip)

        @_canvas.selectAll(".point")
          .data(entry.data)
          .enter().append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", (d) => return "#{entry.config.color}" )
          .attr("cx", (d) => return x(d[entry.config.xAttributeName]) )
          .attr("cy", (d) => return y(d[entry.config.yAttributeName]) )
          .attr("r", (d) => return 3)

        #################
        #label:

        # rect =  @_canvas.append("rect")
        #   .attr("width", 10)
        #   .attr("height", 10)
        #   .style("fill","#{entry.config.color}")
        #   .attr("x",15)
        #   .attr("y",15*count-15)

        # text = @_canvas.append("text")
        #     .attr("x", 30)
        #     .attr("y",15*count-15)
        #     .attr("dy","10px")
        #     .style("font-size","8px")
        #     .style("fill","black")
        #     .text("#{entry.config.label}")

        #tooltip:
        entry.focus = @_canvas.append("g")
            .attr("class", "focus"+count)
            #.style("display", "none");

        @_tooltips.push entry.focus

        entry.focus.style("fill","none")
        #entry.focus.style("stroke","steelblue")
        entry.focus.style("stroke","#{entry.config.color}")

        entry.focus.append("circle")
            .attr("r", 5.0);

        entry.focus.text = entry.focus.append("text")
            .attr("x", 15)
            .attr("dy",".35em")
            .style("font-size","#{HGConfig.statistics_widget_tooltip_size.val}#{HGConfig.statistics_widget_tooltip_size.unit}")
            .style("fill","#{entry.config.color}")
            #.style("fill","black")


      #@_svg.append("rect")
      rect = @_canvas.append("rect")
        .attr("class", "overlay")
        .attr("width", width)
        .attr("height", height)
        .on("mouseover", () => focus.style("display", null) for focus in @_tooltips )
        .on("mouseout", () => focus.style("display", "none") for focus in @_tooltips )
        .on("mousemove", @_showTooltip)

      rect.style("fill","none")
      rect.style("pointer-events","all")



        ##############################

      @_canvas.append("g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + @_canvasHeight + ")")
          .call(xAxis)

      @_canvas.append("g")
          .attr("class", "y axis")
          .call(yAxis)
          .append("text")
          .attr("transform", "rotate(-90)")
          .attr("y", 5)
          .attr("dy", "0.71em")
          .style("text-anchor", "end")
          .text(@_config.yCaption)

      @onDivClick @content, (e) =>
        x = e.clientX - $(@content).offset().left -
            HGConfig.statistics_widget_margin_left.val -
            HGConfig.widget_body_padding.val
        @_setNowMarkerPosition x
        @_updateTimeline x

      @_initNowMarker()





  # ============================================================================
  _showTooltip: () =>


    fx = d3.time.scale()
      .range([0, @_canvasWidth])
    fy = d3.scale.linear()
      .range([@_canvasHeight, 0])

    count = 0
    for entry in @_data


      ++count
      #console.log "onmouseloop nr : ",count
      #console.log entry.focus.attr("class")

      fx.domain(d3.extent(entry.data, (d) => return d[entry.config.xAttributeName] ))
      fy.domain(@_config.yDomain)

      bisectDate = d3.bisector((d)=> return d[entry.config.xAttributeName]).left

      x = window.event.clientX - $(@content).offset().left -
              HGConfig.statistics_widget_margin_left.val -
              HGConfig.widget_body_padding.val

      y = window.event.clientY - $(@content).offset().top -
              HGConfig.statistics_widget_margin_top.val -
              HGConfig.widget_body_padding.val

      x0 = fx.invert(x)

      i = bisectDate(entry.data, x0, 1)
      d0 = entry.data[i - 1]
      d1 = entry.data[i]

      d = d0
      if d1
        d = d1 if x0 - d0[entry.config.xAttributeName] > d1[entry.config.xAttributeName] - x0

      #y offset:(quickhack)
      yOffset = 0
      entry.focus.text.attr("dy","#{yOffset}px")
      yPosition = fy(d[entry.config.yAttributeName])
      if @_data[count-2]
        dist = @_data[count-2].focus.text.yPosition - yPosition
        if Math.abs(dist) <10
          if dist > 0
            yPosition = @_data[count-2].focus.text.yPosition - 15
            yOffset = @_data[count-2].focus.text.yOffset - 15
          else
            yPosition = @_data[count-2].focus.text.yPosition + 15
            yOffset = @_data[count-2].focus.text.yOffset + 15
          entry.focus.text.attr("dy","#{yOffset}px")
      entry.focus.text.yPosition = yPosition
      entry.focus.text.yOffset = yOffset


      entry.focus.attr("transform", "translate(" + fx(d[entry.config.xAttributeName]) + "," + fy(d[entry.config.yAttributeName]) + ")");
      #console.log "translate(" + fx(d[entry.config.xAttributeName]) + "," + fy(d[entry.config.yAttributeName]) + ")"
      entry.focus.select("text").text(d[entry.config.yAttributeName]);

      if i > entry.data.length/2
        entry.focus.text.attr("x", -55)
      else
        entry.focus.text.attr("x", 15)

      entry.focus.text.y =

      '''console.log(d3.mouse(@content));
      console.log "x", fx(d[entry.config.xAttributeName])
      console.log "y", fy(d[entry.config.yAttributeName])'''


      '''distx = window.event.clientX - (fx(d[entry.config.xAttributeName]) + $(@content).offset().left +
              HGConfig.statistics_widget_margin_left.val +
              HGConfig.widget_body_padding.val)
      disty = window.event.clientY - (fy(d[entry.config.yAttributeName]) + $(@content).offset().top +
              HGConfig.statistics_widget_margin_top.val +
              HGConfig.widget_body_padding.val)'''

      '''distx = d3.mouse(@content)[0] - fx(d[entry.config.xAttributeName])
      disty = d3.mouse(@content)[1] - fy(d[entry.config.yAttributeName])

      distance = Math.sqrt(distx * distx + disty * disty)


      if distance < @_min_dist
        for focus in @_tooltips
          focus.style("display", "none")
        entry.focus.style("display", null)
        @_min_dist = distance'''




  # ============================================================================
  _dateToXCoordinate: (date) =>

    if date.getTime() > @_maxDate.getTime()
      return @_canvasWidth

    if date.getTime() <= @_minDate.getTime()
      return 0

    return @_canvasWidth * (date.getTime() - @_minDate.getTime()) / (@_maxDate.getTime() - @_minDate.getTime())

  # ============================================================================
  _xCoordinateToDate: (x) =>
    if x > @_canvasWidth
      return @_maxDate

    if x < 0
      return @_minDate

    return new Date (@_maxDate.getTime() - @_minDate.getTime()) * x / @_canvasWidth + @_minDate.getTime()

  # ============================================================================
  _setNowMarkerPosition: (x) =>
    @_nowMarker.attr "x", Math.min(@_canvasWidth, Math.max(x, 0))

  # ============================================================================
  _updateTimeline: (x) =>
    @_timeline.moveToDate @_xCoordinateToDate(x), 0.5

