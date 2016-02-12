window.HG ?= {}

# ============================================================================
# <input type='text' name='id'>

class HG.NewCountryLabel

  # ============================================================================
  constructor: (@_hgInstance, pos) ->

    # add to HG instance
    @_hgInstance.newCountryLabel = @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onChangeName'

    ## PROBLEM:
    # I need a text field with the following three characterstics:
    # 1. it needs to be in the coordinate system of the world
    # 2. it needs to be draggable
    # 3. its text needs to be editable

    ## SOLUTIONS:
    # A) use Leaflet element
    #   (+) in coordinate system
    #   (-) no element is both draggable and editable
    # B) use HTML text input in the view point
    #   (+) draggable and editable
    #   (-) not in coordinate system
    #   (-) position does not update on zoom / pan of the map
    # => :( that is going to be hard...

    # # setup Label
    # @_label = new L.Label()
    # @_label.setContent "PLEASE TYPE THE NEW NAME"
    # @_label.setLatLng pos
    # @_hgInstance.map._map.showLabel @_label

    # $(@_label).attr 'id', 'new-marker-label'

    # # try with marker (fake it as background)
    # marker = L.marker new L.LatLng(37.9, -77), {
    #       icon: L.mapbox.marker.icon({
    #         'marker-color': 'ff8888'
    #     }),
    #     draggable: true
    # });

    # marker.bindPopup('This marker is draggable! Move it around.');
    # marker.addTo(map);

    # change
    $(@_elem).on 'keyup mouseup', (e) =>
      # tell everyone the new value
      @notifyAll 'onChangeName', e.currentTarget.value