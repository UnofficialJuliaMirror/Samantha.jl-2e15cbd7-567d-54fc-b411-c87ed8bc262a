nupdate!(x::Any) = ()
nupdate!(cont::CPUContainer{C}) where C<:AbstractNode = nupdate!(get(cont))

sync!(cont::C) where C<:AbstractContainer = sync!(cont.root) # TODO: First pull down transient?
sync!(num::N) where N<:Number = ()
sync!(arr::A) where A<:AbstractArray = Mmap.sync!(arr)
