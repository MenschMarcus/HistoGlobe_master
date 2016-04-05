window.HG ?= {}

# ==============================================================================
# manages the labels on the map, decides which ones are to be shown / hidden
# work with a priority list for labels
# ==============================================================================

class HG.LabelManager

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_map) ->
    @_labelList = new HG.DoublyLinkedList

  # ============================================================================
  insert: (label) ->

    # in case of empty list, put it as first element
    if @_labelList.isEmpty()
      @_labelList.addFront label

    # otherwise find its position in labelList
    else

      # start with first element
      currNode = @_labelList.head.next

      # check until the tail is reached
      while currNode.data   # = currNode isnt @_labelList.tail

        # find the first label with a lower priority
        # => break, because current node is the one we want to add it after
        break if label.priority > currNode.data.priority

        # label priority is smaller than priority of current node
        # => check next node
        currNode = currNode.next

      # insert node into label list
      @_labelList.addBefore label, currNode

    # if @_labelList.length() > 239
    #   console.log "=============================================================="
    #   cn = @_labelList.head.next
    #   i = 0
    #   while cn.data
    #     data =
    #       curr: if cn.data then cn.data._content + "(" + cn.data.priority + ")"
    #       prev: if cn.prev.data then cn.prev.data._content + "(" + cn.prev.data.priority + ")"
    #       next: if cn.next.data then cn.next.data._content + "(" + cn.next.data.priority + ")"
    #     console.log i, ":", data.curr, "| prev:", data.prev, "| next:", data.next
    #     cn = cn.next
    #     i++

    # show label
    @_map.showLabel label
    @_recenter label

  # ============================================================================
  remove: (label) ->

    # hide label
    @_map.removeLayer label

  # ============================================================================
  update: (label) ->


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _recenter: (label) ->
    # put text in center of label
    label.options.offset = [
      -(label._container.offsetWidth/2),
      -(label._container.offsetHeight/2)
    ]
    label._updatePosition()