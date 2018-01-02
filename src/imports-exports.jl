### Imports ###

import Base: size, show, getindex, setindex!, merge, merge!

### Exports ###

export AbstractBranch, AbstractAccelerator, AbstractContainer, AbstractLoadable, AbstractNode
export @nodegen, isnodegenerated
export loadfile, storefile!, load, store!, sync!
export size, show, relocate!, register!, nupdate!, eforward!, clear!
export inputs, outputs, getindex, setindex!
export params
export merge, merge!

export MutationProfile, InplaceMutation, ChangeEdgePatternMutation, mutate!
export RecombinationProfile, CheapRecombination, recombine
export EvalFactor, EvolutionProfile, EvolutionState, GenericMode, addfactor!, seed!, setup
