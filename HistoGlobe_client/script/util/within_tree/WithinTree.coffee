window.HG ?= {}

# ============================================================================
# tree for hierarchical structure of holes in polygons
# input: single nodes containing closed Polylines

class HG.WithinTree

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->
    @_nodes = []

    @_geometryOperator = new HG.GeometryOperator

    # inititally create ROOT node
    @_root = new HG.WithinTreeNode 'ROOT'
    @_nodes.push @_root

  # ============================================================================
  insert: (N, P=@_root) ->
  # N = node to be inserted in the tree
  # P = parent node / root node of the subtree it is inserted into
  # initially all polygons are within ROOT node
  # => first function call for all polygons: insert(N, @_root)

    ## PREPARATION
    # check for each child C of the parent node P if they have any
    # hierarchical relation to the inserted node N
    # there are 3 cases:
    # 1) N also in 1 child of P -> withinChild
    # 2) 1+ children of P in N -> containChildren
    # 3) no hierarchical relation between N and any child of P
    withinChild = null
    containChildren = []
    for child in P.getChildren()
      C = @_getNode child

      # check for case 1)
      if @_isWithin N, C
        withinChild = C
        # if N is in 1 child of P it can not have any
        # hierarchical relation to any other child of P
        break

      # check for case 2)
      else if @_isWithin C, N
        containChildren.push C

    ## EXECUTION
    # case 1) N in 1 child of P
    # => insert N into this child node -> recursion :)
    if withinChild
      @insert N, C

    # for both cases 2 and 3) N is not in any child of P
    # => place N underneath P
    else
      @_nodes.push N
      N.setParent P.getId()
      P.addChild N.getId()

      # case 2) 1+ children of P in N
      # => re-place all these as children of N and detach from P
      for CC in containChildren
        CC.setParent N.getId()
        N.addChild CC.getId()
        P.removeChild CC.getId()

      # case 3) no hierarchical relation between N and any child of P
      # => no additional re-placement of nodes
      # => do not do anything


  # ============================================================================
  extract: () ->
  # initial condition: all nodes are in the hierarchical tree
  # extract always the first child (FC) of the root node -> will be outer ring
  # its children (Ci) -> will be inner ring(s) / hole(s)
  # => polygon = [FC, C1, C2, ... , Ci, ... , Cn]

    # extract first child and all its children
    firstChild = @_root.getChildren()[0]
    FC = @_getNode firstChild

    Ci = []
    for C in FC.getChildren()
      Ci.push(@_getNode C)

    # reset relations and remove extracted nodes
    @_root.removeChild FC.getId()
    @_removeNode FC
    for C in Ci
      # children of children of first child become new children of root
      for Cchild in C.getChildren()
        CC = @_getNode Cchild
        CC.setParent @_root.getId()
        @_root.addChild CC.getId()
      @_removeNode C

    # prepare output
    polygon = [FC.getPolyline()]
    for C in Ci
      polygon.push C.getPolyline()

    polygon


  # ============================================================================
  isEmpty: () ->  @_root.getChildren().length is 0


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _isWithin: (nodeA, nodeB) ->
    A = nodeA.getPolyline()
    B = nodeB.getPolyline()
    @_geometryOperator.isWithin A, B

  # ============================================================================
  _getNode: (id) ->
    result = $.grep @_nodes, (e) -> e.getId() is id
    result[0] # can do it because each id is unique

  # ----------------------------------------------------------------------------
  _removeNode: (node) ->
    @_nodes.splice((@_nodes.indexOf(node)), 1)
