### Imports ###

import Base: size, setindex!, getindex, broadcast!, Broadcast.fill!, Broadcast.fill

### Exports ###

export ZeroArray, RingBuffer

### Types ###

# Useful type for writing/reading inactive containers efficiently
mutable struct ZeroArray{T, N} <: DenseArray{T, N}
  size::NTuple{N, Int}
end
ZeroArray{N}(T::Type, size::NTuple{N,Int}) = ZeroArray{T,N}(size)
ZeroArray{T,N}(arr::DenseArray{T,N}) = ZeroArray{T,N}(size(arr))

mutable struct RingBuffer{T}
  buf::AbstractArray{T,2}
  pos::Int
end
RingBuffer(T, width, length) = RingBuffer(zeros(T, width, length), 1)

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


function rotate!(rb::RingBuffer)
  if rb.pos < size(rb.buf, 2)
    rb.pos += 1
  else
    rb.pos = 1
  end
end
Base.getindex(rb::RingBuffer, idx) = getindex(rb.buf, idx, rb.pos)
function Base.getindex(rb::RingBuffer, idx1, idx2)
  @assert 1 < idx2 < size(rb.buf, 2) "Invalid RingBuffer position: $idx2"
  npos = rb.pos - idx2
  if npos < 1
    npos += size(rb.buf, 2)
  end
  getindex(rb.buf, idx1, npos)
end
Base.setindex!(rb::RingBuffer, value, idx) = setindex!(rb.buf, value, idx, rb.pos)
function Base.setindex!(rb::RingBuffer, value, idx1, idx2)
  @assert 1 < idx2 < size(rb.buf, 2) "Invalid RingBuffer position: $idx2"
  npos = rb.pos - idx2
  if npos < 1
    npos += size(rb.buf, 2)
  end
  setindex!(rb.buf, value, idx1, npos)
end
Base.endof(rb::RingBuffer) = rb.buf[end,rb.pos]
