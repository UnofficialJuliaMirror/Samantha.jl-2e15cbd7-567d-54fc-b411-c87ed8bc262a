### Exports ###

export GenericMod

### Types ###

@nodegen mutable struct GenericMod
  learnMod::Float32
  learnModShort::Float32
  learnModLong::Float32
  actMod::Float32
  actModShort::Float32
  actModLong::Float32
end
GenericMod() = GenericMod(1f0, 0f0, 0f0, 1f0, 0f0, 0f0)

### Methods ###

# TODO: Core methods

#= FIXME
function eforward!{C,S,M}(scont::CPUContainer{LearnModSynapses{C,S,M}}, ncontSrc::AbstractContainer, ncontDst::AbstractContainer)
  if scont.active
    mod = get(scont).synapses.mod
    input = mean(outputs(ncontSrc))
    mod.learnModShort = (input + (32 * mod.learnModShort)) / (32 + 1)
    mod.learnModLong = (input + (1024 * mod.learnModLong)) / (1024 + 1)
    mod.learnMod = 1000 * (mod.learnModShort - mod.learnModLong)
  end
end
function eforward!{C,S,M}(scont::CPUContainer{ActModSynapses{C,S,M}}, ncontSrc::AbstractContainer, ncontDst::AbstractContainer)
  if scont.active
    mod = get(scont).synapses.mod
    input = mean(outputs(ncontSrc))
    mod.actModShort = (input + (32 * mod.actModShort)) / (32 + 1)
    mod.actModLong = (input + (1024 * mod.actModLong)) / (1024 + 1)
    # TODO: Adjust formula for activity modulation
    mod.actMod = 1000 * (mod.actModShort - mod.actModLong)
  end
end
=#
