@testset "Optimisation models" begin
  @testset "Specific data structures" begin
    @testset "Timing" begin
      @testset "Basic case" begin
        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)

        @test timing(hrm) == t
        @test timeBeginning(hrm) == timeBeginning(t)
        @test timeHorizon(hrm) == timeHorizon(t)
        @test timeEnding(hrm) == timeEnding(t)
        @test timeStepDuration(hrm) == timeStepDuration(t)
        @test shiftBeginning(hrm) == shiftBeginning(s)
        @test shiftDuration(hrm) == shiftDuration(s)
        @test shiftDurations(hrm) == shiftDurations(s)
        @test shiftDurationsStart(hrm) == shiftDurationsStart(s)
        @test shiftDurationsStep(hrm) == shiftDurationsStep(s)
        @test shiftDurationsStop(hrm) == shiftDurationsStop(s)
        @test nShiftDurations(hrm) == nShiftDurations(s)

        @test nTimeSteps(hrm) == 48
        @test nTimeSteps(hrm, Minute(15)) == 1 # Something that lasts 15 minutes has to be represented as one time step here (even though it is much shorter than one hour).
        @test nTimeSteps(hrm, Day(1)) == 24
        @test nTimeStepsPerShift(hrm) == [8] # Only one shift length available, hence a singleton (but not a scalar).
        @test nShifts(hrm) == 6

        @test_throws(ErrorException, dateToTimeStep(hrm, date - Hour(1)))
        @test dateToTimeStep(hrm, date) == 1
        @test dateToTimeStep(hrm, date + Minute(15)) == 1
        @test dateToTimeStep(hrm, date + Hour(1)) == 2
        @test dateToTimeStep(hrm, date + Hour(8)) == 9 # One shift.
        @test dateToTimeStep(hrm, date + Hour(47)) == 48 # Optimisation horizon.

        @test_throws(ErrorException, dateToShift(hrm, date - Hour(1)))
        @test dateToShift(hrm, date) == 1
        @test dateToShift(hrm, date + Hour(5)) == 1
        @test dateToShift(hrm, date + Hour(7)) == 1
        @test dateToShift(hrm, date + Hour(8)) == 2
        @test dateToShift(hrm, date + Hour(12)) == 2

        # Optimisation variable accessors.
        @test shiftOpen(hrm, 1) == hrm.shiftOpen[1]

        @test timeStepOpen(hrm, date) == shiftOpen(hrm, 1)
        @test timeStepOpen(hrm, date + Minute(15)) == shiftOpen(hrm, 1)
        @test timeStepOpen(hrm, date + Hour(15)) == shiftOpen(hrm, 2)
      end

      @testset "Beginning of the shifts is four hours before the optimisation" begin
        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1))
        s = Shifts(t, date - Hour(4), Hour(8))
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)

        @test_throws(ErrorException, dateToShift(hrm, date - Hour(4) - Hour(1)))
        @test dateToShift(hrm, date - Hour(4)) == 1
        @test dateToShift(hrm, date - Hour(4) + Hour(5)) == 1
        @test dateToShift(hrm, date - Hour(4) + Hour(7)) == 1
        @test dateToShift(hrm, date - Hour(4) + Hour(8)) == 2
        @test dateToShift(hrm, date - Hour(4) + Hour(12)) == 2
      end
    end

    @testset "Equipment" begin
      @testset "One product, one time step" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

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

        # Accessing variables (low level).
        for em in [eqm, inm, oum]
          @test(quantity(em) == em.quantity)
        end
        @test(flowIn(eqm) == eqm.flowIn)
        @test(flowOut(eqm) == eqm.flowOut)
        @test(on(eqm) == eqm.on)
        @test(start(eqm) == eqm.start)
        @test(currentProduct(eqm) == eqm.currentProduct)
        for em in [inm, oum]
          @test_throws(MethodError, flowIn(em))
          @test_throws(MethodError, flowOut(em))
          @test_throws(MethodError, on(em))
          @test_throws(MethodError, start(em))
          @test_throws(ErrorException, currentProduct(em))
        end

        # Accessing variables (high level).
        for em in [eqm, inm, oum]
          @test(quantity(em, 1, 1) == em.quantity[1, 1])
        end
        @test(flowIn(eqm, 1, 1) == eqm.flowIn[1, 1])
        @test(flowOut(eqm, 1, 1) == eqm.flowOut[1, 1])
        @test(on(eqm, 1) == eqm.on[1])
        @test(start(eqm, 1) == eqm.start[1])
        @test_throws(ErrorException, currentProduct(eqm, 1, 1)) # Only one product.

        @test_throws(ErrorException, flowIn(inm, 1, 1))
        @test(flowIn(oum, 1, 1) == oum.quantity[1, 1])
        @test(flowOut(inm, 1, 1) == inm.quantity[1, 1])
        @test_throws(ErrorException, flowOut(oum, 1, 1))
        for em in [inm, oum]
          @test_throws(MethodError, on(em, 1))
          @test_throws(MethodError, start(em, 1))
          @test_throws(MethodError, currentProduct(em, 1, 1))
        end

        # Accessing variables (nice level).
        @test_throws(ErrorException, checkDate(eqm, timeBeginning(eqm) - Hour(1), :test))
        @test(checkDate(eqm, timeBeginning(eqm), :test))
        @test(checkDate(eqm, timeEnding(eqm), :test))
        @test_throws(ErrorException, checkDate(eqm, timeEnding(eqm) + Hour(1), :test))

        @test(productId(eqm, p) == 1)

        for em in [eqm, inm, oum]
          @test(quantity(em, date, p) == em.quantity[1, 1])
          @test(quantity(em, date + Hour(1), p) == em.quantity[2, 1])
        end

        @test(flowIn(eqm, date, p) == eqm.flowIn[1, 1])
        @test(flowIn(eqm, date + Hour(1), p) == eqm.flowIn[2, 1])
        @test(flowOut(eqm, date, p) == eqm.flowOut[1, 1])
        @test(flowOut(eqm, date + Hour(1), p) == eqm.flowOut[2, 1])
        @test_throws(ErrorException, flowIn(inm, date, p))
        @test(flowIn(oum, date, p) == oum.quantity[1, 1])
        @test(flowOut(inm, date, p) == inm.quantity[1, 1])
        @test_throws(ErrorException, flowOut(oum, date, p))

        @test(on(eqm, date) == eqm.on[1, 1])
        @test(on(eqm, date + Hour(1)) == eqm.on[2, 1])
        @test(start(eqm, date) == eqm.start[1, 1])
        @test(start(eqm, date + Hour(1)) == eqm.start[2, 1])
        @test_throws(ErrorException, currentProduct(eqm, date, p)) # Only one product.
        @test_throws(ErrorException, currentProduct(eqm, date + Hour(1), p)) # Only one product.

        @test(off(eqm, date) == 1 - eqm.on[1, 1])
        @test(off(eqm, date + Hour(1)) == 1 - eqm.on[2, 1])
        @test_throws(ErrorException, stop(eqm, date))
        @test(stop(eqm, date + Hour(1)) == eqm.on[1, 1])
      end

      @testset "Multiple products, one time step" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

        e = Equipment("EAF", :eaf)
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        p2 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p1, 50), date + Day(3) => (p2, 50)))

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
        for p in [p1, p2]
          @test(maxBatchSize(p, eqm) == maxBatchSize(p, e))
          @test_throws(MethodError, maxBatchSize(p, inm))
          @test_throws(MethodError, maxBatchSize(p, oum))
          @test(minBatchSize(p, eqm) == minBatchSize(p, e))
          @test_throws(MethodError, minBatchSize(p, inm))
          @test_throws(MethodError, minBatchSize(p, oum))
        end

        # Accessing variables (low level).
        for em in [eqm, inm, oum]
          @test(quantity(em) == em.quantity)
        end
        @test(flowIn(eqm) == eqm.flowIn)
        @test(flowOut(eqm) == eqm.flowOut)
        @test(on(eqm) == eqm.on)
        @test(start(eqm) == eqm.start)
        @test(currentProduct(eqm) == eqm.currentProduct)
        for em in [inm, oum]
          @test_throws(MethodError, flowIn(em))
          @test_throws(MethodError, flowOut(em))
          @test_throws(MethodError, on(em))
          @test_throws(MethodError, start(em))
          @test_throws(ErrorException, currentProduct(em))
        end

        # Accessing variables (high level).
        for em in [eqm, inm, oum]
          @test(quantity(em, 1, 1) == em.quantity[1, 1])
        end
        @test(flowIn(eqm, 1, 1) == eqm.flowIn[1, 1])
        @test(flowOut(eqm, 1, 1) == eqm.flowOut[1, 1])
        @test(on(eqm, 1) == eqm.on[1])
        @test(start(eqm, 1) == eqm.start[1])
        @test(currentProduct(eqm, 1, 1) == eqm.currentProduct[1, 1])
        @test(currentProduct(eqm, 1, 2) == eqm.currentProduct[1, 2])

        @test_throws(ErrorException, flowIn(inm, 1, 1))
        @test(flowIn(oum, 1, 1) == oum.quantity[1, 1])
        @test(flowOut(inm, 1, 1) == inm.quantity[1, 1])
        @test_throws(ErrorException, flowOut(oum, 1, 1))
        for em in [inm, oum]
          @test_throws(MethodError, on(em, 1))
          @test_throws(MethodError, start(em, 1))
          @test_throws(MethodError, currentProduct(em, 1, 1))
        end

        # Accessing variables (nice level).
        @test_throws(ErrorException, checkDate(eqm, timeBeginning(eqm) - Hour(1), :test))
        @test(checkDate(eqm, timeBeginning(eqm), :test))
        @test(checkDate(eqm, timeEnding(eqm), :test))
        @test_throws(ErrorException, checkDate(eqm, timeEnding(eqm) + Hour(1), :test))

        @test(all(sort([productId(eqm, p1), productId(eqm, p2)]) .== [1, 2]))

        for em in [eqm, inm, oum]
          for p in [p1, p2]
            @test(quantity(em, date, p) == em.quantity[1, productId(eqm, p)])
            @test(quantity(em, date + Hour(1), p) == em.quantity[2, productId(eqm, p)])
          end
        end

        for p in [p1, p2]
          @test(flowIn(eqm, date, p) == eqm.flowIn[1, productId(eqm, p)])
          @test(flowIn(eqm, date + Hour(1), p) == eqm.flowIn[2, productId(eqm, p)])
          @test(flowOut(eqm, date, p) == eqm.flowOut[1, productId(eqm, p)])
          @test(flowOut(eqm, date + Hour(1), p) == eqm.flowOut[2, productId(eqm, p)])
          @test_throws(ErrorException, flowIn(inm, date, p))
          @test(flowIn(oum, date, p) == oum.quantity[1, productId(eqm, p)])
          @test(flowOut(inm, date, p) == inm.quantity[1, productId(eqm, p)])
          @test_throws(ErrorException, flowOut(oum, date, p))
        end

        @test(on(eqm, date) == eqm.on[1])
        @test(on(eqm, date + Hour(1)) == eqm.on[2])
        @test(start(eqm, date) == eqm.start[1])
        @test(start(eqm, date + Hour(1)) == eqm.start[2])
        for p in [p1, p2]
          @test(currentProduct(eqm, date, p) == eqm.currentProduct[1, productId(eqm, p)])
          @test(currentProduct(eqm, date + Hour(1), p) == eqm.currentProduct[2, productId(eqm, p)])
        end

        @test(off(eqm, date) == 1 - eqm.on[1])
        @test(off(eqm, date + Hour(1)) == 1 - eqm.on[2])
        @test(stop(eqm, date + Hour(1)) == eqm.on[1])
        @test_throws(ErrorException, stop(eqm, date))
      end

      @testset "One product, multiple time steps" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Minute(15))

        e = Equipment("EAF", :eaf) # One-hour duration
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

        # Accessing variables (low level).
        for em in [eqm, inm, oum]
          @test(quantity(em) == em.quantity)
        end
        @test(flowIn(eqm) == eqm.flowIn)
        @test(flowOut(eqm) == eqm.flowOut)
        @test(on(eqm) == eqm.on)
        @test(start(eqm) == eqm.start)
        @test(currentProduct(eqm) == eqm.currentProduct)
        for em in [inm, oum]
          @test_throws(MethodError, flowIn(em))
          @test_throws(MethodError, flowOut(em))
          @test_throws(MethodError, on(em))
          @test_throws(MethodError, start(em))
          @test_throws(ErrorException, currentProduct(em))
        end

        # Accessing variables (high level).
        for em in [eqm, inm, oum]
          @test(quantity(em, 1, 1) == em.quantity[1, 1])
        end
        @test(flowIn(eqm, 1, 1) == eqm.flowIn[1, 1])
        @test(flowOut(eqm, 1, 1) == eqm.flowOut[1, 1])
        @test(on(eqm, 1) == eqm.on[1])
        @test(start(eqm, 1) == eqm.start[1])
        @test_throws(ErrorException, currentProduct(eqm, 1, 1)) # Only one product.

        @test_throws(ErrorException, flowIn(inm, 1, 1))
        @test(flowIn(oum, 1, 1) == oum.quantity[1, 1])
        @test(flowOut(inm, 1, 1) == inm.quantity[1, 1])
        @test_throws(ErrorException, flowOut(oum, 1, 1))
        for em in [inm, oum]
          @test_throws(MethodError, on(em, 1))
          @test_throws(MethodError, start(em, 1))
          @test_throws(MethodError, currentProduct(em, 1, 1))
        end

        # Accessing variables (nice level).
        @test_throws(ErrorException, checkDate(eqm, timeBeginning(eqm) - Hour(1), :test))
        @test(checkDate(eqm, timeBeginning(eqm), :test))
        @test(checkDate(eqm, timeEnding(eqm), :test))
        @test_throws(ErrorException, checkDate(eqm, timeEnding(eqm) + Hour(1), :test))

        @test(productId(eqm, p) == 1)

        for em in [eqm, inm, oum]
          @test(quantity(em, date, p) == em.quantity[1, 1])
          @test(quantity(em, date + Minute(15), p) == em.quantity[2, 1])
          @test(quantity(em, date + Hour(1), p) == em.quantity[5, 1])
        end

        @test(flowIn(eqm, date, p) == eqm.flowIn[1, 1])
        @test(flowIn(eqm, date + Minute(15), p) == eqm.flowIn[2, 1])
        @test(flowIn(eqm, date + Hour(1), p) == eqm.flowIn[5, 1])
        @test(flowOut(eqm, date, p) == eqm.flowOut[1, 1])
        @test(flowOut(eqm, date + Minute(15), p) == eqm.flowOut[2, 1])
        @test(flowOut(eqm, date + Hour(1), p) == eqm.flowOut[5, 1])
        @test_throws(ErrorException, flowIn(inm, date, p))
        @test(flowIn(oum, date, p) == oum.quantity[1, 1])
        @test(flowOut(inm, date, p) == inm.quantity[1, 1])
        @test_throws(ErrorException, flowOut(oum, date, p))

        @test(on(eqm, date) == eqm.on[1, 1])
        @test(on(eqm, date + Minute(15)) == eqm.on[2, 1])
        @test(on(eqm, date + Hour(1)) == eqm.on[5, 1])
        @test(start(eqm, date) == eqm.start[1, 1])
        @test(start(eqm, date + Minute(15)) == eqm.start[2, 1])
        @test(start(eqm, date + Hour(1)) == eqm.start[5, 1])
        @test_throws(ErrorException, currentProduct(eqm, date, p)) # Only one product.
        @test_throws(ErrorException, currentProduct(eqm, date + Hour(1), p)) # Only one product.

        @test(off(eqm, date) == 1 - eqm.on[1, 1])
        @test(off(eqm, date + Minute(15)) == 1 - eqm.on[2, 1])
        @test(off(eqm, date + Hour(1)) == 1 - eqm.on[5, 1])
        @test_throws(ErrorException, stop(eqm, date))
        @test_throws(ErrorException, stop(eqm, date + Minute(15)))
        @test(stop(eqm, date + Hour(1)) == eqm.start[1, 1])
      end

      @testset "One product, multiple time steps" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Minute(15))

        e = Equipment("EAF", :eaf) # One-hour duration
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        p2 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p1, 50), date + Day(3) => (p2, 50)))

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
        for p in [p1, p2]
          @test(maxBatchSize(p, eqm) == maxBatchSize(p, e))
          @test_throws(MethodError, maxBatchSize(p, inm))
          @test_throws(MethodError, maxBatchSize(p, oum))
          @test(minBatchSize(p, eqm) == minBatchSize(p, e))
          @test_throws(MethodError, minBatchSize(p, inm))
          @test_throws(MethodError, minBatchSize(p, oum))
        end

        # Accessing variables (low level).
        for em in [eqm, inm, oum]
          @test(quantity(em) == em.quantity)
        end
        @test(flowIn(eqm) == eqm.flowIn)
        @test(flowOut(eqm) == eqm.flowOut)
        @test(on(eqm) == eqm.on)
        @test(start(eqm) == eqm.start)
        @test(currentProduct(eqm) == eqm.currentProduct)
        for em in [inm, oum]
          @test_throws(MethodError, flowIn(em))
          @test_throws(MethodError, flowOut(em))
          @test_throws(MethodError, on(em))
          @test_throws(MethodError, start(em))
          @test_throws(ErrorException, currentProduct(em))
        end

        # Accessing variables (high level).
        for em in [eqm, inm, oum]
          @test(quantity(em, 1, 1) == em.quantity[1, 1])
        end
        @test(flowIn(eqm, 1, 1) == eqm.flowIn[1, 1])
        @test(flowOut(eqm, 1, 1) == eqm.flowOut[1, 1])
        @test(on(eqm, 1) == eqm.on[1])
        @test(start(eqm, 1) == eqm.start[1])
        @test(currentProduct(eqm, 1, 1) == eqm.currentProduct[1, 1])
        @test(currentProduct(eqm, 1, 2) == eqm.currentProduct[1, 2])

        @test_throws(ErrorException, flowIn(inm, 1, 1))
        @test(flowIn(oum, 1, 1) == oum.quantity[1, 1])
        @test(flowOut(inm, 1, 1) == inm.quantity[1, 1])
        @test_throws(ErrorException, flowOut(oum, 1, 1))
        for em in [inm, oum]
          @test_throws(MethodError, on(em, 1))
          @test_throws(MethodError, start(em, 1))
          @test_throws(MethodError, currentProduct(em, 1, 1))
        end

        # Accessing variables (nice level).
        @test_throws(ErrorException, checkDate(eqm, timeBeginning(eqm) - Hour(1), :test))
        @test(checkDate(eqm, timeBeginning(eqm), :test))
        @test(checkDate(eqm, timeEnding(eqm), :test))
        @test_throws(ErrorException, checkDate(eqm, timeEnding(eqm) + Hour(1), :test))

        @test(all(sort([productId(eqm, p1), productId(eqm, p2)]) .== [1, 2]))

        for em in [eqm, inm, oum]
          for p in [p1, p2]
            @test(quantity(em, date, p) == em.quantity[1, productId(eqm, p)])
            @test(quantity(em, date + Minute(15), p) == em.quantity[2, productId(eqm, p)])
            @test(quantity(em, date + Hour(1), p) == em.quantity[5, productId(eqm, p)])
          end
        end

        for p in [p1, p2]
          @test(flowIn(eqm, date, p) == eqm.flowIn[1, productId(eqm, p)])
          @test(flowIn(eqm, date + Minute(15), p) == eqm.flowIn[2, productId(eqm, p)])
          @test(flowIn(eqm, date + Hour(1), p) == eqm.flowIn[5, productId(eqm, p)])
          @test(flowOut(eqm, date, p) == eqm.flowOut[1, productId(eqm, p)])
          @test(flowOut(eqm, date + Minute(15), p) == eqm.flowOut[2, productId(eqm, p)])
          @test(flowOut(eqm, date + Hour(1), p) == eqm.flowOut[5, productId(eqm, p)])
          @test_throws(ErrorException, flowIn(inm, date, p))
          @test(flowIn(oum, date, p) == oum.quantity[1, productId(eqm, p)])
          @test(flowOut(inm, date, p) == inm.quantity[1, productId(eqm, p)])
          @test_throws(ErrorException, flowOut(oum, date, p))
        end

        @test(on(eqm, date) == eqm.on[1, 1])
        @test(on(eqm, date + Minute(15)) == eqm.on[2, 1])
        @test(on(eqm, date + Hour(1)) == eqm.on[5, 1])
        @test(start(eqm, date) == eqm.start[1, 1])
        @test(start(eqm, date + Minute(15)) == eqm.start[2, 1])
        @test(start(eqm, date + Hour(1)) == eqm.start[5, 1])
        for p in [p1, p2]
          @test(currentProduct(eqm, date, p) == eqm.currentProduct[1, productId(eqm, p)])
          @test(currentProduct(eqm, date + Minute(15), p) == eqm.currentProduct[2, productId(eqm, p)])
          @test(currentProduct(eqm, date + Hour(1), p) == eqm.currentProduct[5, productId(eqm, p)])
        end

        @test(off(eqm, date) == 1 - eqm.on[1, 1])
        @test(off(eqm, date + Minute(15)) == 1 - eqm.on[2, 1])
        @test(off(eqm, date + Hour(1)) == 1 - eqm.on[5, 1])
        @test_throws(ErrorException, stop(eqm, date))
        @test_throws(ErrorException, stop(eqm, date + Minute(15)))
        @test(stop(eqm, date + Hour(1)) == eqm.start[1, 1])
      end
    end

    @testset "Consumption" begin
      @testset "No consumption" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        e = Equipment("EAF", :eaf)

        c = NoConsumption()
        p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

        m = Model(solver=CbcSolver(logLevel=0))
        eqm = EquipmentModel(m, e, t, ob)

        @test(consumption(eqm, p, date + Day(2)) == 0.0)
        @test(consumption(eqm, p, date + Day(2)) == consumption(eqm, p, consumption(p, e), date + Day(2)))
      end

      @testset "Constant consumption" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        e = Equipment("EAF", :eaf)

        c = ConstantConsumption(2.0)
        p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

        m = Model(solver=CbcSolver(logLevel=0))
        eqm = EquipmentModel(m, e, t, ob)

        @test(consumption(eqm, p, date + Day(2)) == 2 * on(eqm, date + Day(2)))
        @test(consumption(eqm, p, date + Day(2)) == consumption(eqm, p, consumption(p, e), date + Day(2)))
      end

      @testset "Linear consumption" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        e = Equipment("EAF", :eaf)

        c = LinearConsumption(2.0, 4.0)
        p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

        m = Model(solver=CbcSolver(logLevel=0))
        eqm = EquipmentModel(m, e, t, ob)

        @test(consumption(eqm, p, date + Day(2)) == 2 * on(eqm, date + Day(2)) + 4 * quantity(eqm, date + Day(2), p))
        @test(consumption(eqm, p, date + Day(2)) == consumption(eqm, p, consumption(p, e), date + Day(2)))
      end

      @testset "Quadratic consumption" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        e = Equipment("EAF", :eaf)

        c = QuadraticConsumption(2.0, 4.0, 8.0)
        p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

        m = Model(solver=CbcSolver(logLevel=0))
        eqm = EquipmentModel(m, e, t, ob)

        @test(consumption(eqm, p, date + Day(2)) == 2 * on(eqm, date + Day(2)) + 4 * quantity(eqm, date + Day(2), p) + 8 * quantity(eqm, date + Day(2), p) ^ 2)
        @test(consumption(eqm, p, date + Day(2)) == consumption(eqm, p, consumption(p, e), date + Day(2)))
      end

      @testset "Piecewise linear consumption" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        e = Equipment("EAF", :eaf)

        c = PiecewiseLinearConsumption([1.0, 2.0], [4.0, 8.0])
        p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

        m = Model(solver=CbcSolver(logLevel=0))
        eqm = EquipmentModel(m, e, t, ob)

        @test_broken(consumption(eqm, p, date + Day(2)) == 0.0)
        @test_broken(consumption(eqm, p, date + Day(2)) == consumption(eqm, p, consumption(p, e), date + Day(2)))
      end
    end

    @testset "Order book" begin
      date = DateTime(2010, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

      e = Equipment("EAF", :eaf)
      c = ConstantConsumption(2.0)
      p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

      m = Model(solver=CbcSolver(logLevel=0))
      obm = OrderBookModel(m, ob, t)

      # Basic accessors.
      @test orderBook(obm) == ob
      @test timing(obm) == t

      # Link to the methods of Timing.
      @test timeBeginning(obm) == timeBeginning(t)
      @test timeHorizon(obm) == timeHorizon(t)
      @test timeEnding(obm) == timeEnding(t)
      @test timeStepDuration(obm) == timeStepDuration(t)

      @test nTimeSteps(obm, Minute(15)) == nTimeSteps(t, Minute(15))
      @test nTimeSteps(obm, Hour(1)) == nTimeSteps(t, Hour(1))
      @test nTimeSteps(obm, Day(1)) == nTimeSteps(t, Day(1))
      @test nTimeSteps(obm) == nTimeSteps(t)
      @test_throws(ErrorException, dateToTimeStep(obm, date - Hour(1)))
      @test(dateToTimeStep(obm, date) == dateToTimeStep(t, date))
      @test(dateToTimeStep(obm, date + Hour(1)) == dateToTimeStep(t, date + Hour(1)))

      @test eachTimeStep(obm) == eachTimeStep(t)
      @test eachTimeStep(obm, from=timeBeginning(t) + Day(3)) == eachTimeStep(t, from=timeBeginning(t) + Day(3))
      @test eachTimeStep(obm, to=timeBeginning(t) + Day(3)) == eachTimeStep(t, to=timeBeginning(t) + Day(3))
      @test eachTimeStep(obm, duration=Day(4)) == eachTimeStep(t, duration=Day(4))
      @test_throws(ErrorException, eachTimeStep(obm, to=date, duration=date)) # Can't set both
      @test_throws(ErrorException, eachTimeStep(obm, duration=date)) # Bad type for duration
      @test_throws(ErrorException, eachTimeStep(obm, to=Hour(1))) # Bad type for to
      @test_throws(ErrorException, eachTimeStep(obm, thiskeywordparameterdoesnotexist=Hour(1))) # Unknown keyword argument
      @test_throws(ErrorException, eachTimeStep(obm, to=1)) # Invalid argument type.
      @test_throws(ErrorException, eachTimeStep(obm, from=date, to=date, duration=date)) # Can't set all parameters at once
      @test_throws(ErrorException, eachTimeStep(obm, from=date, duration=date)) # Bad type for duration
      @test_throws(ErrorException, eachTimeStep(obm, from=date, to=Hour(1))) # Bad type for to
      @test_throws(ErrorException, eachTimeStep(obm, from=date, thiskeywordparameterdoesnotexist=Hour(1))) # Unknown keyword argument
      @test_throws(TypeError, eachTimeStep(obm, from=1)) # Invalid argument type.

      # Link to the methods of OrderBook.
      @test orderBookDetails(obm) == orderBook(ob)
      @test dates(obm) == dates(ob)
      @test products(obm) == products(ob)
      @test nProducts(obm) == nProducts(ob)
      @test(dueBy(obm, DateTime(2009)) == dueBy(ob, DateTime(2009)))
      @test(dueBy(obm, DateTime(2010)) == dueBy(ob, DateTime(2010)))
      @test(dueBy(obm, DateTime(2011)) == dueBy(ob, DateTime(2011)))
      @test(dueBy(obm, DateTime(2012)) == dueBy(ob, DateTime(2012)))
      @test(dueBy(obm, DateTime(2009)) == dueBy(ob, DateTime(2009)))
      @test(dueBy(obm, DateTime(2010)) == dueBy(ob, DateTime(2010)))
      @test(dueBy(obm, DateTime(2011)) == dueBy(ob, DateTime(2011)))
      @test(dueBy(obm, DateTime(2012)) == dueBy(ob, DateTime(2012)))
      @test(dueBy(obm, DateTime(2009), cumulative=false) == dueBy(ob, DateTime(2009), cumulative=false))
      @test(dueBy(obm, DateTime(2010), cumulative=false) == dueBy(ob, DateTime(2010), cumulative=false))
      @test(dueBy(obm, DateTime(2011), cumulative=false) == dueBy(ob, DateTime(2011), cumulative=false))
      @test(dueBy(obm, DateTime(2012), cumulative=false) == dueBy(ob, DateTime(2012), cumulative=false))
      @test(dueBy(fromto(obm, DateTime(2010), DateTime(2011)), DateTime(2012)) == dueBy(fromto(ob, DateTime(2010), DateTime(2011)), DateTime(2012)))
      @test(dueBy(fromto(obm, DateTime(2009), DateTime(2010)), DateTime(2012)) == dueBy(fromto(ob, DateTime(2009), DateTime(2010)), DateTime(2012)))
      @test(dueBy(fromto(obm, DateTime(2011), DateTime(2012)), DateTime(2012)) == dueBy(fromto(ob, DateTime(2011), DateTime(2012)), DateTime(2012)))
      @test(dueBy(fromto(obm, DateTime(2008), DateTime(2009)), DateTime(2012)) == dueBy(fromto(ob, DateTime(2008), DateTime(2009)), DateTime(2012)))
      @test productIds(obm) == productIds(ob)
      @test productId(obm, p) == productId(ob, p)
      @test productFromId(obm, 1) == productFromId(ob, 1)

      # Test with multiple products.
      p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      p2 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p1, 50), date + Day(4) => (p2, 50)))

      m = Model(solver=CbcSolver(logLevel=0))
      obm = OrderBookModel(m, ob, t)

      @test productIds(obm) == productIds(ob)
      @test productId(obm, p1) == productId(ob, p1)
      @test productId(obm, p2) == productId(ob, p2)
      @test productFromId(obm, 1) == productFromId(ob, 1)
      @test productFromId(obm, 2) == productFromId(ob, 2)

      # Warn when orders before the beginning of Timing or after its end.
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date - Day(2) => (p, 50)))
      @test_warn "The latest order is at $(latest(ob)), but the optimisation starts later, at $(timeBeginning(t))." OrderBookModel(m, ob, t)

      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Week(2) => (p, 50)))
      @test_warn "The earliest order is at $(earliest(ob)), but the optimisation ends sooner, at $(timeEnding(t))." OrderBookModel(m, ob, t)
    end

    @testset "Objective" begin
      @testset "Dummy objective" begin
        e = Equipment("EAF", :eaf)
        p = Plant([e], Route[])
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (120.0, 150.0)))

        date = DateTime(2017, 01, 01, 08)
        ob = OrderBook(Dict(date + Hour(1) => (p1, 50.)))
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        pm = PlantModel(m, p, ob, t, s)

        dobj = DummyProductionObjective()
        @test objectiveTimeStep(m, dobj, pm, date) == AffExpr()
        @test objectiveTimeStep(m, dobj, pm, date + Hour(1)) == AffExpr()
        @test objectiveShift(m, dobj, pm, date) == AffExpr()
        @test objectiveShift(m, dobj, pm, date + Hour(8)) == AffExpr()
        @test objective(m, dobj, pm) == AffExpr()
        @test objective(m, dobj, pm, date + Hour(1), date + Hour(8)) == AffExpr()
      end

      @testset "No objective" begin
        e = Equipment("EAF", :eaf)
        p = Plant([e], Route[])
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (120.0, 150.0)))

        date = DateTime(2017, 01, 01, 08)
        ob = OrderBook(Dict(date + Hour(1) => (p1, 50.)))
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        pm = PlantModel(m, p, ob, t, s)

        dobj = NoObjective()
        @test objectiveTimeStep(m, dobj, pm, date) == AffExpr()
        @test objectiveTimeStep(m, dobj, pm, date + Hour(1)) == AffExpr()
        @test objectiveShift(m, dobj, pm, date) == AffExpr()
        @test objectiveShift(m, dobj, pm, date + Hour(8)) == AffExpr()
        @test objective(m, dobj, pm) == AffExpr()
        @test objective(m, dobj, pm, date + Hour(1), date + Hour(8)) == AffExpr()
      end

      @testset "Energy objective: normal case" begin
        e = Equipment("EAF", :eaf)
        p = Plant([e], Route[])
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (120.0, 150.0)))

        date = DateTime(2017, 01, 01, 08)
        ob = OrderBook(Dict(date + Hour(1) => (p1, 50.)))
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        pm = PlantModel(m, p, ob, t, s)

        ep = [rand() for _ in eachTimeStep(t)]
        ep_ts = TimeArray(collect(eachTimeStep(t)), ep)
        dobj = EnergyObjective(ep_ts, t)

        @test electricityPrice(dobj) == ep_ts
        @test electricityPrice(dobj, date) == ep[1]
        @test electricityPrice(dobj, date + Hour(1)) == ep[2]
        @test_broken electricityPrice(dobj, date - Hour(1)) # TODO: Should fail with an error.
        @test_broken electricityPrice(dobj, date + Week(1) + Hour(1)) # TODO: Should fail with an error.

        eq = collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, values(equipmentModels(pm))))[1]
        @test objective(m, dobj, pm) == sum(values(ep_ts[ts])[1] * consumption(eq, p1, ts) for ts in eachTimeStep(t))
        @test objective(m, dobj, pm, date + Hour(1), date + Hour(8)) == sum(ep[ts + 1] * consumption(eq, p1, date + Hour(ts)) for ts in 1:7)
      end

      @testset "Energy objective: not enough data" begin
        e = Equipment("EAF", :eaf)
        p = Plant([e], Route[])
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (120.0, 150.0)))

        date = DateTime(2017, 01, 01, 08)
        ob = OrderBook(Dict(date + Hour(1) => (p1, 50.)))
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        pm = PlantModel(m, p, ob, t, s)

        ep = [rand() for _ in eachTimeStep(t)][4:end]
        ep_ts = TimeArray(collect(eachTimeStep(t))[4:end], ep)
        @test EnergyObjective(ep_ts) == EnergyObjective(ep_ts) # Basic constructor performs no check and sees no error.
        @test_throws ErrorException EnergyObjective(ep_ts, t) # The main constructor checks for consistency.
      end

      @testset "HR objective" begin
        e = Equipment("EAF", :eaf)
        p = Plant([e], Route[])
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (120.0, 150.0)))

        date = DateTime(2017, 01, 01, 08)
        ob = OrderBook(Dict(date + Hour(1) => (p1, 50.)))
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        pm = PlantModel(m, p, ob, t, s)
        hrm = timingModel(pm)

        f = (d::DateTime) -> Dates.hour(d)
        o = HRCostObjective(f)

        @test objectiveShift(m, o, pm, date) == sum(f(dt) for dt in date : Hour(1) : date + Hour(7)) * shiftOpen(hrm, date)
        @test_throws ErrorException objectiveShift(m, o, pm, date + Hour(1)) # Not the beginning of a shift.

        f = (d::DateTime) -> 0.0
        o = HRCostObjective(f)

        @test objectiveShift(m, o, pm, date) == AffExpr()
        @test_throws ErrorException objectiveShift(m, o, pm, date + Hour(1)) # Not the beginning of a shift.
      end

      @testset "Objective combination" begin
        e = Equipment("EAF", :eaf)
        p = Plant([e], Route[])
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (120.0, 150.0)))

        date = DateTime(2017, 01, 01, 08)
        ob = OrderBook(Dict(date + Hour(1) => (p1, 50.)))
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        pm = PlantModel(m, p, ob, t, s)
        hrm = timingModel(pm)

        f = (d::DateTime) -> Dates.hour(d)
        hro = HRCostObjective(f)

        ep = [rand() for _ in eachTimeStep(t)]
        ep_ts = TimeArray(collect(eachTimeStep(t)), ep)
        eo = EnergyObjective(ep_ts, t)

        co = ObjectiveCombination([hro, eo], [.5, .75], symbols=[:hr, :en])
      end
    end

    @testset "Plant" begin
      @testset "Base case" begin
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
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
        p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
        ob = OrderBook(Dict(DateTime(2017, 01, 30) => (p1, 50.), DateTime(2017, 01, 31) => (p2, 50.)))

        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        pm = PlantModel(m, p, ob, t, s)

        # Basic accessors.
        @test plant(pm) == p
        @test orderBook(pm) == ob
        @test timing(pm) == t
        @test shifts(pm) == s

        @test timingModel(pm) == pm.hr
        @test equipmentModels(pm) == pm.equipments
        @test flowModels(pm) == pm.flows
        @test orderBookModel(pm) == pm.ob
        
        @test nEquipments(pm) == 5 # 2 implicit, 3 normal

        # Finding things. 
        equips = collect(values(equipmentModels(pm)))
        @test equipmentModel(pm, "EAF") == equips[find((e) -> name(e) == "EAF", equips)[1]]
        @test equipmentModel(pm, "LF")  == equips[find((e) -> name(e) == "LF",  equips)[1]]
        @test equipmentModel(pm, "CC")  == equips[find((e) -> name(e) == "CC",  equips)[1]]
        @test_throws(ErrorException, equipmentModel(pm, "stuff"))

        flows = collect(values(flowModels(pm)))
        @test flowModel(pm, "EAF", "LF") == flows[find((f) -> name(origin(f)) == "EAF" && name(destination(f)) == "LF", flows)[1]]
        @test flowModel(pm, "LF", "CC") == flows[find((f) -> name(origin(f)) == "LF" && name(destination(f)) == "CC", flows)[1]]
        @test_throws(ErrorException, flowModel(pm, "EAF", "CC"))
        @test_throws(ErrorException, flowModel(pm, "EAF", "stuff"))
        @test flowModel(pm, ("EAF", "LF")) == flows[find((f) -> name(origin(f)) == "EAF" && name(destination(f)) == "LF", flows)[1]]
        @test flowModel(pm, ("LF", "CC")) == flows[find((f) -> name(origin(f)) == "LF" && name(destination(f)) == "CC", flows)[1]]
        @test_throws(ErrorException, flowModel(pm, ("EAF", "CC")))
        @test_throws(ErrorException, flowModel(pm, ("EAF", "stuff")))

        # Link to the methods of Timing. 
        @test timeBeginning(pm) == timeBeginning(t)
        @test timeHorizon(pm) == timeHorizon(t)
        @test timeEnding(pm) == timeEnding(t)
        @test timeStepDuration(pm) == timeStepDuration(t)

        @test nTimeSteps(pm, Minute(15)) == nTimeSteps(t, Minute(15))
        @test nTimeSteps(pm, Hour(1)) == nTimeSteps(t, Hour(1))
        @test nTimeSteps(pm, Day(1)) == nTimeSteps(t, Day(1))
        @test nTimeSteps(pm) == nTimeSteps(t)
        @test_throws(ErrorException, dateToTimeStep(pm, date - Hour(1)))
        @test dateToTimeStep(pm, date) == dateToTimeStep(t, date)
        @test dateToTimeStep(pm, date + Hour(1)) == dateToTimeStep(t, date + Hour(1))

        @test eachTimeStep(pm) == eachTimeStep(t)
        @test eachTimeStep(pm, from=timeBeginning(t) + Day(3)) == eachTimeStep(t, from=timeBeginning(t) + Day(3))
        @test eachTimeStep(pm, to=timeBeginning(t) + Day(3)) == eachTimeStep(t, to=timeBeginning(t) + Day(3))
        @test eachTimeStep(pm, duration=Day(4)) == eachTimeStep(t, duration=Day(4))
        @test_throws(ErrorException, eachTimeStep(pm, to=date, duration=date)) # Can't set both
        @test_throws(ErrorException, eachTimeStep(pm, duration=date)) # Bad type for duration
        @test_throws(ErrorException, eachTimeStep(pm, to=Hour(1))) # Bad type for to
        @test_throws(ErrorException, eachTimeStep(pm, thiskeywordparameterdoesnotexist=Hour(1))) # Unknown keyword argument
        @test_throws(ErrorException, eachTimeStep(pm, to=1)) # Invalid argument type.
        @test_throws(ErrorException, eachTimeStep(pm, from=date, to=date, duration=date)) # Can't set all parameters at once
        @test_throws(ErrorException, eachTimeStep(pm, from=date, duration=date)) # Bad type for duration
        @test_throws(ErrorException, eachTimeStep(pm, from=date, to=Hour(1))) # Bad type for to
        @test_throws(ErrorException, eachTimeStep(pm, from=date, thiskeywordparameterdoesnotexist=Hour(1))) # Unknown keyword argument
        @test_throws(TypeError, eachTimeStep(pm, from=1)) # Invalid argument type.

        # Link to the methods of Shifts. 
        @test shiftBeginning(pm) == shiftBeginning(s)
        @test shiftDuration(pm) == shiftDuration(s)
        @test shiftDurations(pm) == shiftDurations(s)
        @test shiftDurationsStart(pm) == shiftDurationsStart(s)
        @test shiftDurationsStep(pm) == shiftDurationsStep(s)
        @test shiftDurationsStop(pm) == shiftDurationsStop(s)
        @test minimumShiftDurations(pm) == minimumShiftDurations(s)
        @test maximumShiftDurations(pm) == maximumShiftDurations(s)
        @test nShiftDurations(pm) == nShiftDurations(s)

        # Link to the methods of OrderBook.
        @test orderBookDetails(pm) == orderBook(ob)
        @test dates(pm) == dates(ob)
        @test products(pm) == products(ob)
        @test nProducts(pm) == nProducts(ob)
        @test dueBy(pm, DateTime(2016)) == dueBy(ob, DateTime(2016))
        @test dueBy(pm, DateTime(2017)) == dueBy(ob, DateTime(2017))
        @test dueBy(pm, DateTime(2018)) == dueBy(ob, DateTime(2018))
        @test dueBy(pm, DateTime(2016), cumulative=false) == dueBy(ob, DateTime(2016), cumulative=false)
        @test dueBy(pm, DateTime(2017), cumulative=false) == dueBy(ob, DateTime(2017), cumulative=false)
        @test dueBy(pm, DateTime(2018), cumulative=false) == dueBy(ob, DateTime(2018), cumulative=false)
        @test productIds(pm) == productIds(ob)
        @test productId(pm, p1) == productId(ob, p1)
        @test productId(pm, p2) == productId(ob, p2)
        @test productFromId(pm, 1) == productFromId(ob, 1)
        @test productFromId(pm, 2) == productFromId(ob, 2)
      end
      
      @testset "Error case: missing equipment in the plant" begin
        e1 = Equipment("EAF", :eaf)
        e2 = Equipment("LF", :lf)
        e3 = Equipment("CC", :cc) # Not in the plant, but used by the order book products. 
        r1 = NormalRoute(e1, e2)
        le = [e1, e2]
        lr = Route[r1]
        p = Plant(le, lr)

        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
        p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in [e1, e2, e3]]))
        ob = OrderBook(Dict(DateTime(2017, 01, 30) => (p1, 50.), DateTime(2017, 01, 31) => (p2, 50.)))

        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        @test_throws ErrorException PlantModel(m, p, ob, t, s)
      end
      
      @testset "Error case: missing route in the plant (origin)" begin
        e1 = Equipment("EAF", :eaf)
        e2 = Equipment("LF", :lf)
        r1 = NormalRoute(e1, e2)
        le = [e1, e2]
        lr = Route[r1]
        p = Plant(le, lr)

        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e2 => (120.0, 150.0))) # No e1: no path in -> e2!
        p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e2 => (120.0, 150.0)))
        ob = OrderBook(Dict(DateTime(2017, 01, 30) => (p1, 50.), DateTime(2017, 01, 31) => (p2, 50.)))

        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        @test_throws ErrorException PlantModel(m, p, ob, t, s)
      end
      
      @testset "Error case: missing route in the plant (destination)" begin
        e1 = Equipment("EAF", :eaf)
        e2 = Equipment("LF", :lf)
        r1 = NormalRoute(e1, e2)
        le = [e1, e2]
        lr = Route[r1]
        p = Plant(le, lr)

        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (120.0, 150.0))) # No e2: no path e1 -> out!
        p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (120.0, 150.0)))
        ob = OrderBook(Dict(DateTime(2017, 01, 30) => (p1, 50.), DateTime(2017, 01, 31) => (p2, 50.)))

        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        m = Model(solver=CbcSolver(logLevel=0))
        @test_throws ErrorException PlantModel(m, p, ob, t, s)
      end
    end
  end

  @testset "Model building blocks (postConstraints)" begin
    @testset "Timing" begin
      # model/ds/timing.jl, postConstraints(m::Model, hr::TimingModel, forcedShifts::Array{Tuple{DateTime, Hour, Int}, 1}=Tuple{DateTime, Hour, Int}[])
      @testset "Shifts and optimisation starts simultaneously" begin
        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        # Check the constraints behave as expected.
        # First shift 8:00-16:00: if the second time step is open, then the shift is open. (Actually, this constraint is
        # automatically rewritten as a shift opening.)
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)
        postConstraints(m, hrm)
        @constraint(m, timeStepOpen(hrm, date + Hour(1)) == 1.)
        solve(m)
        @test(getvalue(shiftOpen(hrm, 1)) == 1.0)

        # If the shift 16:00-0:00 is open, and if only one shift is allowed, then the maximum number of time steps is eight.
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)
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
        t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1))
        s = Shifts(t, date - Hour(4), Hour(8))

        # If the first shift is open, can work at most four hours.
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)
        postConstraints(m, hrm)
        @constraint(m, shiftOpen(hrm, 1) == 1.)
        for i in 2:nShifts(hrm)
          @constraint(m, shiftOpen(hrm, i) == 0.)
        end
        @objective(m, Max, sum([shiftOpen(hrm, i) for i in 1:nShifts(hrm)]))
        solve(m)
        @test(getobjectivevalue(m) == 1.)
      end

      @testset "Shifts being forced" begin
        date = DateTime(2017, 01, 01, 08)
        t = Timing(timeBeginning=date, timeHorizon=Day(2), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        # Dummy objective: first, try to minimise the assignment at a given shift (i.e. no team). 
        # Second test: force this shift, same objective, see that it is not assigned. 
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)
        postConstraints(m, hrm)
        @objective(m, Min, shiftOpen(hrm, date))
        solve(m)
        @test(getobjectivevalue(m) == 0.)
        
        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)
        postConstraints(m, hrm, [(date, Hour(8), 1)])
        @objective(m, Min, shiftOpen(hrm, date))
        solve(m)
        @test(getobjectivevalue(m) == 1.)
      end
    end

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
    
    @testset "Each piece of equipment" begin
      # model/ds/equipment.jl, postConstraints(m::Model, eq::EquipmentModel, hrm::TimingModel)
      @testset "One process, one time step, one product" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        getModel(trf=1.) = begin
          e = Equipment("EAF", :eaf, trf, Hour(1), 0.0, 1.e6, Hour(2))
          #                                                   ^^^^^^^
          c = ConstantConsumption(2.0)
          p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 150.0)))
          ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

          m = Model(solver=CbcSolver(logLevel=0))
          hrm = TimingModel(m, t, s)
          eqm = EquipmentModel(m, e, t, ob)
          inm = EquipmentModel(m, inEquipment, t, ob)
          outm = EquipmentModel(m, outEquipment, t, ob)
          eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eqm, "out" => outm)

          postConstraints(m, hrm)
          postConstraints(m, hrm, collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, [eqm, inm, outm]))) # Same filtering as in model/production.jl. 
          postConstraints(m, eqm, hrm)
          postConstraints(m, FlowModel(m, inEquipment, e, t, ob, maxValue=150.), eqms)
          postConstraints(m, FlowModel(m, e, outEquipment, t, ob, maxValue=150.), eqms)

          return e, c, p, ob, m, hrm, eqm, inm, outm
        end
        
        @testset "Link between pieces of equipment and timing" begin
          # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

          @testset "If all time steps are disabled, then no machine may run, at any time" begin
            e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
            @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
            solve(m)
            @test getobjectivevalue(m) == 0.
          end

          @testset "If one time step is allowed, then the machines may run at that time step" begin
            e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
            @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
            solve(m)

            @test getobjectivevalue(m) == 8.
            @test sum(getvalue([on(eqm, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) == 8. 
          end
        end
        
        @testset "Flows" begin
          @testset "In and out flows without transformation rate" begin
            e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowIn(outm, d, p) for d in eachTimeStep(hrm)))
            solve(m)

            # At the beginning of the horizon, may have no output (just initial conditions). 
            @test getvalue(flowOut(eqm, date, p)) == 0.

            # Flows between processes are not affected by any transformation rate. 
            @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
            @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

            # Effect on the overall values. 
            @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) == 16 * 150. / 2
            @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 150. / 2 atol=1.e-5
          end
          
          @testset "In and out flows with transformation rate" begin
            e, c, p, ob, m, hrm, eqm, inm, outm = getModel(.99)
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowOut(inm, d, p) for d in eachTimeStep(hrm)))
            solve(m)

            # At the beginning of the horizon, may have no output (just initial conditions). 
            @test getvalue(flowOut(eqm, date, p)) == .0

            # Flows between processes are not affected by any transformation rate, even though there is one applied. 
            @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
            @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

            # Flows at the borders of a process are affected by the transformation rate. 
            # Time shift between the input and the output for the same process! 
            @test .99 * getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])[1:end-2] ≈ getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)])[3:end] atol=1.e-4
            
            # Effect on the overall values, with the transformation rates at the output. 
            @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 150. / 2 * .99 atol=1.e-4 
            @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 150. / 2 atol=1.e-4
          end
        end
      end
    
      @testset "Two processes, one time step, one product" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        getModel(trfEAF=1., trfLF=1.) = begin
          e1 = Equipment("EAF", :eaf, trfEAF)
          e2 = Equipment("LF", :lf, trfLF)
          c = ConstantConsumption(2.0)
          p = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 155.0), e2 => (150.0, 155.0)))
          ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

          m = Model(solver=CbcSolver(logLevel=0))
          hrm = TimingModel(m, t, s)
          eq1m = EquipmentModel(m, e1, t, ob)
          eq2m = EquipmentModel(m, e2, t, ob)
          inm = EquipmentModel(m, inEquipment, t, ob)
          outm = EquipmentModel(m, outEquipment, t, ob)
          eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eq1m, "LF" => eq2m, "out" => outm)
  
          postConstraints(m, hrm)
          postConstraints(m, hrm, collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, [eq1m, eq2m, inm, outm]))) # Same filtering as in model/production.jl. 
          postConstraints(m, eq1m, hrm)
          postConstraints(m, eq2m, hrm)
          postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=155.), eqms)
          postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=155.), eqms)
          postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=155.), eqms)

          return e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm
        end

        @testset "Link between pieces of equipment and timing" begin
          # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

          @testset "If all time steps are disabled, then no machine may run, at any time" begin
            e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
            @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
            solve(m)
            @test getobjectivevalue(m) == 0.
          end

          @testset "If one time step is allowed, then the machines may run at that time step" begin
            e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
            @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
            solve(m)

            # Each machine is on for one time step. However, the model only works by shifts, hence allow one shift (8 hours, 8 time steps per machine).
            # Due to the processing times, cannot reach 2*8. 
            @test getobjectivevalue(m) == 2 * 8. - 1
            # Both machines are on when the time steps are allowed (i.e. the summed elements must be zero for the non-allowed time steps, 
            # and 1*0 or 1*1 for the two allowed ones). 
            @test sum(getvalue([on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) == 15. 
          end
        end

        @testset "Flows" begin
          @testset "In and out flows without transformation rate" begin
            e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowIn(outm, d, p) for d in eachTimeStep(hrm)))
            solve(m)

            # At the beginning of the horizon, may have no output (just initial conditions). 
            @test getvalue(flowOut(eq1m, date, p)) == .0

            # Flows between processes are not affected by any transformation rate. 
            @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
            @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
            @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

            # Effect on the overall values. 
            @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) == 15 * 155.
            @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ 15 * 155. atol=1.e-5
          end

          @testset "In and out flows with transformation rate" begin
            e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel(.99, .99)
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowOut(inm, d, p) for d in eachTimeStep(hrm)))
            solve(m)

            # At the beginning of the horizon, may have no output (just initial conditions). 
            @test getvalue(flowOut(eq1m, date, p)) == .0

            # Flows between processes are not affected by any transformation rate, even though there is one applied. 
            @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
            @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
            @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

            # Flows at the borders of a process are affected by the transformation rate. 
            # Time shift between the input and the output for the same process! 
            @test .99 * getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
            @test .99 * getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
            
            # Effect on the overall values, with the transformation rates at the output. 
            @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ 15 * 155. * (.99 ^ 2) atol=1.e-4 
            @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ 15 * 155. atol=1.e-4
          end
        end
      end
      
      @testset "One process, two time steps, one product" begin
        # TODO: 
      end
      
      @testset "Two processes, two time steps, one product" begin
        # TODO: 
      end

      @testset "One process, one time step, two products" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        getModel(trf=1.) = begin
          e = Equipment("EAF", :eaf, trf)
          c = ConstantConsumption(2.0)
          p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
          p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
          ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p1, 50), date + Day(4) => (p2, 100)))

          m = Model(solver=CbcSolver(logLevel=0))
          hrm = TimingModel(m, t, s)
          eqm = EquipmentModel(m, e, t, ob)
          inm = EquipmentModel(m, inEquipment, t, ob)
          outm = EquipmentModel(m, outEquipment, t, ob)
          eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eqm, "out" => outm)

          postConstraints(m, hrm)
          postConstraints(m, hrm, collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, [eqm, inm, outm]))) # Same filtering as in model/production.jl. 
          postConstraints(m, eqm, hrm)
          postConstraints(m, FlowModel(m, inEquipment, e, t, ob, maxValue=155.), eqms)
          postConstraints(m, FlowModel(m, e, outEquipment, t, ob, maxValue=155.), eqms)

          return e, c, p1, p2, ob, m, hrm, eqm, inm, outm
        end
        
        @testset "Link between pieces of equipment and timing" begin
          # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

          @testset "If all time steps are disabled, then no machine may run, at any time" begin
            e, c, p1, p2, ob, m, hrm, eqm, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
            @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
            solve(m)
            @test getobjectivevalue(m) == 0.
          end

          @testset "If one time step is allowed, then the machines may run at that time step" begin
            e, c, p1, p2, ob, m, hrm, eqm, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
            @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
            solve(m)

            @test getobjectivevalue(m) == 8.
            @test sum(getvalue([on(eqm, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 8. 
          end

          @testset "Exact process duration respected" begin
            e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
            @constraint(m, start(eqm, date) == 1.)
            @objective(m, Min, sum(on(eqm, d) for d in eachTimeStep(hrm)))
            solve(m)

            @test getvalue(start(eqm, date + Hour(1))) == 0. # Cannot yet start, not yet finished. 
            @test getvalue(on(eqm, date)) == 1. # Must be on, as started this time step. 
            @test getvalue(on(eqm, date + Hour(1))) == 1. # Must be on, as started one time step ago (the process lasts two time steps). 
            @test getvalue(on(eqm, date + Hour(2))) == 0. # Must be off, as started two time steps ago (the process lasts two time steps) 
            # and minimising the number of time steps where the process is on. 
            @test getvalue(on(eqm, date + Hour(3))) == 0.
          end
        end
        
        @testset "Flows" begin
          @testset "In and out flows without transformation rate" begin
            e, c, p1, p2, ob, m, hrm, eqm, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm)))
            solve(m)

            for p in [p1, p2]
              # At the beginning of the horizon, may have no output (just initial conditions). 
              @test getvalue(flowOut(eqm, date, p)) == 0.

              # Flows between processes are not affected by any transformation rate. 
              @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
              @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])
            end
            
            # Effect on the overall values, without any transformation rates at the output. 
            @test getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 16 * 155. atol=1.e-4 
            @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 16 * 155. atol=1.e-4
          end
          
          @testset "In and out flows with transformation rate" begin
            e, c, p1, p2, ob, m, hrm, eqm, inm, outm = getModel(.99)
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm)))
            solve(m)

            for p in [p1, p2]
              # At the beginning of the horizon, may have no output (just initial conditions). 
              @test getvalue(flowOut(eqm, date, p)) == .0

              # Flows between processes are not affected by any transformation rate, even though there is one applied. 
              @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
              @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

              # Flows at the borders of a process are affected by the transformation rate. 
              # Time shift between the input and the output for the same process! 
              @test .99 * getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
            end
            
            # Effect on the overall values, with the transformation rates at the output. 
            @test getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 16 * 155. * .99 atol=1.e-4 
            @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 16 * 155. atol=1.e-4
          end
        end
      end
    
      @testset "Two processes, one time step, two products" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        getModel(trfEAF=1., trfLF=1.) = begin
          e1 = Equipment("EAF", :eaf, trfEAF)
          e2 = Equipment("LF", :lf, trfLF)
          c = ConstantConsumption(2.0)
          p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 155.0), e2 => (150.0, 155.0)))
          p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 155.0), e2 => (150.0, 155.0)))
          ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p1, 50), date + Day(4) => (p2, 100)))

          m = Model(solver=CbcSolver(logLevel=0))
          hrm = TimingModel(m, t, s)
          eq1m = EquipmentModel(m, e1, t, ob)
          eq2m = EquipmentModel(m, e2, t, ob)
          inm = EquipmentModel(m, inEquipment, t, ob)
          outm = EquipmentModel(m, outEquipment, t, ob)
          eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eq1m, "LF" => eq2m, "out" => outm)
  
          postConstraints(m, hrm)
          postConstraints(m, hrm, collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, [eq1m, eq2m, inm, outm]))) # Same filtering as in model/production.jl. 
          postConstraints(m, eq1m, hrm)
          postConstraints(m, eq2m, hrm)
          postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=155.), eqms)
          postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=155.), eqms)
          postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=155.), eqms)

          return e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm
        end

        @testset "Link between pieces of equipment and timing" begin
          # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

          @testset "If all time steps are disabled, then no machine may run, at any time" begin
            e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
            @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
            solve(m)
            @test getobjectivevalue(m) == 0.
          end

          @testset "If one time step is allowed, then the machines may run at that time step" begin
            e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
            @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
            solve(m)

            # Each machine is on for one time step. However, the model only works by shifts, hence allow one shift (8 hours, 8 time steps per machine).
            # Due to the processing times, cannot reach 2*8. 
            @test getobjectivevalue(m) == 2 * 8. - 1
            # Both machines are on when the time steps are allowed (i.e. the summed elements must be zero for the non-allowed time steps, 
            # and 1*0 or 1*1 for the two allowed ones). 
            @test sum(getvalue([on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) == 15. 
          end
        end

        @testset "Flows" begin
          @testset "In and out flows without transformation rate" begin
            e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm)))
            solve(m)

            for p in [p1, p2]
              # At the beginning of the horizon, may have no output (just initial conditions). 
              @test getvalue(flowOut(eq1m, date, p)) == .0

              # Flows between processes are not affected by any transformation rate. 
              @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
              @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
              @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])
            end

            # Effect on the overall values, without any transformation rates at the output. 
            @test getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. atol=1.e-4 
            @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. atol=1.e-4
          end

          @testset "In and out flows with transformation rate" begin
            e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel(.99, .99)
            @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
            @constraint(m, timeStepOpen(hrm, date) == 1.)
            @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
            @objective(m, Max, sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm)))
            solve(m)

            for p in [p1, p2]
              # At the beginning of the horizon, may have no output (just initial conditions). 
              @test getvalue(flowOut(eq1m, date, p)) == .0

              # Flows between processes are not affected by any transformation rate, even though there is one applied. 
              @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
              @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
              @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) == getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

              # Flows at the borders of a process are affected by the transformation rate. 
              # Time shift between the input and the output for the same process! 
              @test .99 * getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
              @test .99 * getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
            end
            
            # Effect on the overall values, without any transformation rates at the output. 
            @test getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. * (.99 ^ 2) atol=1.e-4 
            @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. atol=1.e-4
          end
        end
      end
      
      @testset "One process, two time steps, two products" begin
      # TODO: 
      end
      
      @testset "Two processes, two time steps, two products" begin
        # TODO: 
      end
    end
    
    @testset "Each piece of implicit equipment" begin
      # TODO: model/ds/equipment.jl, postConstraints(m::Model, eq::ImplicitEquipmentModel, hrm::TimingModel) 
    end

    @testset "Order book" begin
      # TODO: model/ds/orderbook.jl, postConstraints(m::Model, ob::OrderBookModel, out::ImplicitEquipmentModel, alreadyProduced::Dict{Product, Float64}=Dict{Product, Float64}())
    end

    @testset "Flows" begin
      # TODO: model/ds/flow.jl, postConstraints(m::Model, f::FlowModel, eqs::Dict{AbstractString, AbstractEquipmentModel}) 
      # Mostly: flow bounds (min most important). 
    end

    @testset "Objectives" begin
      # TODO: model/ds/objective.jl 
    end
  end

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
      @test sum(pr.productionPlanOutput) == 360
    end
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

    @testset "Results data structures" begin
      # Embryo, just like the data structure itself! 
      m = Model()
      
      hrr = HRModelResults(m)
      @test ! hrr.feasibility
      @test hrr.model == m
      
      hrr = HRModelResults(m, Array{Bool}(0, 0), 0.0, 0.0, Array{Bool}(0, 0), Array{Bool}(0, 0), Float64[], Float64[], Float64[], 0.0, 0.0)
      @test hrr.feasibility
      @test hrr.model == m
    end
  end
end
