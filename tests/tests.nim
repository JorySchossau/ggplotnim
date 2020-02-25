import unittest
# we include ggplotnim so that we can test non exported procs
include ../src/ggplotnim

import tables, sets, options
import sequtils, seqmath
import math

suite "Value":
  let
    v1 = %~ 1
    v2 = %~ 1.5
    v3 = %~ true
    v4 = %~ 'a'
    # `v5` itself is already a test, whether we can hash `Value`
    v5 = %~ { "test" : v1,
              "some" : v2,
              "heterogeneous" : v3,
              "fields" : v4 }.toOrderedTable
    v6 = Value(kind: VNull)

  test "Storing in sets":
    var valueSet = initHashSet[Value]()
    valueSet.incl v1
    valueSet.incl v2
    valueSet.incl v3
    valueSet.incl v4
    valueSet.incl v5
    valueSet.incl v6
    check v1 in valueSet
    check v2 in valueSet
    check v3 in valueSet
    check v4 in valueSet
    check v5 in valueSet
    check v6 in valueSet
    check valueSet.card == 6

  test "Storing in tables":
    var tab = initTable[string, Value]()
    tab["v1"] = v1
    tab["v2"] = v2
    tab["v3"] = v3
    tab["v4"] = v4 # is converted to string!
    tab["v5"] = v5
    tab["v6"] = v6
    check tab.len == 6
    check tab["v1"] == v1
    check tab["v2"] == v2
    check tab["v3"] == v3
    check tab["v4"] == v4
    check tab["v5"] == v5
    check tab["v6"] == v6

  test "Extracting values":
    check v1.toInt == 1
    check v2.toFloat == 1.5
    check v3.toBool == true
    check v4.toStr == "a"
    check v1.toStr == "1"
    check v2.toStr == "1.5"
    check v3.toStr == "true"
    expect(ValueError):
      discard v5.toStr
    expect(ValueError):
      discard v6.toStr

  test "Direct `isNumber` check":
    # Note: this test checks basically whether the content of a `Value`
    # to be echoed is recognized as a number (in which case it's engulfed
    # by literal ``"``) or a normal string (no ``"``)
    let n1 = "1.1"
    let n2 = "1.3e5"
    let n3 = "aba"
    let n4 = "1..1"
    let n5 = "1.123"
    let n6 = "1.5e5E5"
    let n7 = "e"
    let n8 = "E"
    let n9 = "."
    let n10 = "1e"
    let n11 = "1E"
    let n12 = "1."
    let n13 = "e1"
    let n14 = "E1"
    let n15 = ".1"
    # and some actually valid floats
    let n16 = "6.084E+01"
    let n17 = "1.676E+01"
    let n18 = "6.863E+00"
    let n19 = "2.007E+00"
    let n20 = "9.329E-01"
    let n21 = "2.441E-04"
    let n22 = "-2.441E-04"
    let n23 = "--2.441"
    let n24 = "-6.836E-04 "
    let n25 = "2.930E-04    "
    let n26 = "2.930E-04  d   "
    check n1.isNumber
    check n2.isNumber
    check not n3.isNumber
    check not n4.isNumber
    check n5.isNumber
    check not n6.isNumber
    check not n7.isNumber
    check not n8.isNumber
    check not n9.isNumber
    check not n10.isNumber
    check not n11.isNumber
    check n12.isNumber
    check not n13.isNumber
    check not n14.isNumber
    check not n15.isNumber
    check n16.isNumber
    check n17.isNumber
    check n18.isNumber
    check n19.isNumber
    check n20.isNumber
    check n21.isNumber
    check n22.isNumber
    check not n23.isNumber
    check n24.isNumber
    check n25.isNumber
    check not n26.isNumber

  test "String conversion":
    # Note: this test checks basically whether the content of a `Value`
    # to be echoed is recognized as a number (in which case it's engulfed
    # by literal ``"``) or a normal string (no ``"``)
    # This uses `isNumber` internally.
    let n1 = %~ "1.1"
    let n2 = %~ "1.3e5"
    let n3 = %~ "aba"
    let n4 = %~ "1..1"
    let n5 = %~ "1.123"
    let n6 = %~ "1.5e5E5"
    let n7 = %~ "e"
    let n8 = %~ "E"
    let n9 = %~ "."
    let n10 = %~ "1e"
    let n11 = %~ "1E"
    let n12 = %~ "1."
    let n13 = %~ "e1"
    let n14 = %~ "E1"
    let n15 = %~ ".1"
    # and some actually valid floats
    let n16 = %~ "6.084E+01"
    let n17 = %~ "1.676E+01"
    let n18 = %~ "6.863E+00"
    let n19 = %~ "2.007E+00"
    let n20 = %~ "9.329E-01"
    let n21 = %~ "2.441E-04"
    let n22 = %~ "-2.441E-04"
    check $n1 == "\"1.1\""
    check $n2 == "\"1.3e5\""
    check $n3 == "aba"
    check $n4 == "1..1"
    check $n5 == "\"1.123\""
    check $n6 == "1.5e5E5"
    check $n7 == "e"
    check $n8 == "E"
    check $n9 == "."
    check $n10 == "1e"
    check $n11 == "1E"
    check $n12 == "\"1.\""
    check $n13 == "e1"
    check $n14 == "E1"
    check $n15 == ".1"
    check $n16 == "\"6.084E+01\""
    check $n17 == "\"1.676E+01\""
    check $n18 == "\"6.863E+00\""
    check $n19 == "\"2.007E+00\""
    check $n20 == "\"9.329E-01\""
    check $n21 == "\"2.441E-04\""
    check $n22 == "\"-2.441E-04\""

    # check that `emphStrNumber` can be disabled
    echo n16.pretty(emphStrNumber = false).repr
    echo n16.str.repr
    check n16.pretty(emphStrNumber = false) == "6.084E+01"
    check n17.pretty(emphStrNumber = false) == "1.676E+01"
    check n18.pretty(emphStrNumber = false) == "6.863E+00"
    check n19.pretty(emphStrNumber = false) == "2.007E+00"
    check n20.pretty(emphStrNumber = false) == "9.329E-01"
    check n21.pretty(emphStrNumber = false) == "2.441E-04"
    check n22.pretty(emphStrNumber = false) == "-2.441E-04"


  test "Math with Values":
    check (v1 * v2).kind == VFloat
    check (v1 + v1).kind == VFloat
    check (v1 + v1) == %~ 2
    check (v1 * v1).kind == VFloat
    check almostEqual((v1 * v2).toFloat, 1.5)
    check almostEqual((v1 / v2).toFloat, 2.0 / 3.0)
    check v1 * v6 == Value(kind: VNull)

suite "Formula":
  test "Testing ~ formula creation":
    let f = x ~ y
    let a = x ~ (a - b)
    let g = n ~ m + a * b * d
    let g2 = n ~ m + a - b + d
    let g3 = n ~ m + a * b / d
    let single = ~ x
    let gg1 = hwy ~ (displ + cyl - cty)
    let gg2 = hwy ~ displ + cyl - cty

    check $f == "(~ x y)"
    check $a == "(~ x (- a b))"
    check $g == "(~ n (+ m (* (* a b) d)))"
    check $g2 == "(~ n (+ (- (+ m a) b) d))"
    check $g3 == "(~ n (+ m (/ (* a b) d)))"
    check $single == "(~ \"\" x)" # LHS is empty string value
    check $gg1 == "(~ hwy (- (+ displ cyl) cty))"
    check $gg2 == "(~ hwy (- (+ displ cyl) cty))"

  test "Testing ~ formula creation using f{} macro":
    let f = f{"meanCty" ~ ("hwy" + "cty")}
    let g = meanCty ~ hwy + cty
    check $f == $g
    # TODO: Add more tests here...
    # create with `.` access
    let tup = (a: 5.5, b: "ok")
    let h = f{tup.a == tup.b}
    check $h == "(== 5.5 ok)"

    let f2 = f{"min" ~ min("runTimes")}
    check $f2 == "(~ min (min runTimes))"

    let s = Scale(col: "testCol",
                  scKind: scTransformedData,
                  dcKind: dcContinuous,
                  trans: (proc(v: Value): Value =
                            result = v * (%~ 2.0)
                  )
    )
    var f3 = f{ s.col ~ s.trans( s.col )}
    check $f3 == "(~ testCol (s.trans testCol))"
    # test function on DF
    let df = seqsToDf( { "testCol" : @[1.0, 2.0, 3.0] })
    check toSeq(0 .. 2).mapIt(f3.rhs.evaluate(df, it)) == %~ @[2.0, 4.0, 6.0]

  test "Evaluate ~ formula":
    let mpg = readCsv("data/mpg.csv")
    let f = hwy ~ (displ + cyl - cty) # this doesn't make sense, but anyways...
    # Displacement + Cylinders - City mpg. Yeah :D
    # use RHS of formula for calculation of 0 row.
    check f.rhs.evaluate(mpg, 0) == %~ -12.2

  test "Formula, literal on RHS":
    let f = f{"from" ~ 0}
    check $f == "(~ from 0)"

  test "Test formula creation of type `fkVariable`":
    let f1 = f{"Test"}
    let f2 = f{1.1}
    let f3 = f{4}
    let f4 = f{true}
    check f1.kind == fkVariable
    check f2.kind == fkVariable
    check f3.kind == fkVariable
    check f4.kind == fkVariable
    check $f1 == "Test"
    check $f2 == "1.1"
    check $f3 == "4"
    check $f4 == "true"

suite "Geom":
  test "application of aes, style works":
    # Write test which tests that the application of things like an
    # aesthetic and a style, e.g. color, line size etc, is properly
    # applied for all geoms!
    # Take a look at the style check in the first GgPlot test
    discard

suite "GgPlot":
  test "Histogram with discrete scale fails":
    let mpg = toDf(readCsv("data/mpg.csv"))
    expect(ValueError):
      ggplot(mpg, aes("class")) + geom_histogram() + ggsave("fails.pdf")

  test "Bar with continuous scale fails":
    let mpg = toDf(readCsv("data/mpg.csv"))
    expect(ValueError):
      ggplot(mpg, aes("cty")) + geom_bar() + ggsave("fails.pdf")

  test "Bar plot with string based scale":
    let mpg = toDf(readCsv("data/mpg.csv"))
    let plt = ggcreate(ggplot(mpg, aes("class")) + geom_bar())
    let plotview = plt.view[4]
    check plotview.name == "plot"
    proc calcPos(classes: seq[string]): seq[float] =
      ## given the possible classes, calculates the positions the
      ## labels have to be placed at
      ## NOTE: this is the same calculation happening in the `handleDisreteTicks`
      ## proc. Thus the test here is based on the assumption that this calc over
      ## there is correct. However, it's been checked by eye at the time of this
      ## commit (b1a3a155587d4ee54e6581ac99f3a428eea37c1f) that it produces the
      ## desired result.
      let discrMargin = quant(0.2, ukCentimeter).toRelative(
        length = some(plotview.wView)
      ).val
      let nclass = classes.len
      let barViewWidth = (1.0 - 2 * discrMargin) / nclass.float
      let centerPos = barViewWidth / 2.0
      for i in 0 ..< nclass:
        let pos = discrMargin + i.float * barViewWidth + centerPos
        result.add pos
    let classes = mpg["class"].unique.mapIt(it.toStr).sorted
    let checkPos = calcPos(classes)
    var
      idxTk = 0
      idxLab = 0
    for obj in plotview.objects:
      case obj.kind
      of goTick:
        # verify tick position
        if obj.tkAxis == akX:
          check obj.tkPos.x.pos == checkPos[idxTk]
          inc idxTk
      of goTickLabel:
        # verify position and text
        if obj.name == "xtickLabel":
          check obj.txtText == classes[idxLab]
          check obj.txtPos.x.pos == checkPos[idxLab]
          inc idxLab
      else: discard
    plt.ggdraw("bartest.pdf")


  test "Plot with continuous color scale":
    let mpg = toDf(readCsv("data/mpg.csv"))
    ggplot(mpg, aes("displ", "hwy", color = "cty")) +
      geom_point() +
      ggsave("cont_color.pdf")
    # TODO: write an actual test here
    # NOTE: at least this works now! :) Only have to implement a legend for
    # colormaps and then we could add more colormaps.

  test "x,y aesthetics of geom picked over GgPlot":
    ## tests that the x, y aesthetics are picked from the present `geom`
    ## if x, y are defined, instead of the `GgPlot` object.
    let x = toSeq(0 .. 10).mapIt(it.float)
    let y1 = x.mapIt(cos(it))
    let y2 = x.mapIt(sin(it))
    let df = seqsToDf({"x" : x, "cos" : y1, "sin" : y2})

    let gplt = ggplot(df, aes(x ~ cos)) +
      geom_line() + # line for cos
      geom_line(aes(x ~ sin), # line for sin
                color = color(0.0, 0.0))
    # geoms[0].x and y won't be set, since the aes from ggplot is used
    check (not gplt.geoms[0].aes.x.isSome)
    check (not gplt.geoms[0].aes.y.isSome)
    check gplt.geoms[1].aes.x.isSome
    check gplt.geoms[1].aes.y.isSome
    check gplt.aes.x.get.scKind == scLinearData
    check gplt.aes.y.get.scKind == scLinearData
    check gplt.aes.x.get.col == "x"
    check gplt.aes.y.get.col == "cos"
    check gplt.geoms[1].aes.x.get.scKind == scLinearData
    check gplt.geoms[1].aes.y.get.scKind == scLinearData
    check gplt.geoms[1].aes.x.get.col == "x"
    check gplt.geoms[1].aes.y.get.col == "sin"

    # bonus check
    check gplt.geoms[1].style.isSome
    let style = gplt.geoms[1].style.get
    check style.color == color(0.0, 0.0)
    check style.lineWidth == 1.0
    check style.lineType == ltSolid
    check style.fillColor == transparent

    # we cannot guarantee in a test whether the order is preserved in the code other
    # than calling the proc, which handles the ordering
    let (x1v, y1v) = readXYcols(gplt, gplt.geoms[0], float)
    let (x2v, y2v) = readXYcols(gplt, gplt.geoms[1], float)

    check x1v == x
    check x2v == x
    check y1v == y1
    check y2v == y2

  test "Application of log scale works as expected":
    let x = linspace(0.0, 10.0, 500)
    let y1 = x.mapIt(cos(it))
    let y2 = x.mapIt(sin(it))
    let df = seqsToDf({"x" : x, "cos" : y1, "sin" : y2})
    block:
      let plt = ggplot(df, aes("x", "cos")) +
        geom_line() +
        scale_x_log10()
      check plt.aes.x.isSome
      check plt.aes.y.isSome
      check plt.aes.x.get.col == "x"
      check plt.aes.y.get.col == "cos"
      check plt.aes.x.get.axKind == akX
      check plt.aes.y.get.axKind == akY
      check plt.aes.x.get.scKind == scTransformedData
      check plt.aes.y.get.scKind == scLinearData

    # check also applied to another geom added before
    block:
      let plt = ggplot(df, aes("x", "cos")) +
        geom_line(aes(y = "sin")) +
        geom_point(aes(y = "sin")) +
        scale_y_log10()
      check plt.aes.x.isSome
      check plt.aes.y.isSome
      check plt.aes.x.get.col == "x"
      check plt.aes.y.get.col == "cos"
      check plt.aes.x.get.axKind == akX
      check plt.aes.y.get.axKind == akY
      check plt.aes.x.get.scKind == scLinearData
      check plt.aes.y.get.scKind == scTransformedData
      check plt.geoms[0].aes.y.get.col == "sin"
      check plt.geoms[0].aes.y.get.axKind == akY
      check plt.geoms[0].aes.y.get.scKind == scTransformedData
      plt.ggsave("sin_log.pdf")
    # check that it is ``not`` applied to a geom that is added ``after``
    # the call to `scale_*` (this is in contrast to `ggplot2` where the
    # order does not matter
    block:
      let plt = ggplot(df, aes("x", "cos")) +
        scale_x_log10() +
        geom_line(aes(y = "sin"))
      check plt.aes.x.isSome
      check plt.aes.y.isSome
      check plt.aes.x.get.col == "x"
      check plt.aes.y.get.col == "cos"
      check plt.aes.x.get.axKind == akX
      check plt.aes.y.get.axKind == akY
      check plt.aes.x.get.scKind == scTransformedData
      check plt.aes.y.get.scKind == scLinearData
      check plt.geoms[0].aes.y.get.col == "sin"
      check plt.geoms[0].aes.y.get.axKind == akY
      check plt.geoms[0].aes.y.get.scKind == scLinearData

  test "Automatic margin setting for labels":
    let x = logspace(-6, 1.0, 100)
    let y = x.mapIt(exp(-it))
    let df = seqsToDf({"x" : x, "exp" : y})
    let pltView = ggcreate(ggplot(df, aes("x", "exp")) +
      geom_line() +
      scale_y_log10())
    let plt = pltView.view
    # extract x and y label of plt's objects
    let xLab = plt.children[4].objects.filterIt(it.name == "xLabel")
    let yLab = plt.children[4].objects.filterIt(it.name == "yLabel")
    template checkLabel(lab, labName, text, posTup, rot): untyped =
      check lab.name == labName
      check lab.kind == goLabel
      check lab.txtText == text
      check lab.txtAlign == taCenter
      check lab.txtPos.y.toRelative.pos.almostEqual(posTup.y.toRelative.pos)
      when not defined(noCairo):
        ## This check only works if we compile with the cairo backend. That is because the
        ## placement of the text in y position depends explicitly on the extent of the
        ## text, which is determined using cairo's TTextExtents object. The dummy backend
        ## provides only zeroes for these numbers.
        check lab.txtPos.x.toRelative.pos.almostEqual(posTup.x.toRelative.pos)

      check lab.rotate == rot
      check lab.txtFont == Font(family: "sans-serif", size: 12.0, bold: false,
                                slant: fsNormal, color: color(0.0, 0.0, 0.0, 1.0))
    # the default label margin is 1 cm, i.e. ~28.34 pixels at 72 dpi
    checkLabel(xLab[0], "xLabel", "x",
               Coord(x: Coord1D(pos: 0.5, kind: ukRelative),
                     y: Coord1D(pos: 423.0944881889764, kind: ukPoint, length: some((val: 480.0, unit: ukPoint)))),
               none[float]())
    checkLabel(yLab[0], "yLabel", "exp",
               Coord(x: Coord1D(pos: -0.07931594488188977, kind: ukRelative),
                     y: Coord1D(pos: 0.5, kind: ukRelative)),
               some(-90.0))
    check yLab[0].txtPos.x.toPoints.pos != quant(1.0, ukCentimeter).toPoints.val
    plt.ggdraw("exp.pdf")

  test "Set manual margin and text for labels":
    let x = logspace(-6, 1.0, 100)
    let y = x.mapIt(exp(-it))
    let df = seqsToDf({"x" : x, "exp" : y})
    const xMargin = 0.5
    const yMargin = 1.7
    let pltView = ggcreate(ggplot(df, aes("x", "exp")) +
      geom_line() +
      xlab("Custom label", margin = xMargin) +
      ylab("More custom!", margin = yMargin) +
      scale_y_log10())
    let plt = pltView.view
    # extract x and y label of plt's objects
    let view = plt.children[4]
    let xLab = view.objects.filterIt(it.name == "xLabel")
    let yLab = view.objects.filterIt(it.name == "yLabel")
    template checkLabel(lab, labName, text, rot): untyped =
      check lab.name == labName
      check lab.kind == goLabel
      check lab.txtText == text
      check lab.txtAlign == taCenter
      check lab.rotate == rot
      check lab.txtFont == Font(family: "sans-serif", size: 12.0, bold: false,
                                slant: fsNormal, color: color(0.0, 0.0, 0.0, 1.0))
    # the default label margin is 1 cm, i.e. ~28.34 pixels at 72 dpi
    checkLabel(xLab[0], "xLabel", "Custom label",
               none[float]())
    checkLabel(yLab[0], "yLabel", "More custom!",
               some(-90.0))
    check almostEqual(yLab[0].txtPos.x.toPoints.pos,
                      -quant(yMargin, ukCentimeter).toPoints.val,
                      epsilon = 1e-6)
    check almostEqual(xLab[0].txtPos.y.toPoints.pos,
                      height(view).toPoints(some(view.hView)).val + quant(xMargin, ukCentimeter).toPoints.val,
                      epsilon = 1e-6)
    plt.ggdraw("exp2.pdf")

suite "Theme":
  test "Canvas background color":
    let mpg = toDf(readCsv("data/mpg.csv"))
    let white = color(1.0, 1.0, 1.0)
    proc checkPlt(plt: GgPlot) =
      check plt.theme.canvasColor.isSome
      check plt.theme.canvasColor.unsafeGet == white
      let pltGinger = ggcreate(plt)
      # don't expect root viewport to have more than 1 element here
      check pltGinger.view.objects.len == 1
      let canvas = pltGinger.view.objects[0]
      check canvas.kind == goRect
      check canvas.style.isSome
      let canvasStyle = canvas.style.get
      check canvasStyle.fillColor == white

    block:
      let plt = ggplot(mpg, aes("hwy", "cty")) +
        geom_point() +
        canvasColor(color = white)
      checkPlt(plt)
    block:
      let plt = ggplot(mpg, aes("hwy", "cty")) +
        geom_point() +
        theme_opaque()
      checkPlt(plt)

suite "Annotations":
  test "Annotation using relative coordinates":
    let df = toDf(readCsv("data/mpg.csv"))
    let annot = "A simple\nAnnotation\nMulti\nLine"
    let plt = ggcreate(ggplot(df, aes("hwy", "cty")) +
      geom_line() +
      annotate(annot,
               left = 0.5,
               bottom = 1.0,
               font = font(size = 12.0,
                           family = "monospace")))
    let view = plt.view
    # get actual plot view
    let actPlot = view[4]
    var count = 0
    for gobj in actPlot.objects:
      if "multiLineText" in gobj.name:
        when not defined(noCairo):
          ## text extent based calcs are not supported without cairo!
          check almostEqual(gobj.txtPos.x.pos, 0.5, epsilon = 1e-6)
        # we don't check y because it depends on the line
        inc count
      elif "annotationBackground" in gobj.name:
        # rough position check. Values should align with bottom left of
        # the rectangle, placed in the plot viewport. Takes into
        # account the margin we use:
        when not defined(noCairo):
          check almostEqual(gobj.reOrigin.x.pos, 0.49167, epsilon = 1e-4)
          check almostEqual(gobj.reOrigin.y.pos, 0.85734, epsilon = 1e-4)
        else:
          discard
    # check number of lines
    check count == annot.strip.splitLines.len

  test "Annotation using data coordinates":
    let df = toDf(readCsv("data/mpg.csv"))
    let annot = "A simple\nAnnotation\nMulti\nLine"
    let font = font(size = 12.0,
                    family = "monospace")
    let plt = ggcreate(ggplot(df, aes("hwy", "cty")) +
      geom_point() +
      annotate(annot,
               x = 10.0,
               y = 20.0,
               font = font))
    let view = plt.view
    # get actual plot view
    let actPlot = view[4]
    var count = 0
    for gobj in actPlot.objects:
      if "multiLineText" in gobj.name:
        when not defined(noCairo):
          ## text extent based calcs are not supported without cairo!
          check almostEqual(gobj.txtPos.x.pos, 0.0, epsilon = 1e-6)
        # we don't check y because it depends on the line
        check gobj.txtFont == font
        check gobj.txtText == annot.strip.splitLines[count]
        inc count
      elif "annotationBackground" in gobj.name:
        # rough position check
        when not defined(noCairo):
          check almostEqual(gobj.reOrigin.x.pos, -0.008327, epsilon = 1e-4)
          check almostEqual(gobj.reOrigin.y.pos, 0.35734, epsilon = 1e-4)
        check gobj.style.isSome
        check gobj.style.unsafeGet.color == color(1.0, 1.0, 1.0, 1.0)
        check gobj.style.unsafeGet.fillColor == color(1.0, 1.0, 1.0, 1.0)
    # check number of lines
    check count == annot.strip.splitLines.len

  test "Manually set x and y limits":
    let df = toDf(readCsv("data/mpg.csv"))
    let dfAt44 = df.filter(f{"hwy" == 44})
    check dfAt44.len == 2
    check dfAt44["cty"].vToSeq == %~ @[33.0, 35.0]
    block:
      let plt = ggcreate(ggplot(df, aes("hwy", "cty")) +
        geom_point() +
        ylim(5, 30)) # will cut off two values at hwy = 44, clip them to `30`, since
                      # default is `outsideRange = "clip"` (`orkClip`)
      let view = plt.view[4]
      check view.yScale == (low: 5.0, high: 30.0)
      for gobj in view[0].objects:
        case gobj.kind
        of goPoint:
          if gobj.ptPos.x.pos == 44.0:
            check almostEqual(gobj.ptPos.y.pos, 30.0, 1e-8)
        else: discard
    block:
      let plt = ggcreate(ggplot(df, aes("hwy", "cty")) +
        geom_point() +
        ylim(5, 30, outsideRange = "drop")) # will drop 2 values at `hwy = 44`
      let view = plt.view
      check view.yScale == (low: 5.0, high: 30.0)
      var count = 0
      for gobj in view[4][0].objects:
        case gobj.kind
        of goPoint:
          if gobj.ptPos.x.pos == 44.0:
            inc count
        else: discard
      check count == 0
    block:
      let plt = ggcreate(ggplot(df, aes("hwy", "cty")) +
        geom_point() +
        ylim(5, 30, outsideRange = "none")) # will leave two values at `hwy = 44` somewhere
                                             # outside the plot
      let view = plt.view
      check view.yScale == (low: 5.0, high: 30.0)
      for gobj in view[4][0].objects:
        case gobj.kind
        of goPoint:
          if gobj.ptPos.x.pos == 44.0:
            check (almostEqual(gobj.ptPos.y.pos, 33.0, 1e-8) or
                   almostEqual(gobj.ptPos.y.pos, 35.0, 1e-8))
        else: discard

  test "Set custom plot data margins":
    let df = toDf(readCsv("data/mpg.csv"))
    const marg = 0.05
    let plt = ggcreate(ggplot(df, aes("hwy", "cty")) +
        geom_point() +
        xMargin(marg))
    let pltRef = ggcreate(ggplot(df, aes("hwy", "cty")) +
        geom_point())
    let pltRefXScale = pltRef.view[4].xScale
    let view = plt.view[4]
    # naive `xScale` is low to high
    let xScale = (low: colMin(df, "hwy"), high: colMax(df, "hwy"))
    check pltRefXScale != xScale # scale is adjusted by calculation of tick positions!
    check view.xScale == (low: pltRefXScale.low - marg * (pltRefXScale.high - pltRefXScale.low),
                          high: pltRefXScale.high + marg * (pltRefXScale.high - pltRefXScale.low))

  test "Margin plus limit using orkClip clips to range + margin":
    let df = toDf(readCsv("data/mpg.csv"))
    const marg = 0.1
    let pltRef = ggcreate(ggplot(df, aes("hwy", "cty")) +
        geom_point())
    let plt = ggcreate(ggplot(df, aes("hwy", "cty")) +
        geom_point() +
        xlim(0.0, 30.0) +
        xMargin(marg))
    ## the interesting aspect here is that the points are not clipped to `30.0` as given
    ## by the limit, but rather to limit + margin. This allows to create a sort of
    ## buffer area where points show up, which are outside the desired range (e.g. to
    ## highlight `inf`, `-inf`). However, ``all`` values > 30.0 are clipped to `33`!
    let view = plt.view[4]
    echo view.xScale
    # results in range +- (range.high - range.low) * marg
    check view.xScale == (low: -3.0, high: 33.0)
    for gobj in view[0].objects:
      case gobj.kind
      of goPoint:
        if gobj.ptPos.x.pos > 30.0:
          check almostEqual(gobj.ptPos.x.pos, 33.0, 1e-8)
      else: discard

  test "Negative margins raise ValueError":
    let df = toDf(readCsv("data/mpg.csv"))
    expect(ValueError):
      ggplot(df, aes("hwy", "cty")) +
        geom_point() +
        xMargin(-0.5) +
        ggsave("raisesInstead")
    expect(ValueError):
      ggplot(df, aes("hwy", "cty")) +
        geom_point() +
        yMargin(-0.5) +
        ggsave("raisesInstead")
