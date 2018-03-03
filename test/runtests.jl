# Parse arguments, if any
path = "RUNME.jl"
for arg in ARGS
  if ispath(arg)
    path = arg
  else
    error("Unknown argument: $arg")
  end
end

using Compat
using Compat.Test
import Compat.@info
import Compat.@warn
import Compat.axes

# Setup global configuration
const SAMANTHA_TMP_HOME = mktempdir()
const SAMANTHA_DATA_PATH = joinpath(SAMANTHA_TMP_HOME, "data")
mkdir(SAMANTHA_DATA_PATH)
const SAMANTHA_LOG_PATH = joinpath(SAMANTHA_TMP_HOME, "logs")
mkdir(SAMANTHA_LOG_PATH)

try
  @info "Loading Samantha"
  include(joinpath("..", "src", "Samantha.jl")); using .Samantha

  if path == "RUNME.jl"
    @info "Running All Tests"
  else
    @info "Running Test $path"
  end
  include(path)

  @info "Tests Finished"
catch err
  try rm(SAMANTHA_TMP_HOME, true, true) end
  @warn "Error encountered"
  rethrow(err)
end
