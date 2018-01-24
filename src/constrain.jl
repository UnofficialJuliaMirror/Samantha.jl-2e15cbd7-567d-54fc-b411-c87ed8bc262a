### Types ###

abstract type ConstraintIdentifier end
abstract type ConstraintRestriction end

struct Constraint{CI<:ConstraintIdentifier}
  identifier::CI
  restrictions::Vector{ConstraintRestriction}
end

### Constraint Identifiers ###

struct NodeIDConstraint <: ConstraintIdentifier
  node_id::String
end

struct NodeTypeConstraint <: ConstraintIdentifier
  node_type::Type
end

### Constraint Restrictions ###

"""
Restricts an agent from changing in any manner
"""
struct AgentTotalRestriction <: ConstraintRestriction end

"""
Restricts a node from changing in any manner
"""
struct NodeTotalRestriction <: ConstraintRestriction end

### Methods ###

isagentconstrained(agent::Agent, constraint::Constraint{CI} where CI) = false
isagentrestricted(agent::Agent, constraint::Constraint{CI} where CI) = false

isnodeconstrained(agent::Agent, node_id::String, constraint::Constraint{CI} where CI) = false
isnodeconstrained(agent::Agent, node_id::String, constraint::Constraint{NodeIDConstraint}) =
  (node_id == constraint.identifier.node_id)
isnoderestricted(agent::Agent, node_id::String, constraint::Constraint{CI} where CI) = false

isedgeconstrained(agent::Agent, edge::Tuple{String,String,Symbol}, constraint::Constraint{CI} where CI) = false
isedgerestricted(agent::Agent, edge::Tuple{String,String,Symbol}, constraint::Constraint{CI} where CI) = false
