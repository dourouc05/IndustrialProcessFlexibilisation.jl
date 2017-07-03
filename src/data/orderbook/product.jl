"""
A product with its operational details (including requirement equipments and their consumption when making
this product).

The order for the various equipments is implicit: it is deducted from the routes available in a plant with which the
product will be associated.

This reprensentation makes the hypothesis that the consumption does not depend on the machine performing the operation,
if there are multiple such machines.
"""
struct Product
  name::AbstractString
  consumptions::Dict{Equipment, ConsumptionModel}
  batchSize::Dict{Equipment, Tuple{Float64, Float64}}

  function Product(pname::AbstractString, consumptions::Dict{Equipment, ConsumptionModel}, batchSize::Dict{Equipment, Tuple{Float64, Float64}})
    # Test whether the pieces of equipment for the consumptions and the batch sizes are equivalent. Also check whether
    # the batch sizes are consistent.
    for (eq, bs) in batchSize
      if ! in(eq, keys(consumptions))
        error("Equipment " * name(eq) * " has a batch size but no consumption. (Use NoConsumption() if the consumption is zero.)")
      end
      if bs[1] > bs[2]
        error("The maximum batch size is lower than the minimum for " * name(eq) * ".")
      end
    end
    for (eq, cm) in consumptions
      if ! in(eq, keys(batchSize))
        error("Equipment " * name(eq) * " has a consumption but no batch size.")
      end
    end

    # All checks are done.
    return new(pname, consumptions, batchSize)
  end
end

name(p::Product) = p.name
consumptions(p::Product) = p.consumptions
hasConsumption(p::Product, eq::AbstractEquipment) = haskey(consumptions(p), eq)
requiredEquipments(p::Product) = convert(Array{Symbol, 1}, unique(map((eq) -> kind(eq), keys(consumptions(p)))))

function consumption(p::Product, eq::Equipment)
  if hasConsumption(p, eq)
    return consumptions(p)[eq]
  else
    error("Product " * name(p) * " has no consumption for equipment " * name(eq) * ".")
  end
end

function consumption(p::Product, n::AbstractString)
  eqs = filter((e) -> name(e) == n, collect(keys(consumptions(p))))
  if length(eqs) == 1 # Found!
    consumption(p, eqs[1])
  else # Not found!
    error("Product " * name(p) * " has no consumption for equipment whose name is \"" * n * "\".")
  end
end

consumption(p::Product, s::Symbol) = Dict(e => consumption(p, e) for e in filter((eq) -> kind(eq) == s, collect(keys(consumptions(p))))) # An empty dictionary is returned if there is no match.
hasConsumption(p::Product, n::AbstractString) = in(n, map((e) -> name(e), keys(consumptions(p))))
hasConsumption(p::Product, s::Symbol) = in(s, map((e) -> kind(e), keys(consumptions(p))))

batchSizes(p::Product) = p.batchSize
minBatchSize(p::Product, eq::Equipment) = batchSizes(p)[eq][1]
maxBatchSize(p::Product, eq::Equipment) = batchSizes(p)[eq][2]
minBatchSize(lp::Array{Product, 1}, eq::Equipment) = minimum([minBatchSize(p, eq) for p in lp])
maxBatchSize(lp::Array{Product, 1}, eq::Equipment) = maximum([maxBatchSize(p, eq) for p in lp])
