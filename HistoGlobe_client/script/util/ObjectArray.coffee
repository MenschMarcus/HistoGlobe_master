window.HG ?= {}

# ============================================================================
# Array of objects
# [ {}, {}, ... ]
# assumption: each object in list is unique
# ============================================================================

class HG.ObjectArray

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_arr) ->
    # todo: only accept array of objects as initial input, otherwise empty
    @_arr = [] unless @_arr

  # ============================================================================
  length: () ->         @_arr.length
  num: () ->            @_arr.length

  push: (obj) ->        @_arr.push obj
  add: (obj) ->         @_arr.push obj
  append: (obj) ->      @_arr.push obj

  pushFront: (obj) ->   @_arr.unshift obj
  addFront: (obj) ->    @_arr.unshift obj
  prepend: (obj) ->     @_arr.unshift obj

  empty: () ->          @_arr = []
  clear: () ->          @_arr = []

  # ============================================================================
  getByPropVal: (prop, val) ->
    res = $.grep @_arr, (r) ->
      r[prop] == val
    if res.length > 0
      return res[0]
    else
      return null

  # ============================================================================
  getById: (val) ->
    @getByPropVal 'id', val

  # ============================================================================
  getByIdx: (id) ->
    @_arr[id]

  # ============================================================================
  # find element whose property has this value and deletes it
  # usage: myObjArr.remove 'id', id
  remove: (prop, val) ->
    # get index of elem in arr
    idx = -1
    i = 0
    len = @_arr.length
    while i < len
      if @_arr[i][prop] == val
        idx = i
        break
      i++
    # remove elem of array by index
    @_arr.splice idx, 1

  delete: (prop, val) ->
    @remove prop, val

  # ============================================================================
  foreach: (cb) ->
    cb el for el in @_arr
    # maaaagic!
    # executes given callback for each element in the array
    # hands element of array callback
    # usage: arr.foreach (elem) => console.log elem
