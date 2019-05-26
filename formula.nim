import macros, tables, strutils, options

import persvector, sequtils, seqmath, stats, strformat

type
  ValueKind* = enum
    VNull,
    VBool,
    VInt,
    VFloat,
    VString,
    VObject

  Value* = object
    case kind*: ValueKind
    of VString:
      str*: string
    of VInt:
      num*: BiggestInt
    of VFloat:
      fnum*: float
    of VBool:
      bval*: bool
    of VObject:
      fields*: OrderedTable[string, Value]
    of VNull:
      discard

  FormulaKind* = enum
    fkTerm, fkVariable, fkFunction, #fkFormula

  ArithmeticKind* = enum
    amPlus = "+"
    amMinus = "-"
    amMul = "*"
    amDiv = "/"
    amDep = "~"
    amEqual = "=="
    amGreater = ">"
    amLess = ">"
    amGeq = ">="
    amLeq = "<="

  FormulaNode* = ref FormulaNodeObj
  FormulaNodeObj = object
    # FormulaNode is either a Term, meaning it has a LHS and RHS
    # or a variable. The operator (function) is given as an enum for
    # the Term connecting the two sides
    case kind*: FormulaKind
    of fkTerm:
      lhs*: FormulaNode
      rhs*: FormulaNode
      op*: ArithmeticKind
    of fkVariable:
      val*: string # TODO: replace by `Value`!
    of fkFunction:
      # storing a function to be applied to the data
      fnName*: string
      fn*: proc(s: PersistentVector[Value]): Value
      arg*: FormulaNode
      res: Option[Value] # the result of fn(arg), so that we can cache it
                         # instead of recalculating it for every index potentially

type
  DataFrame* = object
    len*: int
    data*: OrderedTable[string, PersistentVector[Value]]
    #data: Table[string, seq[Value]]

iterator keys(df: DataFrame): string =
  for k in keys(df.data):
    yield k

iterator keys(row: Value): string =
  doAssert row.kind == VObject
  for k in keys(row.fields):
    yield k

proc `[]`*(df: DataFrame, k: string): PersistentVector[Value] =
#proc `[]`(df: DataFrame, k: string): seq[Value] =
  result = df.data[k]

proc `[]=`*(df: var DataFrame, k: string, vec: PersistentVector[Value]) =
#proc `[]=`(df: var DataFrame, k: string, vec: seq[Value]) =
  df.data[k] = vec
  # doAssert df.len == vec.len

proc `[]`*(v: Value, key: string): Value =
  doAssert v.kind == VObject
  result = v.fields[key]

proc `[]=`*(v: var Value, key: string, val: Value) =
  doAssert v.kind == VObject
  v.fields[key] = val

proc `$`*(v: Value): string =
  ## converts the given value to its value as a string
  case v.kind
  of VInt:
    result = $v.num
  of VFloat:
    result = &"{v.fnum:g}"
  of VBool:
    result = $v.bval
  of VString:
    result = v.str
  of VObject:
    for k, x in v.fields:
      result.add (&"{k} : {x}")
  of VNull:
    result = "null"

proc print*(df: DataFrame, numLines = 20): string =
  ## converts the first `numLines` to a table
  let num = min(df.len, numLines)
  # write header
  result.add align("Idx", 10)
  for k in keys(df):
    result.add &"{k:>10}"
  result.add "\n"
  for i in 0 ..< num:
    result.add &"{i:>10}"
    for k in keys(df):
      result.add &"{df[k][i]:>10}"
    result.add "\n"

func isInt(s: string): bool =
  result = s.isDigit

func isFloat(s: string): bool =
  result = s.replace(".", "").isDigit

func isBool(s: string): bool = false
func parseBool(s: string): bool = false

proc toDf*(t: OrderedTable[string, seq[string]]): DataFrame =
  ## creates a data frame from a table of seq[string]
  result = DataFrame(len: 0)
  for k, v in t:
    var vec = initVector[Value]()
    var data = newSeq[Value]()
    # check first element of v for type
    if v.len > 0:
      #if v[0].isInt:
      #  for x in v:
      #    data.add Value(kind: VInt, num: x.parseInt)
      if v[0].isFloat:
        for x in v:
          data.add Value(kind: VFloat, fnum: x.parseFloat)
      elif v[0].isBool:
        for x in v:
          data.add Value(kind: VBool, bval: x.parseBool)
      else:
        # assume string
        for x in v:
          data.add Value(kind: VString, str: x)
      vec = data.toPersistentVector
    #result.data[k] = data
    result.data[k] = vec
    if result.len == 0:
      result.len = result.data[k].len

proc hasKey(df: DataFrame, key: string): bool =
  result = df.data.hasKey(key)

iterator items(df: DataFrame): Value =
  # returns each row of the dataframe as a Value of kind VObject
  for i in 0 ..< df.len:
    var res = Value(kind: VObject)
    for k in keys(df):
      res[k] = df[k][i]
    yield res

iterator pairs(df: DataFrame): (int, Value) =
  # returns each row of the dataframe as a Value of kind VObject
  for i in 0 ..< df.len:
    var res = Value(kind: VObject)
    for k in keys(df):
      res[k] = df[k][i]
    yield (i, res)

proc toSeq(v: PersistentVector[Value]): seq[Value] =
  result = v[0 ..< v.len]

proc toSeq(df: DataFrame, key: string): seq[Value] =
  result = df[key].toSeq

proc toFloat*(s: string): float =
  # TODO: replace by `toFloat(v: Value)`!
  result = s.parseFloat

proc toFloat*(v: Value): float =
  doAssert v.kind in {VInt, VFloat}
  case v.kind
  of VInt: result = v.num.float
  of VFloat: result = v.fnum
  else: discard

proc isValidVal(v: Value, f: FormulaNode): bool =
  doAssert v.kind != VObject
  doAssert f.kind == fkTerm
  doAssert f.op in {amEqual, amGreater, amLess, amGeq, amLeq}
  case v.kind
  of VInt, VFloat:
    case f.op
    of amEqual:
      result = v.toFloat == f.rhs.val.toFloat
    of amGreater:
      result = v.toFloat > f.rhs.val.toFloat
    of amLess:
      result = v.toFloat < f.rhs.val.toFloat
    of amGeq:
      result = v.toFloat >= f.rhs.val.toFloat
    of amLeq:
      result = v.toFloat <= f.rhs.val.toFloat
    else:
      raise newException(Exception, "comparison of kind " & $f.op & " does " &
        "not make sense for value kind of " & $v.kind & "!")
  of VString:
    doAssert not f.rhs.val.isDigit, "comparison must be with another string!"
    case f.op
    of amEqual:
      result = v.str == f.rhs.val
    of amGreater:
      result = v.str > f.rhs.val
    of amLess:
      result = v.str < f.rhs.val
    else:
      raise newException(Exception, "comparison of kind " & $f.op & " does " &
        "not make sense for value kind of " & $v.kind & "!")
  else:
    raise newException(Exception, "comparison for kind " & $v.kind &
      " not yet implemented!")

proc isValidRow(v: Value, f: FormulaNode): bool =
  doAssert v.kind == VObject
  doAssert f.kind == fkTerm
  doAssert f.op in {amEqual, amGreater, amLess, amGeq, amLeq}
  let lhsKey = f.lhs.val
  result = v[lhsKey].isValidVal(f)

proc delete(df: DataFrame, rowIdx: int): DataFrame =
  result = df
  for k in keys(df):
    var s = df[k][0 ..< df.len]
    s.delete(rowIdx)
    #result[k] = s
    result[k] = toPersistentVector(s)
  result.len = result.len - 1

proc add(df: var DataFrame, row: Value) =
  for k in keys(row):
    #var s = df[k]
    #s.add row[k]
    #df[k] = s
    if not df.hasKey(k):
      df[k] = initVector[Value]()
    df[k] = df[k].add row[k]
    doAssert df.len + 1 == df[k].len
  df.len = df.len + 1

func buildCondition(conds: varargs[FormulaNode]): FormulaNode =
  if conds.len == 1:
    let c = conds[0]
    doAssert c.kind == fkTerm
    doAssert c.op in {amEqual, amGreater, amLess, amGeq, amLeq}
    result = c
  else: discard

template checkCondition(c: FormulaNode): untyped =
  doAssert c.kind == fkTerm
  doAssert c.op in {amEqual, amGreater, amLess, amGeq, amLeq}

func buildCondProc(conds: varargs[FormulaNode]): proc(v: Value): bool =
  # returns a proc which contains the condition given by the Formulas
  result = (
    proc(v: Value): bool =
      result = false
      for c in conds:
        if not v.isValidVal(c):
          result = false
          break
  )

func getFilteredIdx(df: DataFrame, cond: FormulaNode): seq[int] =
  ## return indices allowed after filter
  let key = cond.lhs.val
  let pv = df[key]
  result = toSeq(0 ..< df.len).filterIt(pv[it].isValidVal(cond))

func getFilteredIdx(idx: seq[int], df: DataFrame, cond: FormulaNode): seq[int] =
  ## return indices allowed after filter, starting from a given sequence
  ## of allowed indices
  let key = cond.lhs.val
  let pv = df[key]
  result = idx.filterIt(pv[it].isValidVal(cond))

#func getFilteredIdx(df: DataFrame, isValid: proc(v: Value): bool): seq[int] =
#  ## return indices allowed after filter
#  let key = cond.lhs.val
#  let pv = df[key]
#  result = toSeq(0 ..< df.len).filterIt(isValid(pv[it]))

func filter(p: PersistentVector[Value], idx: seq[int]): PersistentVector[Value] =
  result = toPersistentVector(idx.mapIt(p[it]))

#func filter(p: seq[Value], idx: seq[int]): seq[Value] =
#  result = idx.mapIt(p[it])

proc filter*(df: DataFrame, conds: varargs[FormulaNode]): DataFrame =
  ## returns the data frame filtered by the conditions given
  var fullCondition: FormulaNode
  var filterIdx: seq[int]
  for c in conds:
    checkCondition(c)
    if filterIdx.len > 0:
      filterIdx = filterIdx.getFilteredIdx(df, c)
    else:
      filterIdx = getFilteredIdx(df, c)
  #let condProc = buildCondProc(conds)

  #let filterIdx = getFilteredIdx(df, fullCondition)
  #let filterIdx = getFilteredIdx(df, condProc)
  for k in keys(df):
    result[k] = initVector[Value]()
    result[k] = df[k].filter(filterIdx)
  result.len = filterIdx.len

template liftScalarFloatProc(name: untyped): untyped =
  proc `name`*(v: PersistentVector[Value]): Value =
    result = Value(kind: VFloat, fnum: `name`(v[0 ..< v.len].mapIt(it.toFloat)))

template liftScalarIntProc(name: untyped): untyped =
  proc `name`*(v: PersistentVector[Value]): Value =
    result = Value(kind: VInt, num: `name`(v[0 ..< v.len].mapIt(it.toInt)))

template liftScalarStringProc(name: untyped): untyped =
  proc `name`*(v: PersistentVector[Value]): Value =
    result = Value(kind: VString, str: `name`(v[0 ..< v.len].mapIt(it.toInt)))

liftScalarFloatProc(mean)

template liftVectorProcToPersVec(name: untyped, outType: untyped): untyped =
  proc `name`*(v: PersistentVector[Value]): `outType` =
    result = v[0 ..< v.len].mapIt(`name`(it.toFloat))

liftVectorProcToPersVec(ln, seq[float])

#template liftProcToString(name: untyped, outType: untyped): untyped =
#  proc `name`(df: DataFrame, x: string): `outType` =
#    result = `name`(df[x])
#
#liftProcToString(mean, float)

proc serialize*[T](node: var FormulaNode, data: T, idx: int): float
proc constructVariable*(n: NimNode): NimNode
proc constructFunction*(n: NimNode): NimNode
proc buildFormula(n: NimNode): NimNode
proc handleSide(n: NimNode): NimNode =
  case n.kind
  of nnkInfix:
    result = buildFormula(n)
  of nnkStrLit:
    result = constructVariable(n)
  of nnkCall:
    result = constructFunction(n)
  else:
    raise newException(Exception, "Not implemented!")

proc buildFormula(n: NimNode): NimNode =
  expectKind(n, nnkInfix)
  let opid = n[0].strVal
  let op = quote do:
    parseEnum[ArithmeticKind](`opid`)
  let lhs = handleSide(n[1])
  let rhs = handleSide(n[2])
  result = quote do:
    FormulaNode(kind: fkTerm, lhs: `lhs`, rhs: `rhs`, op: `op`)

macro `{}`*(x, y: untyped): untyped =
  if x.repr == "f":
    result = buildFormula(y)

proc `$`*(node: FormulaNode): string

proc calcNewColumn(df: DataFrame, fn: FormulaNode): (string, PersistentVector[Value]) =
  ## calculates a new column based on the `fn` given
  doAssert fn.lhs.kind == fkVariable
  let colName = fn.lhs.val
  # mutable copy so that we can cache the result of `fn(arg)` if such a
  # function call is involved
  var mfn = fn
  var newCol = newSeq[Value](df.len)
  for i in 0 ..< df.len:
    newCol[i] = Value(kind: VFloat, fnum: mfn.rhs.serialize(df, i))
  result = (colName, toPersistentVector(newCol))

proc mutate*(df: DataFrame, fns: varargs[FormulaNode]): DataFrame =
  ## Returns the data frame with an additional mutated column, described
  ## by the functions `fns`.
  ## Each formula `fn` given will be used to create a new column in the
  ## dataframe.
  ## We assume that the LHS of the formula corresponds to a fkVariable
  ## that's used to designate the new name.
  result = df
  for fn in fns:
    if fn.kind == fkVariable:
      result[fn.val] = df[fn.val]
    else:
      let (colName, newCol) = result.calcNewColumn(fn)
      result[colName] = newCol

proc transmute*(df: DataFrame, fns: varargs[FormulaNode]): DataFrame =
  ## Returns the data frame cut to the columns created by `fns`, which
  ## should involve a calculation. To only cut to one or more columns
  ## use the `select` proc.
  ## A function may only contain a `fkVariable` in order to keep the
  ## column without modification.
  ## We assume that the LHS of the formula corresponds to a fkVariable
  ## that's used to designate the new name.
  # since result dataframe is empty, copy len of input
  result.len = df.len
  for fn in fns:
    if fn.kind == fkVariable:
      result[fn.val] = df[fn.val]
    else:
      let (colName, newCol) = df.calcNewColumn(fn)
      result[colName] = newCol

proc select*[T: string | FormulaNode](df: DataFrame, cols: varargs[T]): DataFrame =
  ## Returns the data frame cut to the names given as `cols`. The argument
  ## may either be the name of a column as a string, or a `FormulaNode` describing
  ## either a selection with a name applied in form of an "equation" (c/f mpg dataset):
  ## mySelection ~ hwy
  ## or just an `fkVariable` stating the name of the column. Using the former approach
  ## it's possible to select and rename a column at the same time.
  ## Note that the columns will be ordered from left to right given by the order
  ## of the `cols` argument!
  result.len = df.len
  for fn in cols:
    when type(T) is string:
      result[fn] = df[fn]
    else:
      if fn.kind == fkVariable:
        result[fn.val] = df[fn.val]
      else:
        doAssert fn.rhs.kind == fkVariable, "if you wish to perform a calculation " &
          "of one or more columns, please use `transmute` or `mutate`!"
        result[fn.lhs.val] = df[fn.rhs.val]
        #let (colName, newCol) = df.calcNewColumn(fn)
        #result[colName] = newCol

proc rename*(df: DataFrame, cols: varargs[FormulaNode]): DataFrame =
  ## Returns the data frame with the columns described by `cols` renamed to
  ## the names on the LHS of the given `FormulaNode`. All other columns will
  ## be left untouched.
  ## Note that the renamed columns will be stacked on the right side of the
  ## data frame!
  ## NOTE: The operator between the LHS and RHS of the formulas does not
  ## have to be `~`, but for clarity it should be.
  result = df
  for fn in cols:
    doAssert fn.kind == fkTerm, "The formula must be term!"
    doAssert fn.rhs.kind == fkVariable, "the RHS of the formula must be a name " &
      "given as a `fkVariable`!"
    result[fn.lhs.val] = df[fn.rhs.val]
    # remove the column of the old name
    result.data.del(fn.rhs.val)


################################################################################
####### FORMULA
################################################################################

proc isSingle(x, y: NimNode, op: ArithmeticKind): NimNode
proc expand(n: NimNode): NimNode =
  case n.kind
  of nnkObjConstr:
    result = n
  of nnkInfix:
    let
      kind = parseEnum[ArithmeticKind](n[0].strVal)
      n1 = n[1]
      n2 = n[2]
    result = isSingle(n1, n2, kind)
  of nnkPar:
    let
      kind = parseEnum[ArithmeticKind](n[0][0].strVal)
      n1 = n[0][1]
      n2 = n[0][2]
    result = isSingle(n1, n2, kind)
  of nnkPrefix:
    let
      kind = parseEnum[ArithmeticKind](n[0].strVal)
      n1 = n[1]
    result = isSingle(nil, n1, kind)
  else:
    error("Unsupported kind " & $n.kind)

proc constructVariable*(n: NimNode): NimNode =
  var val = ""
  if n.kind != nnkNilLit:
    val = n.strVal
  else:
    # empty value meaning no comparison. Only allowed for something like
    # ~ x
    val = ""
  result = quote do:
    FormulaNode(kind: fkVariable, val: `val`)

proc constructFunction*(n: NimNode): NimNode =
  let fname = n[0].strVal
  let fn = n[0]
  let arg = constructVariable(n[1])
  result = quote do:
    FormulaNode(kind: fkFunction, fnName: `fname`, fn: `fn`, arg: `arg`)

proc isSingle(x, y: NimNode, op: ArithmeticKind): NimNode =
  var
    lhs: NimNode
    rhs: NimNode
  if x.len == 0:
    # is single
    lhs = constructVariable(x)
  else:
    lhs = expand(x)
  if y.len == 0:
    # is single
    rhs = constructVariable(y)
  else:
    rhs = expand(y)

  if x.kind == nnkNilLit and y.kind == nnkNilLit:
    error("Not both values can be nil at the same time!")
  elif y.kind == nnkNilLit:
    # assign nil lit always to `lhs`
    var tmp = lhs
    lhs = rhs
    rhs = tmp
  elif x.kind == nnkNilLit:
    doAssert rhs[2][1].strVal.len > 0, "Nil value cannot be at RHS!"

  let lit = newLit op
  result = quote do:
    FormulaNode(kind: fkTerm, lhs: `lhs`, rhs: `rhs`, op: `lit`)

proc findTilde(n: NimNode): NimNode =
  ## searches for the ~ node in the LHS branch of the given node
  ## returns a tuple of:
  ## - ~ node
  ## - whole tree with ~ node replaced by ~.rhs
  ## No, do it recursively on ``mutable (!)`` node, replace the ~ node
  ## with the RHS value of it and have result be copy of old ~ node
  expectKind(n, nnkObjConstr)
  for ch in n:
    case ch.kind
    of nnkSym:
      discard
    of nnkExprColonExpr:
      if ch[0].strVal == "lhs":
        # Index 3
        result = findTilde(ch[1])
      elif ch[0].strVal == "op":
        # found operator, check if `~`
        if (ch[1].kind == nnkCall or ch[1].kind == nnkConv) and ch[1][1] == newLit 4: # 4 == amDep
          result = copyNimTree(n)
      else:
        discard # RHS can be ignored
    else:
      error("Unsupported tree kind: " & $ch.kind)

proc replaceTilde(n: NimNode, tilde: NimNode): NimNode =
  ## searches for the ~ node in the LHS branch of the given node
  ## returns a tuple of:
  ## - ~ node
  ## - whole tree with ~ node replaced by ~.rhs
  ## No, do it recursively on ``mutable (!)`` node, replace the ~ node
  ## with the RHS value of it and have result be copy of old ~ node
  expectKind(n, nnkObjConstr)
  result = copyNimTree(n)
  for ch in n:
    case ch.kind
    of nnkSym:
      discard
    of nnkExprColonExpr:
      if ch[0].strVal == "lhs":
        # Index 2
        let res = replaceTilde(ch[1], tilde)
        case res.kind
        of nnkExprColonExpr:
          # replace the whole LHS part of the constructor (replaceTilde *did* do
          # something)
          result[2] = res
        of nnkObjConstr:
          # only replace the LHS Obj constructor part. (replaceTilde *did not* do
          # anything on the last call. *However* it may have done something one or
          # more levels deeper, so we *have* to copy it!
          result[2][1] = res
        else:
          error("Unsupported kind to copy " & $ch.kind)

      elif ch[0].strVal == "op":
        # found operator, check if `~`
        if (ch[1].kind == nnkCall or ch[1].kind == nnkConv) and ch[1][1] == newLit 4: # 4 == amDep
          # copy the tree again and assign tilde to RHS branch
          # Have to copy again, because above might have changed `result` in an
          # undesirable way!
          # -> if we *are* in the `~` branch, we do *NOT* care about the result of call to
          # replaceTilde, since that would reproduce the LHS part of it we're trying to get
          # rid of!
          result = copyNimTree(n)
          result = tilde[3]
          return result
        else:
          # repair the "RHS" ident in result. Due to a previous call in `deconstruct`, the
          # LHS field may still have a `RHS` attached to it. Fix that.
          result[2][0] = ident"lhs"
      else:
        discard # RHS can be ignored
    else:
      error("Unsupported tree kind: " & $ch.kind)

macro deconstruct(x, y: untyped, op: static ArithmeticKind): untyped =
  result = isSingle(x, y, op)
  let tilde = findTilde(result)
  if tilde.kind != nnkNilLit:
    let replaced = replaceTilde(result, tilde)
    let tildeLeft = tilde[2][1]
    var newRight: NimNode
    case replaced.kind
    of nnkObjConstr:
      newRight = replaced
    of nnkExprColonExpr:
      newRight = replaced[1]
    else: error("Unsupported " & $replaced.kind)
    let op = nnkCall.newTree(ident"ArithmeticKind", newLit 4)
    result = quote do:
      FormulaNode(kind: fkTerm, lhs: `tildeLeft`, rhs: `newRight`, op: `op`)

template `~`*(x: untyped): FormulaNode =
  deconstruct(x, nil, amDep)

template `~`*(x, y: untyped): FormulaNode =
  deconstruct(x, y, amDep)

template `+`*(x, y: untyped): FormulaNode =
  deconstruct(x, y, amPlus)

template `-`*(x, y: untyped): FormulaNode =
  deconstruct(x, y, amMinus)

template `*`*(x, y: untyped): FormulaNode =
  deconstruct(x, y, amMinus)

template `/`*(x, y: untyped): FormulaNode =
  deconstruct(x, y, amDiv)

proc initVariable(x: string): FormulaNode =
  result = FormulaNode(kind: fkVariable,
                       val: x)

template makeMathProc(operator, opKind: untyped): untyped =
  proc `operator`*(x, y: string): FormulaNode =
    let
      lhs = initVariable(x)
      rhs = initVariable(y)
    result = FormulaNode(kind: fkTerm, lhs: lhs, rhs: rhs,
                         op: opKind)
  proc `operator`*(lhs: FormulaNode, y: string): FormulaNode =
    let rhs = initVariable(y)
    result = FormulaNode(kind: fkTerm, lhs: lhs, rhs: rhs,
                         op: opKind)
  proc `operator`*(x: string, rhs: FormulaNode): FormulaNode =
    let lhs = initVariable(x)
    result = FormulaNode(kind: fkTerm, lhs: lhs, rhs: rhs,
                         op: opKind)

# there are no overloads using `:` syntax for +, -, *, / since
# then the operator precedence would be overwritten!
# For comparison operators this does not matter.
#makeMathProc(`+`, amPlus)
#makeMathProc(`-`, amMinus)
#makeMathProc(`*`, amMul)
#makeMathProc(`/`, amDiv)
#makeMathProc(`~`, amDep)
makeMathProc(`:~`, amDep)
makeMathProc(`:=`, amEqual)
makeMathProc(equal, amEqual)
makeMathProc(`:>`, amGreater)
makeMathProc(greater, amGreater)
makeMathProc(`:<`, amLess)
makeMathProc(less, amLess)
makeMathProc(`:>=`, amGeq)
makeMathProc(geq, amGeq)
makeMathProc(`:<=`, amLeq)
makeMathProc(leq, amLeq)

proc toUgly*(result: var string, node: FormulaNode) =
  var comma = false
  case node.kind:
  of fkTerm:
    result.add "(" & $node.op & " "
    result.toUgly node.lhs
    result.add " "
    result.toUgly node.rhs
    result.add ")"
  of fkVariable:
    result.add node.val
  of fkFunction:
    result.add "("
    result.add node.fnName
    result.add " "
    result.toUgly node.arg
    result.add ")"

proc `$`*(node: FormulaNode): string =
  ## Converts `node` to its string representation
  result = newStringOfCap(1024)
  toUgly(result, node)

import typetraits
proc serialize*[T](node: var FormulaNode, data: T, idx: int): float =
  case node.kind
  of fkVariable:
    when type(data) is DataFrame:
      result = data[node.val][idx].toFloat
    elif type(data) is Table[string, seq[string]]:
      result = data[node.val][idx].parseFloat
    else:
      error("Unsupported type " & $type(data) & " for serialization!")
  of fkTerm:
    case node.op
    of amPlus:
      result = node.lhs.serialize(data, idx) + node.rhs.serialize(data, idx)
    of amMinus:
      result = node.lhs.serialize(data, idx) - node.rhs.serialize(data, idx)
    of amMul:
      result = node.lhs.serialize(data, idx) * node.rhs.serialize(data, idx)
    of amDiv:
      result = node.lhs.serialize(data, idx) / node.rhs.serialize(data, idx)
    of amDep:
      raise newException(Exception, "Cannot serialize a term still containing a dependency!")
    else:
      raise newException(Exception, "Cannot serialize a term of kind " & $node.op & "!")
  of fkFunction:
    # for now assert that the argument to the function is just a string
    # Extend this if support for statements like `mean("x" + "y")` (whatever
    # that is even supposed to mean) is to be added.
    doAssert node.arg.kind == fkVariable
    # we also convert to float for the time being. Implement a different proc or make this
    # generic, we want to support functions returning e.g. `string` (maybe to change the
    # field name at runtime via some magic proc)
    #echo "Accessing ", data[node.arg.val]
    when type(data) is DataFrame:
      if node.res.isSome:
        result = node.res.unsafeGet.toFloat
      else:
        result = node.fn(data[node.arg.val]).toFloat
        node.res = some(Value(kind: VFloat, fnum: result))
    else:
      raise newException(Exception, "Cannot serialize a fkFunction for a data " &
        " frame of this type: " & $(type(data).name) & "!")
