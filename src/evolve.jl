import Base: delete!

### Types ###

mutable struct EvolutionProfile
  mprofile::MutationProfile
  rprofile::RecombinationProfile
  factors::Dict{String,Function}
end
EvolutionProfile(mprofile, rprofile) = EvolutionProfile(mprofile, rprofile, Dict{String,Function}())

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
  states::Dict{String,Dict{String,Dict}}
end
EvolutionState(profile::EvolutionProfile, mode::AbstractEvolutionMode) =
  EvolutionState(profile, mode, Dict{String,Agent}(), Dict{String,Agent}(), Dict{String,Dict{String,Float64}}(), Dict{String,Dict{String,Dict}}())

### Utility Methods ###

function setindex!(estate::EvolutionState, agent::Agent, name::String)
  estate.agents[name] = agent
  estate.scores[name] = Dict{String,Float64}()
  estate.states[name] = Dict{String,Dict}()
  for (key,factor) in estate.profile.factors
    estate.scores[name][key] = 0.0
    estate.states[name][key] = Dict{String,Any}()
  end
  estate.mode[name] = agent
end
function Base.delete!(estate::EvolutionState, name::String)
  delete!(estate.agents, name)
  delete!(estate.scores, name)
  delete!(estate.states, name)
  delete!(estate.mode, name)
end
function addfactor!(func::Function, profile::EvolutionProfile, key::String)
  profile.factors[key] = func
end
addfactor!(func, profile) = addfactor!(profile, randstring(), func)
function seed!(estate::EvolutionState, agent::Agent, name=randstring())
  estate.seeds[name] = agent
end
# Wire up the internals as necessary (such as after adding a new factor)
function setup(estate::EvolutionState)
  for (name,agent) in estate.agents
    estate.scores[name] = Dict{String,Float64}()
    estate.states[name] = Dict{String,Dict}()
    for (key,factor) in estate.profile.factors
      estate.scores[name][key] = 0.0
      estate.states[name][key] = Dict{String,Any}()
    end
  end
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
      estate.scores[name][key] = factor(agent, estate.states[name][key])
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
function compute_bounds(estate::EvolutionState{GenericMode})
  # Calculate current birth and death energies
  carryFactor = exp(length(estate.agents) / estate.mode.capacity)-1
  birthLower, birthUpper = estate.mode.birthBounds
  birthEnergy = carryFactor*(birthUpper-birthLower)+birthLower
  deathLower, deathUpper = estate.mode.deathBounds
  deathEnergy = carryFactor*(deathUpper-deathLower)+deathLower
  return (carryFactor, birthEnergy, deathEnergy)
end
function lifecycle_phase!(estate::EvolutionState{GenericMode})
  added, deleted = String[], String[]
  
  carryFactor, birthEnergy, deathEnergy = compute_bounds(estate)

  # Update energies based on scores
  for (name,scores) in estate.scores
    estate.mode.energies[name] += sum(values(scores))
  end

  # Mark agents for creation or deletion
  created = Set{String}()
  destroyed = Set{String}()
  for (name,energy) in estate.mode.energies
    if energy > birthEnergy
      push!(created, name)
      estate.mode.energies[name] -= estate.mode.initialEnergy
    end
    if energy < deathEnergy || rand() < estate.mode.accidentProb
      push!(destroyed, name)
    end
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

  # Optionally create child as offspring of two agents
  # TODO: Improve this significantly (make tunable, adjust based on carryFactor, etc.)
  if rand() < 0.1
    pool = vcat(collect(values(estate.agents)), collect(values(estate.seeds)))
    parent1, parent2 = rand(pool), rand(pool)
    child = recombine(estate.profile.rprofile, parent1, parent2)
    mutate!(child, estate.profile.mprofile)
    estate[randstring()] = child
  end

  # Clone from seeds if necessary
  if length(estate.agents) == 0
    name = randstring()
    agent = mutate!(deepcopy(rand(collect(values(estate.seeds)))), estate.profile.mprofile)
    estate[name] = agent
  end
end
