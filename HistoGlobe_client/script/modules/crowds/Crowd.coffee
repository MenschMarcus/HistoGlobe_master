window.HG ?= {}

class HG.Crowd

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (fillColor, nation, info, startLocation, locations, times, sizes, endTime, date) ->
  	
    @_fillColor = fillColor
    @_nation = nation
    @_info = info
    @_startLocation = startLocation
    @_locations = locations
    @_interpolatedLocations = []
    @_timesForInterpolatedLocations = []
    @_times = times
    @_sizes = sizes
    @_interpolatedSizes = []
    @_percentageSizes = []
    @_endTime = endTime
    @_date = date
    @_startTime = @_times[0]
    @_visitedLocations = []

    @_geojsonMarkerOptions =
  		radius: @_sizes[@_getIndex()],
  		fillColor: @_fillColor,
  		color: "grey",
  		weight: 1,
  		opacity: 1,
  		fillOpacity: 0.5

    @_initLocations()

  # ============================================================================
  getSize: ->
    @_sizes[@_getIndex()]

  # ============================================================================
  getSizes: ->
    @_sizes

  # ============================================================================
  getInterpolatedSizes: ->
    @_interpolatedSizes

  # ============================================================================
  getRadius: (index=-1) ->
    if index is -1
      index = @_getIndex()
    if @_sizes[index] > 1200
      return @_sizes[index] / DIVISOR
    5

  # ============================================================================
  getPercentageSize: ->
    @_percentageSizes[@_getIndex()]

  # ============================================================================
  setPercentageSize: (index, size) ->
    @_percentageSizes[index] = size

  # ============================================================================
  getStartLocation: ->
    @_startLocation

  # ============================================================================
  getLocations: ->
    @_interpolatedLocations

  # ============================================================================
  getRealLocations: ->
    @_locations

  # ============================================================================
  getTimesForLocations: ->
    @_timesForInterpolatedLocations

  # ============================================================================
  getTimesForRealLocations: ->
    @_times

  # ============================================================================
  getLocation: ->
    
    now = @_date.getTime()
    if now >= @_times[@_times.length-1].getTime() and now <= @_endTime.getTime()
      long = @_locations[@_times.length-1].lng
      lat = @_locations[@_times.length-1].lat
      location = L.latLng(lat,long)
    else
      location = @_getInterpolatedLocation(now)

    if @_visitedLocations.length >= 1
      @_visitedLocations.push location unless @_visitedLocations[@_visitedLocations.length-1].equals location
    else
      @_visitedLocations.push location
    location
    

  # ============================================================================
  getVisitedLocations: ->
    @_visitedLocations

  # ============================================================================
  clearVisitedLocations: ->
    @_visitedLocations = []

  # ============================================================================
  getOptions: ->
  	@_geojsonMarkerOptions

	# ============================================================================
  getNation: ->
  	@_nation

  # ============================================================================
  getInfo: ->
    @_info

  # ============================================================================
  getStartTime: ->
  	@_startTime

  # ============================================================================
  getEndTime: ->
  	@_endTime

  # ============================================================================
  getDate: ->
  	@_date

  # ============================================================================
  setDate: (date) ->
  	@_date = date

  # ============================================================================
  setSize: (size) ->
  	@_geojsonMarkerOptions.radius = size

  # ============================================================================
  setOpacity: (opacity) ->
  	@_geojsonMarkerOptions.opacity = opacity

  # ============================================================================
  destroy: ->
  	delete @

  # ============================================================================
  isInTime: ->
    if @_date.getTime() >= @_startTime and @_date.getTime() <= @_endTime
      return true
    return false

  # ============================================================================
  getInterpolatedTimeIndex: ->
    index = 0
    while index < @_timesForInterpolatedLocations.length-1
      if @_timesForInterpolatedLocations[index].getTime() <= @_date.getTime() and @_date.getTime() < @_timesForInterpolatedLocations[index+1].getTime()
        return index
      index++
    return index

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _getIndex: ->
    index = 0
    while index < @_times.length-1
      if @_times[index].getTime() <= @_date.getTime() and @_date.getTime() < @_times[index+1].getTime()
        return index
      index++
    @_currentIndex = index

  # ============================================================================
  _getNearestIndex: ->
    index = 0
    while index < @_times.length-1
      if @_times[index].getTime() <= @_date.getTime() and @_date.getTime() < @_times[index+1].getTime()

        if Math.abs(@_times[index].getTime() - @_date.getTime()) <= Math.abs(@_times[index+1].getTime() - @_date.getTime()) 
          return index
        else
          return index + 1
      index++
    @_currentIndex = index

  # ============================================================================
  _getIndexForInterpolated: ->
    index = 0
    while index < @_timesForInterpolatedLocations.length-1
      if @_timesForInterpolatedLocations[index].getTime() <= @_date.getTime() and @_date.getTime() < @_timesForInterpolatedLocations[index+1].getTime()
        return index
      index++
    @_currentIndex = index

  # ============================================================================
  _initLocations: ->
    time = @_startTime
    end = @_endTime

    # interpolate by time steps (15 days)
    '''while time.getTime() < end.getTime()
      @_interpolatedLocations.push @_getInterpolatedLocation time
      @_timesForInterpolatedLocations.push time
      time = new Date (time.getTime() + 15*24*60*60*1000)'''

    # interpolate by location steps (0.5 degree)
    if @_locations.length>=2 and @_locations.length is @_times.length

      # push starting point
      @_interpolatedLocations.push @_locations[0]
      @_timesForInterpolatedLocations.push @_times[0]
      @_interpolatedSizes.push @_sizes[0]

      for i in [0...@_locations.length-1]

        # current interpolated location
        tmp_location = L.latLng(@_locations[i].lat,@_locations[i].lng)

        # time range
        start_time = @_times[i]
        end_time = @_times[i+1]

        # location range
        lat_diff = @_locations[i+1].lat-@_locations[i].lat
        lng_diff = @_locations[i+1].lng-@_locations[i].lng

        # location interpolation direction
        dir = new THREE.Vector2 lat_diff,lng_diff
        dir.normalize()

        # location range and current distance to destination
        diff = Math.abs(Math.sqrt(Math.pow(lat_diff,2)+Math.pow(lng_diff,2)))
        cur_diff = diff

        while true

          # stepwise interpolated location
          tmp_location.lat += dir.x*0.5
          tmp_location.lng += dir.y*0.5

          # if stepped location in front of destination
          if Math.abs(Math.sqrt(Math.pow(@_locations[i].lat-tmp_location.lat,2)+Math.pow(@_locations[i].lng-tmp_location.lng,2)))<diff
            
            # linearly interpolated time
            cur_diff = Math.abs(Math.sqrt(Math.pow(@_locations[i+1].lat-tmp_location.lat,2)+Math.pow(@_locations[i+1].lng-tmp_location.lng,2)))
            delta = Math.abs(cur_diff/diff)
            tmp_time = new Date(start_time.getTime() + ((1-delta) * (end_time.getTime()-start_time.getTime())))

            # push interpolated point
            new_location = L.latLng(tmp_location.lat,tmp_location.lng)
            @_interpolatedLocations.push new_location
            @_timesForInterpolatedLocations.push tmp_time
            @_interpolatedSizes.push @_sizes[i]
          
          else
            break

        # push end point
        @_interpolatedLocations.push @_locations[i+1]
        @_timesForInterpolatedLocations.push @_times[i+1]
        @_interpolatedSizes.push @_sizes[i+1]
    
    else if @_locations.length==1 and @_locations.length is @_times.length
      @_interpolatedLocations.push @_locations[0]
      @_timesForInterpolatedLocations.push @_times[0]
      @_interpolatedSizes.push @_sizes[0]



  # ============================================================================
  _getInterpolatedLocation: (now) ->
    if @_times.length == 1 # no interpolation necessary (only one position)
      long = @_locations[0].lng
      lat = @_locations[0].lat
    else
      for i in [0...@_times.length-1]
        if now >= @_times[i].getTime() and now <= @_times[i+1].getTime()
          start = @_times[i].getTime()
          longStart = @_locations[i].lng
          latStart = @_locations[i].lat
          end = @_times[i+1].getTime()
          longEnd = @_locations[i+1].lng
          latEnd = @_locations[i+1].lat
        if now > @_times[i+1].getTime() # last position of crowd
          start = @_times[i+1].getTime()
          longStart = @_locations[i+1].lng
          latStart = @_locations[i+1].lat
          end = @_endTime.getTime()
          longEnd = @_locations[i+1].lng
          latEnd = @_locations[i+1].lat

        delta = (now - start)/(end - start)
        long = longStart + delta*(longEnd - longStart)
        lat = latStart + delta*(latEnd - latStart)

    L.latLng(lat,long)

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  DIVISOR = 1200