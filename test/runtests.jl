using Base.Test
using Base.Dates
import TimeSeries: TimeArray, timestamp, colnames, values # Avoid name clashing on from
using JuMP
using Cbc
using IndustrialProcessFlexibilisation

@testset "IndustrialProcessFlexibilisation.jl" begin
  include("data.jl")
  include("model.jl")
  include("utils.jl")
end
