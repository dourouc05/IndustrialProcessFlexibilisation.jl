@testset "Input-output" begin
  @testset "Order book" begin
    @testset "As matrix" begin
      # 24-hour shifts for output, order book within time bounds.
      date = DateTime(2017, 01, 01)
      t1 = Timing(timeBeginning=date, timeHorizon=Week(2), timeStepDuration=Hour(1))
      s1 = Shifts(t1, date, Hour(24))

      c = ConstantConsumption(2.0)
      e = Equipment("EAF", :eaf)
      p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(timeBeginning(t1) => (p1, 50), timeBeginning(t1) + Week(1) => (p2, 50)))

      obm = convert(Array, ob, t1, s1, shiftly=true, restrictToTiming=true)
      @test(size(obm, 1) == 14) # 2 weeks, 1-day shifts.
      @test(size(obm, 2) == 2) # Products.
      @test(sum(obm, 1) ≈ [50., 50.]')
      @test(sum(obm, 2) ≈ [50., 0., 0., 0., 0., 0., 50., 0., 0., 0., 0., 0., 0., 0.])

      # Change timing bounds to get rid of one order.
      t2 = Timing(timeBeginning=date, timeHorizon=Day(5), timeStepDuration=Hour(1))
      s2 = Shifts(t2, date, Hour(24))
      obm = convert(Array, ob, t2, s2, shiftly=true, restrictToTiming=true)
      @test(size(obm, 1) == 5) # 5 days, 1-day shifts.
      @test(size(obm, 2) == 1) # Products.
      @test(sum(obm, 1) ≈ [50.]')
      @test(sum(obm, 2) ≈ [50., 0., 0., 0., 0.])

      # The two previous test cases should not be affected by restrictToTiming, except for matrix size (some orders are
      # deleted from the order book before conversion with restrictToTiming, hence some products may be lost).
      @test(convert(Array, ob, t1, s1, shiftly=true, restrictToTiming=true) ≈ convert(Array, ob, t1, s1, shiftly=true, restrictToTiming=false))
      @test(convert(Array, ob, t2, s2, shiftly=true, restrictToTiming=true) ≈ sum(convert(Array, ob, t2, s2, shiftly=true, restrictToTiming=false), 2))

      # restrictToTiming has an effect on *past* orders.
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(timeBeginning(t1) - Week(1) => (p1, 50), timeBeginning(t1) + Week(1) => (p2, 50)))

      obm = convert(Array, ob, t1, s1, shiftly=true, restrictToTiming=false)
      @test(size(obm, 1) == 14) # 2 weeks, 1-day shifts.
      @test(size(obm, 2) == 2) # Products.
      @test(sum(obm, 1) ≈ [50., 50.]')
      @test(sum(obm, 2) ≈ [50., 0., 0., 0., 0., 0., 50., 0., 0., 0., 0., 0., 0., 0.])

      obm = convert(Array, ob, t1, s1, shiftly=true, restrictToTiming=true)
      @test(size(obm, 1) == 14) # 2 weeks, 1-day shifts.
      @test(size(obm, 2) == 1) # Products.
      @test(sum(obm, 1) ≈ [50.]')
      @test(sum(obm, 2) ≈ [0., 0., 0., 0., 0., 0., 50., 0., 0., 0., 0., 0., 0., 0.])
    end
  end
end
