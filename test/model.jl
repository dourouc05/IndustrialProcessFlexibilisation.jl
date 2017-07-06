@testset "Optimisation models" begin
  @testset "Specific data structures" begin
    @testset "Timing" begin
      date = DateTime(2017, 01, 01, 08)
      t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1), shiftBeginning=date, shiftDuration=Hour(8))
      m = Model(solver=CbcSolver(logLevel=0))
      hrm = TimingModel(m, t)

      @test(timing(hrm) == t)
      @test(timeBeginning(hrm) == timeBeginning(t))
      @test(timeHorizon(hrm) == timeHorizon(t))
      @test(timeEnding(hrm) == timeEnding(t))
      @test(timeStepDuration(hrm) == timeStepDuration(t))
      @test(shiftBeginning(hrm) == shiftBeginning(t))
      @test(shiftDuration(hrm) == shiftDuration(t))

      @test(nTimeSteps(hrm) == 48)
      @test(nTimeSteps(hrm, Minute(15)) == 1) # Something that lasts 15 minutes has to be represented as one time step here (even though it is much shorter than one hour).
      @test(nTimeSteps(hrm, Day(1)) == 24)
      @test(nTimeStepsPerShift(hrm) == 8)
      @test(nShifts(hrm) == 6)

      @test_throws(ErrorException, dateToTimeStep(hrm, date - Hour(1)))
      @test(dateToTimeStep(hrm, date) == 1)
      @test(dateToTimeStep(hrm, date + Minute(15)) == 1)
      @test(dateToTimeStep(hrm, date + Hour(1)) == 2)
      @test(dateToTimeStep(hrm, date + Hour(8)) == 9) # One shift.
      @test(dateToTimeStep(hrm, date + Hour(47)) == 48) # Optimisation horizon.

      @test_throws(ErrorException, dateToShift(hrm, date - Hour(1)))
      @test(dateToShift(hrm, date) == 1)
      @test(dateToShift(hrm, date + Hour(5)) == 1)
      @test(dateToShift(hrm, date + Hour(7)) == 1)
      @test(dateToShift(hrm, date + Hour(8)) == 2)
      @test(dateToShift(hrm, date + Hour(12)) == 2)

      # Optimisation variable accessors.
      @test(shiftOpen(hrm, 1) == hrm.shiftOpen[1])

      @test(timeStepOpen(hrm, date) == shiftOpen(hrm, 1))
      @test(timeStepOpen(hrm, date + Minute(15)) == shiftOpen(hrm, 1))
      @test(timeStepOpen(hrm, date + Hour(15)) == shiftOpen(hrm, 2))

      # TODO: More involved tests: the beginning of the shifts is four hours before the optimisation.
      date = DateTime(2017, 01, 01, 08)
      t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1), shiftBeginning=date - Hour(4), shiftDuration=Hour(8))
      m = Model(solver=CbcSolver(logLevel=0))
      hrm = TimingModel(m, t)

      @test_throws(ErrorException, dateToShift(hrm, date - Hour(4) - Hour(1)))
      @test(dateToShift(hrm, date - Hour(4)) == 1)
      @test(dateToShift(hrm, date - Hour(4) + Hour(5)) == 1)
      @test(dateToShift(hrm, date - Hour(4) + Hour(7)) == 1)
      @test(dateToShift(hrm, date - Hour(4) + Hour(8)) == 2)
      @test(dateToShift(hrm, date - Hour(4) + Hour(12)) == 2)
    end

    @testset "Equipment" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1), shiftBeginning=date, shiftDuration=Hour(8))

      e = Equipment("EAF", :eaf)
      c = ConstantConsumption(2.0)
      p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

      m = Model(solver=CbcSolver(logLevel=0))
      eqm = EquipmentModel(m, e, t, ob)
      inm = EquipmentModel(m, inEquipment, t, ob)
      oum = EquipmentModel(m, outEquipment, t, ob)

      # Linking to the right objects.
      @test(equipment(eqm) == e)
      @test(equipment(inm) == inEquipment)
      @test(equipment(oum) == outEquipment)
      for em in [eqm, inm, oum]
        @test(timing(em) == t)
        @test(orderBook(em) == ob)
      end

      # Linking to Equipment.
      @test(name(eqm) == name(e))
      @test(name(inm) == name(inEquipment))
      @test(name(oum) == name(outEquipment))
      @test(kind(eqm) == kind(e))
      @test(kind(inm) == kind(inEquipment))
      @test(kind(oum) == kind(outEquipment))
      @test(transformationRate(eqm) == transformationRate(e))
      @test_throws(MethodError, transformationRate(inm))
      @test_throws(MethodError, transformationRate(oum))
      @test(minimumUpTime(eqm) == minimumUpTime(e))
      @test_throws(MethodError, minimumUpTime(inm))
      @test_throws(MethodError, minimumUpTime(oum))
      @test(minimumUpTime(eqm) == minimumUpTime(e))
      @test_throws(MethodError, minimumUpTime(inm))
      @test_throws(MethodError, minimumUpTime(oum))
      @test(minimumProduction(eqm) == minimumProduction(e))
      @test_throws(MethodError, minimumProduction(inm))
      @test_throws(MethodError, minimumProduction(oum))
      @test(maximumProduction(eqm) == maximumProduction(e))
      @test_throws(MethodError, maximumProduction(inm))
      @test_throws(MethodError, maximumProduction(oum))
      @test(processTime(eqm) == processTime(e))
      @test_throws(MethodError, processTime(inm))
      @test_throws(MethodError, processTime(oum))

      for em in [eqm, inm, oum]
        # Linking to Timing.
        @test(timeBeginning(em) == timeBeginning(t))
        @test(timeHorizon(em) == timeHorizon(t))
        @test(timeEnding(em) == timeEnding(t))
        @test(timeStepDuration(em) == timeStepDuration(t))
        @test(nTimeSteps(em, Minute(15)) == nTimeSteps(t, Minute(15)))
        @test(nTimeSteps(em, Day(1)) == nTimeSteps(t, Day(1)))
        @test(nTimeSteps(em) == nTimeSteps(t))
        @test(dateToTimeStep(em, date) == dateToTimeStep(t, date))
        @test(dateToTimeStep(em, date + Hour(5)) == dateToTimeStep(t, date + Hour(5)))
        @test(dateToTimeStep(em, date + Hour(7)) == dateToTimeStep(t, date + Hour(7)))
        @test(dateToTimeStep(em, date + Hour(8)) == dateToTimeStep(t, date + Hour(8)))
        @test(dateToTimeStep(em, date + Hour(12)) == dateToTimeStep(t, date + Hour(12)))
        @test(eachTimeStep(em) == eachTimeStep(t))
        @test(collect(eachTimeStep(em)) == collect(eachTimeStep(t)))

        # Linking to OrderBook.
        @test(products(em) == products(ob))
        @test(nProducts(em) == nProducts(ob))
        @test(productIds(em) == productIds(ob))
      end

      # Linking to Product.
      @test(maxBatchSize(p, eqm) == maxBatchSize(p, e))
      @test_throws(MethodError, maxBatchSize(p, inm))
      @test_throws(MethodError, maxBatchSize(p, oum))
      @test(minBatchSize(p, eqm) == minBatchSize(p, e))
      @test_throws(MethodError, minBatchSize(p, inm))
      @test_throws(MethodError, minBatchSize(p, oum))
    end

    @testset "Consumption" begin # TODO: Really keep consumption separate? Maybe easier for maintenance (requires a new function each time a consumption model is added).
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1), shiftBeginning=date, shiftDuration=Hour(8))

      e = Equipment("EAF", :eaf)
      c = ConstantConsumption(2.0)
      p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

      m = Model(solver=CbcSolver(logLevel=0))
      eqm = EquipmentModel(m, e, t, ob)
    end

    @testset "Plant" begin
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      le = [e1, e2, e3]
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      le = [e1, e2, e3]
      lr = Route[r1, r2]
      p = Plant(le, lr)

      c = ConstantConsumption(2.0)
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
      p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
      ob = OrderBook(Dict(DateTime(2017, 01, 30) => (p1, 50.), DateTime(2017, 01, 30) => (p2, 50.)))

      date = DateTime(2017, 01, 01, 08)
      t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1), shiftBeginning=date, shiftDuration=Hour(8))

      m = Model(solver=CbcSolver(logLevel=0))
      pm = PlantModel(m, p, ob, t)

      # Basic accessors.
      @test(timingModel(pm) == pm.hr)
      @test(equipmentModels(pm) == pm.equipments)
      @test(flowModels(pm) == pm.flows)
      # @test(equipmentModel(pm, "EAF") == find()) TODO
      # @test(flowModel(pm) == TODO
    end
  end

  @testset "Model building blocks" begin
    @testset "Timing" begin
      @testset "Shifts and optimisation starts simultaneously" begin
        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1), shiftBeginning=date, shiftDuration=Hour(8))

        # Check the constraints behave as expected.
        # First shift 8:00-16:00: if the second time step is open, then the shift is open. (Actually, this constraint is
        # automatically rewritten as a shift opening.)
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t)
        postConstraints(m, hrm)
        @constraint(m, timeStepOpen(hrm, date + Hour(1)) == 1.)
        solve(m)
        @test(getvalue(shiftOpen(hrm, 1)) == 1.0)

        # If the shift 16:00-0:00 is open, and if only one shift is allowed, then the maximum number of time steps is eight.
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t)
        postConstraints(m, hrm)
        @constraint(m, shiftOpen(hrm, 1) == 0.)
        @constraint(m, shiftOpen(hrm, 2) == 1.)
        for i in 3:nShifts(hrm)
          @constraint(m, shiftOpen(hrm, i) == 0.)
        end
        @objective(m, Max, sum([shiftOpen(hrm, i) for i in 1:nShifts(hrm)]))
        solve(m)
        @test(getobjectivevalue(m) == 1.)
      end

      @testset "Shifts begin before optimisation" begin
        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1), shiftBeginning=date - Hour(4), shiftDuration=Hour(8))

        # If the first shift is open, can work at most four hours.
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t)
        postConstraints(m, hrm)
        @constraint(m, shiftOpen(hrm, 1) == 1.)
        for i in 2:nShifts(hrm)
          @constraint(m, shiftOpen(hrm, i) == 0.)
        end
        @objective(m, Max, sum([shiftOpen(hrm, i) for i in 1:nShifts(hrm)]))
        solve(m)
        @test(getobjectivevalue(m) == 1.)
      end
    end
  end

  @testset "Production model" begin
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
    t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1), shiftBeginning=date, shiftDuration=Hour(8))

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

    # The model should be built without error.
    status, pm, m, shiftsOpen, productionRaw = productionModel(p, ob, t, o, solver=CbcSolver(logLevel=0))
    @test(status)
  end

  @testset "Team model" begin
    @testset "Helpers for fixed schedules" begin
      @testset "5-8 schedule" begin
        @test(sum(shiftsFiveEight) == 30) # Ten days, three shifts per day.
        @test(vec(sum(shiftsFiveEight, 1)) == ones(Int64, 30)) # Each shift has a team.
        @test(vec(sum(shiftsFiveEight, 2)) == 6 * ones(Int64, 5)) # Each team works six shifts.
      end

      @testset "Schedule shifting" begin
        @test(shiftFixedSchedule(shiftsFiveEight, 0) == shiftsFiveEight)
        @test(shiftFixedSchedule(shiftsFiveEight, 1) == hcat(shiftsFiveEight[:, 4:end], shiftsFiveEight[:, 1:3]))
        @test(shiftFixedSchedule(shiftsFiveEight, 2) == hcat(shiftsFiveEight[:, 7:end], shiftsFiveEight[:, 1:6]))
        @test(shiftFixedSchedule(shiftsFiveEight, 3) == hcat(shiftsFiveEight[:, 10:end], shiftsFiveEight[:, 1:9]))

        # Shift by a larger amount than the length of the fixed schedule.
        @test(shiftFixedSchedule(shiftsFiveEight, 10) == shiftsFiveEight)
        @test(shiftFixedSchedule(shiftsFiveEight, 11) == shiftFixedSchedule(shiftsFiveEight, 1))
        @test(shiftFixedSchedule(shiftsFiveEight, 12) == shiftFixedSchedule(shiftsFiveEight, 2))
        @test(shiftFixedSchedule(shiftsFiveEight, 13) == shiftFixedSchedule(shiftsFiveEight, 3))
      end
    end
  end
end
