@testset "Production model" begin
  @testset "Results data structures" begin
    e1 = Equipment("EAF", :eaf)
    e2 = Equipment("LF", :lf)
    r1 = NormalRoute(e1, e2)
    le = [e1, e2]
    lr = Route[r1]
    p = Plant(le, lr)

    c = ConstantConsumption(2.0)
    p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2]]))
    ob = OrderBook(Dict(DateTime(2017, 01, 30) => (p1, 50.)))

    date = DateTime(2017, 01, 01, 08)
    t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
    s = Shifts(t, date, Hour(8))

    epDates = collect(date:Hour(1):date + Week(5))
    ep = TimeArray(epDates, 50 + 10 * sin.(1:length(epDates)) + rand(length(epDates)))
    o = EnergyObjective(ep, t)

    m = Model()
    pm = PlantModel(m, p, ob, t, s)

    # First, build a failed result. 
    failed = ProductionModelResults(m, pm)

    @test ! failed.feasibility 
    @test failed.model == m
    @test failed.plantModel == pm
    @test isempty(failed.shiftsOpenRaw)
    @test isempty(failed.shiftsOpen)
    @test isempty(failed.productionPlanOutput)

    # Then, a successful one. (Only two time steps.)
    production = zeros(Float64, 2, 1)
    production[1, 1] = 50.
    successful = ProductionModelResults(m, pm, [true, false], [(date, Hour(4), 1)], production)
    
    @test successful.feasibility 
    @test successful.model == m
    @test successful.plantModel == pm
    @test successful.shiftsOpenRaw == [true, false]
    @test successful.shiftsOpen == [(date, Hour(4), 1)]
    @test successful.productionPlanOutput == production
  end

  @testset "Basic use" begin
    e1 = Equipment("EAF", :eaf)
    e2 = Equipment("LF", :lf)
    e3 = Equipment("CC", :cc)
    r1 = NormalRoute(e1, e2)
    r2 = NormalRoute(e2, e3)
    le = [e1, e2, e3]
    lr = Route[r1, r2]
    p = Plant(le, lr)

    c = ConstantConsumption(2.0)
    p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
    p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
    ob = OrderBook(Dict(DateTime(2017, 01, 30) => (p1, 50.), DateTime(2017, 01, 30) => (p2, 50.)))

    date = DateTime(2017, 01, 01, 08)
    t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
    s = Shifts(t, date, Hour(8))

    epDates = collect(date:Hour(1):date + Week(5))
    ep = TimeArray(epDates, 50 + 10 * sin.(1:length(epDates)) + rand(length(epDates)))

    function hrp_test(d::DateTime)
      base = 1000

      if hour(d) < 6 || hour(d) >= 22 # Night.
        base *= 1.2
      end

      if dayname(d) == "Sunday" # WE.
        base *= 2
      end

      return base
    end
    eo = EnergyObjective(ep, t)
    hro = HRCostObjective(hrp_test)
    o = ObjectiveCombination([eo, hro])

    pr = productionModel(p, ob, t, s, o, solver=CbcSolver(logLevel=0))
    @test pr.feasibility
    @test sum(pr.shiftsOpenRaw) == 1
    @test length(pr.shiftsOpen) == 1
    @test pr.shiftsOpen[1][1] >= timeBeginning(t)
    @test pr.shiftsOpen[1][1] <= timeEnding(t)
    @test pr.shiftsOpen[1][2] == Hour(8)
    @test pr.shiftsOpen[1][3] == 1
    @test size(pr.productionPlanOutput, 1) == 840
    @test size(pr.productionPlanOutput, 2) == 1
    @test sum(pr.productionPlanOutput) == 120
  end
end