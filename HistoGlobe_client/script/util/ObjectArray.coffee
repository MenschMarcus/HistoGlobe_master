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

    @_ids = []  # contains all ids of objects in the array to ensure they are unique
    @_ids.push o.id for o in @_arr

  # ============================================================================
  length: () ->         @_arr.length
  num: () ->            @_arr.length

  # ============================================================================
  push: (obj) ->
    if @_check obj
      @_ids.push obj.id
      @_arr.push obj

  add: (obj) ->         @push obj
  append: (obj) ->      @push obj

  # ============================================================================
  pushFront: (obj) ->
    if @_check obj
      @_ids.unshift obj.id
      @_arr.unshift obj

  addFront: (obj) ->    @pushFront obj
  prepend: (obj) ->     @pushFront obj

  # ============================================================================
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
  getById: (val) ->     @getByPropVal 'id', val
  getByIdx: (id) ->     @_arr[id]

  # ============================================================================
  # find element whose property has this value and deletes it
  # usage: myObjArr.remove 'name', name
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
  # delete element by its id
  # usage: myObjArr.removeById, id
  removeById: (val) ->  @remove 'id', val
  deleteById: (val) ->  @remove 'id', val

  # ============================================================================
  # usage: arr.foreach (elem) => console.log elem
  foreach: (cb) ->
    cb el for el in @_arr
    # maaaagic!
    # executes given callback for each element in the array
    # hands element of array callback


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # error handling: is id unique? returns yes / no
  _check: (o) ->
    if $.inArray o.id, @_ids is -1
      true
    else
      console.error "id " + o.id + " is already given!"
      false