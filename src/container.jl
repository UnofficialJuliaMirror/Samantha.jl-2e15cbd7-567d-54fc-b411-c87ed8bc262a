### Imports ###

import Base: get

### Exports ###

export CPUContainer
export get, getroot

### Types ###

# InactiveContainer doesn't do anything, so it doesn't need a transient
mutable struct InactiveContainer{R} <: AbstractContainer
  root::R
end
# CPUContainer doesn't store data anywhere special, so it doesn't need a transient
mutable struct CPUContainer{R} <: AbstractContainer
  root::R
end

### Methods ###

# Gets the root of a container
getroot(cont::AbstractContainer) = cont.root

# Gets the transient of a container
get(cont::AbstractContainer) = cont.transient
get(cont::InactiveContainer) = cont.root
get(cont::CPUContainer) = cont.root
