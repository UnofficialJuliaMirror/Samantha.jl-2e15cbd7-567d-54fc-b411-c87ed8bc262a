### Types ###

struct EvalFactor
  preFunc::Function
  postFunc::Function
  pointValue::Float64
  state::Dict{String,Any}
end

mutable struct EvolutionProfile
  mprofile::MutationProfile
  factors::Vector{EvalFactor}
end
EvolutionProfile(mprofile) = EvolutionProfile(mprofile, EvalFactor[])

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

function seed!(estate::EvolutionState, agent::Agent, name=randstring())
  estate.seeds[name] = agent
end

### Phase Methods ###

# Pre-Evaluation phase
function preeval_phase!(estate::EvolutionState)
  for (name,agent) in estate.agents
    for factor in estate.profile.factors
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
    for factor in estate.profile.factors
      estate.scores[name][key] = factor.postFunc(agent, factor.state)
    end
  end
end
# Run all phases
function run!(estate::EvolutionState)
  preeval_phase!(estate)
  run_phase!(estate)
  preeval_phase!(estate)
  lifecycle_phase!(estate)
end

### GenericMode Defaults ###

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
    estate.agents[child_name] = child
    estate.mode.energies[child_name] = estate.mode.initialEnergy
  end
  for name in destroyed
    delete!(estate.agents, name)
    delete!(estate.mode.energies, name)
  end

  # Clone from seeds if necessary
  if length(estate.agents) == 0
    name = randstring()
    estate.agents[name] = mutate!(deepcopy(rand(collect(values(estate.seeds)))), estate.profile.mprofile)
    estate.mode.energies[name] = estate.mode.initialEnergy
  end
end
