@testset "All pieces of equipment" begin
  # model/ds/equipment.jl, postConstraints(m::Model, hrm::TimingModel, eqs::Array{EquipmentModel, 1})
  date = DateTime(2017, 01, 01, 12, 32, 42)
  t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
  s = Shifts(t, date, Hour(8))

  e1 = Equipment("EAF", :eaf)
  e2 = Equipment("LF", :lf)
  c = ConstantConsumption(2.0)
  p = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 155.0), e2 => (150.0, 155.0)))
  ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

  m = Model(solver=CbcSolver(logLevel=0))
  hrm = TimingModel(m, t, s)
  eq1m = EquipmentModel(m, e1, t, ob)
  eq2m = EquipmentModel(m, e2, t, ob)
  inm = EquipmentModel(m, inEquipment, t, ob)
  outm = EquipmentModel(m, outEquipment, t, ob)

  postConstraints(m, hrm)
  postConstraints(m, hrm, collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, [eq1m, eq2m, inm, outm]))) # Same filtering as in model/production.jl. 

  # Force a machine to be on, see that there must be some time steps open. 
  @constraint(m, timeStepOpen(hrm, date) == 1.)
  @objective(m, Min, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
  solve(m)
  @test getobjectivevalue(m) > 0.0
end