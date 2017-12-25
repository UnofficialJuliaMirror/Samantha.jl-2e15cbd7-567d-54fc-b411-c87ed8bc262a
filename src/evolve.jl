import Base: delete!

### Types ###

struct EvalFactor
  func::Function
  state::Dict{String,Any}
end

mutable struct EvolutionProfile
  mprofile::MutationProfile
  # TODO: rprofile::RecombinationProfile
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
function Base.delete!(estate::EvolutionState, name::String)
  delete!(estate.agents, name)
  delete!(estate.scores, name)
  delete!(estate.mode, name)
end
function addfactor!(func::Function, profile::EvolutionProfile, key::String)
  profile.factors[key] = EvalFactor(func, Dict{String,Any}())
end
addfactor!(func, profile) = addfactor!(profile, randstring(), func)
function seed!(estate::EvolutionState, agent::Agent, name=randstring())
  estate.seeds[name] = agent
end

### Phase Methods ###

# Run phase
function run_phase!(estate::EvolutionState)
  for agent in values(estate.agents)
    run!(agent)
  end
end
# Evaluation phase
function eval_phase!(estate::EvolutionState)
  for (name,agent) in estate.agents
    for (key,factor) in estate.profile.factors
      estate.scores[name][key] = factor.func(agent, factor.state)
    end
  end
end
# Run all phases
function run!(estate::EvolutionState)
  run_phase!(estate)
  eval_phase!(estate)
  lifecycle_phase!(estate)
end

### GenericMode Defaults ###

setindex!(mode::GenericMode, agent::Agent, name::String) =
  setindex!(mode.energies, mode.initialEnergy, name)
Base.delete!(mode::GenericMode, name::String) = Base.delete!(mode.energies, name)
function lifecycle_phase!(estate::EvolutionState{GenericMode})
  added, deleted = String[], String[]
  # Calculate current birth and death energies
  carryFactor = length(estate.agents) / estate.mode.capacity
  birthLower, birthUpper = estate.mode.birthBounds
  birthEnergy = carryFactor*(birthUpper-birthLower)+birthLower
  deathLower, deathUpper = estate.mode.deathBounds
  deathEnergy = carryFactor*(deathUpper-deathLower)+deathLower

  # Update energies based on scores
  for (name,scores) in estate.scores
    estate.mode.energies[name] += sum(values(scores))
  end

  # Mark agents for creation or deletion
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
