nupdate!(cont::CPUContainer{C}) where C<:AbstractNode = nupdate!(get(cont))
nupdate!(x::Any) = ()

sync!(cont::C) where C<:AbstractContainer = sync!(cont.root) # TODO: First pull down transient?
sync!(num::N) where N<:Number = ()
sync!(arr::A) where A<:AbstractArray = Mmap.sync!(arr)

mutate!(cont::CPUContainer{C}, args...) where C = mutate!(get(cont), args...)

defaultvalue(obj, param1, params...) = defaultvalue(obj[param1], params...)
defaultvalue(obj, param::T) where T<:Val = defaultvalue(obj[param])
defaultvalue(x::T) where T<:Number = zero(T)

bounds(obj, param1, params...) = bounds(obj[param1], params...)
bounds(obj, param::T) where T<:Val = bounds(obj[param])
bounds(x::T) where T<:Number = (zero(T), one(T))
