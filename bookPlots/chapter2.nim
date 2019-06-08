import ggplotnim

proc ch2_3() =
  let mpg = toDf(readCsv("../data/mpg.csv"))

  # the code is basically the same as for R, but we have to hand
  # strings explicitly for the column names. Adding a template
  # taking `untyped` does not work, since the proc of the same
  # is called instead
  ggplot(mpg, aes(x = "displ", y = "hwy")) +
    geom_point() +
    ggsave("figs/2.3_1.pdf")

  # same plot, but not specifying arguments of `aes`
  ggplot(mpg, aes("displ", "hwy")) +
    geom_point() +
    ggsave("figs/2.3_2.pdf")

  # exercises plots
  # nonsense plot
  # TODO: broken, because we cannot deal with string data at the moment
  # Should create ticks for each possible labels in x / y and create a
  # scatter plot like that. X und Y scale thus become based on classes
  # tick numbers replaced by values!
  #ggplot(mpg, aes("model", "manufacturer")) +
  #  geom_point() +
  #  ggsave("figs/2.3_3.pdf")

  ggplot(mpg, aes("cty", "hwy")) +
    geom_point() +
    ggsave("figs/2.3_4.pdf")

  let diamonds = toDf(readCsv("../data/diamonds.csv"))
  let economics = toDf(readCsv("../data/economics.csv"))

  # works but ylabels are to close to the plot so that they are
  # on top of the tick values
  # also not as fast as it could be :/
  ggplot(diamonds, aes("carat", "price")) +
    geom_point() +
    ggsave("figs/2.3_5.pdf")

  # broken, since we don't support `geom_line` yet, nor can parse
  # dates. See R example
  # geom_line is easy to add. Parsing dates is easy to add, once we
  # decide how to handle it. Convert to time in e.g. seconds and
  # calculate ticks based that? Probably best to work with native
  # dates using `times` module? Should be able to provide `<`, `<=`
  # and `==` (which should be all we need?)
  # also need a smart way to convert those dates back to strings for
  # labeling
  #ggplot(economics, aes("date", "unemploy")) +
  #  geom_line() +
  #  ggsave("figs/2.3_6.pdf")

  ggplot(mpg, aes("cty")) +
    geom_histogram() +
    ggsave("figs/2.3_7.pdf")

  # plots with different third dimension
  ggplot(mpg, aes(x = "displ", y = "hwy", color = "class")) +
    geom_point() +
    ggsave("figs/2.3_8.pdf")

  # broken, because `shape` is not yet supported yet. It's a dummy for the
  # `aes` proc, because we have not implemented enough different shapes
  # yet to support it
  #ggplot(mpg, aes(x = "displ", y = "hwy", shape = "drv")) +
  #  geom_point() +
  #  ggsave("figs/2.3_9.pdf")

  # `size` is still broken. Implementation is pretty easy though, we just
  # have to set the size instead of color for each data point based on
  # the continouos data scale given by the data of the given key. Should
  # probably define a range in of the size of the points e.g. 1.0 - 10.0
  # points or whatever and scale in that. Using Quantities that should be easy.
  #ggplot(mpg, aes(x = "displ", y = "hwy", size = "cyl")) +
  #  geom_point() +
  #  ggsave("figs/2.3_10.pdf")


when isMainModule:
  ch2_3()
