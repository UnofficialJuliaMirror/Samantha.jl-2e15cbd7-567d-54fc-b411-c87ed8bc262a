### Types ###

@with_kw mutable struct RewardModulator{Frontend,LearnAlg,NDims}
  inputSize::Int
  outputSize::Int
  inputIndex::Int

  frontend::Frontend = GenericFrontend(inputSize, 1)
end

### Methods ###

early_modulate!(mod::Nothing, global_state) = ()
late_modulate!(mod::Nothing, global_state) = ()

#=
@with_kw mutable struct FunctionalModulator{OF<:Function,IF}
  outer::OF
  inner::IF = nothing
end
modulate!(state, node, mod::FunctionalModulator) = mod.func(modulate!(state, node, mod.inner), node)
=#

#@with_kw mutable struct RewardModulator
#  avgReward::Mean = RewardModulator(Mean(weight=ExponentialWeight()))
#end
#=
function modulate!(state, node::GenericNeurons, mod::RewardModulator)
  rF = node.state.F
  rw = mean(rF)
  #fit!(learnRate, rw-value(mod.avgReward))
  #fit!(mod.avgReward, rw)
  # TODO
end
=#
