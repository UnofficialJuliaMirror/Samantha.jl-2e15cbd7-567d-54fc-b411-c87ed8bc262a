### Types ###

struct EvalFactor
  preFunc::Function
  postFunc::Function
  pointValue::Float64
  state::Dict{String,Any}
end

mutable struct EvolutionProfile
  mprofile::MutationProfile
  factors::Dict{String,EvalFactor}
end
EvolutionProfile(mprofile) = EvolutionProfile(mprofile, Dict{String,EvalFactor}())

abstract type AbstractEvolutionMode end
mutable struct GenericMode <: AbstractEvolutionMode
  capacity::Int
  initialEnergy::Float64
  energyDecay::Float64
  birthBounds::Tuple{Float64,Float64}
  deathBounds::Tuple{Float64,Float64}
  accidentProb::Float64
  energies::Dict{String,Float64}
end
GenericMode(capacity, initialEnergy, energyDecay, birthBounds, deathBounds, accidentProb) =
  GenericMode(capacity, initialEnergy, energyDecay, birthBounds, deathBounds, accidentProb, Dict{String,Float64}())

mutable struct EvolutionState{M<:AbstractEvolutionMode}
  profile::EvolutionProfile
  mode::M
  seeds::Dict{String,Agent}
  agents::Dict{String,Agent}
  scores::Dict{String,Dict{String,Float64}}
end
EvolutionState(profile::EvolutionProfile, mode::AbstractEvolutionMode) =
  EvolutionState(profile, mode, Dict{String,Agent}(), Dict{String,Agent}(), Dict{String,Dict{String,Float64}}())

### Utility Methods ###

function setindex!(estate::EvolutionState, agent::Agent, name::String)
  estate.agents[name] = agent
  estate.scores[name] = Dict{String,Float64}()
  estate.mode[name] = agent
end
function delete!(estate::EvolutionState, name::String)
  delete!(estate.agents, name)
  delete!(estate.scores, name)
  delete!(estate.mode, name)
end
function addfactor!(profile::EvolutionProfile, key::String, pointValue, preFunc::Function, postFunc::Function)
  profile.factors[key] = EvalFactor(preFunc, postFunc, pointValue, Dict{String,Any}())
end
addfactor!(profile, pointValue, preFunc, postFunc) = addfactor!(profile, randstring(), pointValue, preFunc, postFunc)
function seed!(estate::EvolutionState, agent::Agent, name=randstring())
  estate.seeds[name] = agent
end

### Phase Methods ###

# Pre-Evaluation phase
function preeval_phase!(estate::EvolutionState)
  for (name,agent) in estate.agents
    for (key,factor) in estate.profile.factors
      factor.preFunc(agent, factor.state)
    end
  end
end
# Run phase
function run_phase!(estate::EvolutionState)
  for agent in values(estate.agents)
    run!(agent)
  end
end
# Post-Evaluation phase
function posteval_phase!(estate::EvolutionState)
  for (name,agent) in estate.agents
    for (key,factor) in estate.profile.factors
      estate.scores[name][key] = factor.postFunc(agent, factor.state)
    end
  end
end
# Run all phases
function run!(estate::EvolutionState)
  preeval_phase!(estate)
  run_phase!(estate)
  posteval_phase!(estate)
  lifecycle_phase!(estate)
end

### GenericMode Defaults ###

setindex!(mode::GenericMode, agent::Agent, name::String) =
  setindex!(mode.energies, mode.initialEnergy, name)
delete!(mode::GenericMode, name::String) = delete!(mode.energies, name)
function lifecycle_phase!(estate::EvolutionState{GenericMode})
  # Calculate current birth and death energies
  carryFactor = length(collect(keys(estate.agents))) / estate.mode.capacity
  birthLower, birthUpper = estate.mode.birthBounds
  birthEnergy = carryFactor*(birthUpper-birthLower)+birthLower
  deathLower, deathUpper = estate.mode.deathBounds
  deathEnergy = carryFactor*(deathUpper-deathLower)+deathLower

  created = String[]
  destroyed = String[]
  for (name,energy) in estate.mode.energies
    energy > birthEnergy && push!(created, name)
    (energy < deathEnergy || rand() < estate.mode.accidentProb) && push!(destroyed, name)
    estate.mode.energies[name] *= (1 - estate.mode.energyDecay)
  end
  for name in created
    child = mutate!(deepcopy(estate.agents[name]), estate.profile.mprofile)
    child_name = randstring()
    estate[child_name] = child
  end
  for name in destroyed
    delete!(estate, name)
  end

  # Clone from seeds if necessary
  if length(estate.agents) == 0
    name = randstring()
    agent = mutate!(deepcopy(rand(collect(values(estate.seeds)))), estate.profile.mprofile)
    estate[name] = agent
  end
end
