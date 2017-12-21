abstract type AbstractRecombination end

struct RecombinationProfile
  recombinations::Vector{AbstractRecombination}
end

# FIXME: Recombination operators
