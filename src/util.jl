### Imports ###

import Base: size, setindex!, getindex, broadcast!, Broadcast.fill!, Broadcast.fill

### Exports ###

export ZeroArray

### Types ###

# Useful type for writing/reading inactive containers efficiently
mutable struct ZeroArray{T, N} <: DenseArray{T, N}
  size::NTuple{N, Int}
end
ZeroArray{N}(T::Type, size::NTuple{N,Int}) = ZeroArray{T,N}(size)
ZeroArray{T,N}(arr::DenseArray{T,N}) = ZeroArray{T,N}(size(arr))

# TODO: LockedArray for locking individual arrays

### Methods ###

Base.size(za::ZeroArray) = za.size
# TODO: Check for OOB situation?
Base.setindex!{T,N}(za::ZeroArray{T,N}, value, idx...) = zero(T)
Base.getindex{T,N}(za::ZeroArray{T,N}, idx...) = zero(T)
# TODO: More broadcast overrides
Base.broadcast!{T,N}(f, za::ZeroArray{T,N}, args...) = za
Base.Broadcast.fill!{T,N}(za::ZeroArray{T,N}, value) = za
Base.Broadcast.fill{T,N}(za::ZeroArray{T,N}, value::T) =
  (value == zero(T) ? za : error("Cannot fill a ZeroArray with a non-zero element"))
