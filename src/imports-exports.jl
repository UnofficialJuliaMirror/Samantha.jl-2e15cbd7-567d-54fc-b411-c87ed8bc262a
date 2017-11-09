### Imports ###

import Base: size, getindex, setindex!, get, merge, merge!

### Exports ###

export AbstractBranch, AbstractAccelerator, AbstractContainer, AbstractLoadable, AbstractNode
export @nodegen, isnodegenerated
export loadfile, storefile!, load, store!, sync!
export size, show, relocate!, register!, nupdate!, eforward!
export inputs, outputs, getindex, setindex!
export params
export addnode!, delnode!, addedge!, deledge!, addhook!, delhook!, gethook, sethook!
export merge, merge!

export MutationProfile, InplaceMutation, mutate!
export EvalFactor, EvolutionProfile, EvolutionState, GenericMode, addfactor!, seed!
