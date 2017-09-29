using Base.Test
using Base.Dates
using TimeSeries
using JuMP
using Cbc
using IndustrialProcessFlexibilisation

# Types used for the tests.
struct ConcreteRoute <: Route end # data.jl > Routes
struct DummyProductionObjective <: ProductionObjective end # model.jl > Data structures > Objective

@testset "IndustrialProcessFlexibilisation.jl" begin
  include("data.jl")
  include("model.jl")
  include("utils.jl")
  include("io.jl")
end
