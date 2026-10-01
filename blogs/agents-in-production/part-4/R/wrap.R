# Copy an ellmer tool so every call goes through `around(run, args)`.
# `run()` calls the original tool; `args` is the named list of arguments.
# ellmer checks that a tool's arguments match its function's formals, so the
# wrapper copies the original formals rather than using `...`.
wrap_tool <- function(tool, around) {
  inner <- tool
  fun <- function() {
    args <- as.list(environment())
    around(function() do.call(inner, args), args)
  }
  formals(fun) <- formals(inner)
  ellmer::tool(
    fun,
    name = inner@name,
    description = inner@description,
    arguments = inner@arguments@properties,
    convert = inner@convert,
    annotations = inner@annotations
  )
}
