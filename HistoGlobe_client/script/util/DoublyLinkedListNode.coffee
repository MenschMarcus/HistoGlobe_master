window.HG ?= {}

class HG.DoublyLinkedListNode


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (
    @data,
    @next=null,   # pointer to next neighbor
    @prev=null    # pointer to prev neighbor
  ) ->