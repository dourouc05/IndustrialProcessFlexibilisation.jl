@testset "Each piece of equipment" begin
  eqmFilter = leqm -> collect(EquipmentModel, Iterators.filter((e) -> typeof(e) == EquipmentModel, leqm)) # Same filtering as in model/production.jl. 

  # model/ds/equipment.jl, postConstraints(m::Model, eq::EquipmentModel, hrm::TimingModel)
  @testset "One process, one time step, one product" begin
    date = DateTime(2017, 01, 01, 12, 32, 42)
    t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
    s = Shifts(t, date, Hour(8))

    getModel(trf=1.) = begin
      e = Equipment("EAF", :eaf, trf)
      c = ConstantConsumption(2.0)
      p = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

      m = Model(solver=CbcSolver(logLevel=0))
      hrm = TimingModel(m, t, s)
      eqm = EquipmentModel(m, e, t, ob)
      inm = EquipmentModel(m, inEquipment, t, ob)
      outm = EquipmentModel(m, outEquipment, t, ob)
      eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eqm, "out" => outm)

      postConstraints(m, hrm)
      postConstraints(m, hrm, eqmFilter([eqm, inm, outm]))
      postConstraints(m, eqm, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e, outEquipment, t, ob, maxValue=155.), hrm, eqms)

      return e, c, p, ob, m, hrm, eqm, inm, outm
    end
    
    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
        @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
        solve(m)

        @test getobjectivevalue(m) ≈ 8.
        @test sum(getvalue([on(eqm, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 8. 
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
        @test getvalue(flowOut(eqm, date, p)) ≈ 0.

        # Flows between processes are not affected by any transformation rate. 
        @test getvalue([flowOut(inm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

        # Effect on the overall values. 
        @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 155.
        @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 155. atol=1.e-5
      end
      
      @testset "In and out flows with transformation rate" begin
        e, c, p, ob, m, hrm, eqm, inm, outm = getModel(.99)
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
        @constraint(m, timeStepOpen(hrm, date) == 1.)
        @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
        @objective(m, Max, sum(flowOut(inm, d, p) for d in eachTimeStep(hrm)))
        solve(m)

        # At the beginning of the horizon, may have no output (just initial conditions). 
        @test getvalue(flowOut(eqm, date, p)) ≈ .0

        # Flows between processes are not affected by any transformation rate, even though there is one applied. 
        @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

        # Flows at the borders of a process are affected by the transformation rate. 
        # Time shift between the input and the output for the same process! 
        @test .99 * getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
        
        # Effect on the overall values, with the transformation rates at the output. 
        @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 155. * .99 atol=1.e-4 
        @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 155. atol=1.e-4
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
      postConstraints(m, hrm, eqmFilter([eq1m, eq2m, inm, outm]))
      postConstraints(m, eq1m, hrm)
      postConstraints(m, eq2m, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=155.), hrm, eqms)

      return e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm
    end

    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
        @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
        solve(m)

        # Each machine is on for one time step. However, the model only works by shifts, hence allow one shift (8 hours, 8 time steps per machine).
        # Due to the processing times, cannot reach 2*8. 
        @test getobjectivevalue(m) ≈ 2 * 8. - 1
        # Both machines are on when the time steps are allowed (i.e. the summed elements must be zero for the non-allowed time steps, 
        # and 1*0 or 1*1 for the two allowed ones). 
        @test sum(getvalue([on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 15. 
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
        @test getvalue(flowOut(eq1m, date, p)) ≈ .0

        # Flows between processes are not affected by any transformation rate. 
        @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

        # Effect on the overall values. 
        @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ 15 * 155.
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
        @test getvalue(flowOut(eq1m, date, p)) ≈ .0

        # Flows between processes are not affected by any transformation rate, even though there is one applied. 
        @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

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
      postConstraints(m, hrm, eqmFilter([eqm, inm, outm]))
      postConstraints(m, eqm, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e, t, ob, maxValue=150.), hrm, eqms)
      postConstraints(m, FlowModel(m, e, outEquipment, t, ob, maxValue=150.), hrm, eqms)

      return e, c, p, ob, m, hrm, eqm, inm, outm
    end
    
    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
        @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
        solve(m)

        @test getobjectivevalue(m) ≈ 8.
        @test sum(getvalue([on(eqm, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 8. 
      end

      @testset "Exact process duration respected" begin
        e, c, p, ob, m, hrm, eqm, inm, outm = getModel()
        @constraint(m, start(eqm, date) == 1.)
        @objective(m, Min, sum(on(eqm, d) for d in eachTimeStep(hrm)))
        solve(m)

        @test getvalue(start(eqm, date + Hour(1))) ≈ 0. # Cannot yet start, not yet finished. 
        @test getvalue(on(eqm, date)) ≈ 1. # Must be on, as started this time step. 
        @test getvalue(on(eqm, date + Hour(1))) ≈ 1. # Must be on, as started one time step ago (the process lasts two time steps). 
        @test getvalue(on(eqm, date + Hour(2))) ≈ 0. # Must be off, as started two time steps ago (the process lasts two time steps) 
        # and minimising the number of time steps where the process is on. 
        @test getvalue(on(eqm, date + Hour(3))) ≈ 0.
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
        @test getvalue(flowOut(eqm, date, p)) ≈ 0.

        # Flows between processes are not affected by any transformation rate. 
        @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

        # Effect on the overall values. 
        @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 150. / 2
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
        @test getvalue(flowOut(eqm, date, p)) ≈ .0

        # Flows between processes are not affected by any transformation rate, even though there is one applied. 
        @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

        # Flows at the borders of a process are affected by the transformation rate. 
        # Time shift between the input and the output for the same process! 
        @test .99 * getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])[1:end-2] ≈ getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)])[3:end] atol=1.e-4
        
        # Effect on the overall values, with the transformation rates at the output. 
        @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 150. / 2 * .99 atol=1.e-4 
        @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ 16 * 150. / 2 atol=1.e-4
      end
    end
  end
  
  @testset "Two processes, two time steps, one product" begin
    date = DateTime(2017, 01, 01, 12, 32, 42)
    t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
    s = Shifts(t, date, Hour(8))

    getModel(trf=1.) = begin
      e1 = Equipment("EAF", :eaf, trf, Hour(1), 0.0, 1.e6, Hour(2))
      #                                                    ^^^^^^^
      e2 = Equipment("LF", :lf, trf, Hour(1), 0.0, 1.e6, Hour(2))
      #                                                  ^^^^^^^
      c = ConstantConsumption(2.0)
      p = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (145.0, 150.0), e2 => (145.0, 150.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p, 50)))

      m = Model(solver=CbcSolver(logLevel=0))
      hrm = TimingModel(m, t, s)
      eq1m = EquipmentModel(m, e1, t, ob)
      eq2m = EquipmentModel(m, e2, t, ob)
      inm = EquipmentModel(m, inEquipment, t, ob)
      outm = EquipmentModel(m, outEquipment, t, ob)
      eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eq1m, "LF" => eq2m, "out" => outm)

      postConstraints(m, hrm)
      postConstraints(m, hrm, eqmFilter([eq1m, eq2m, inm, outm]))
      postConstraints(m, eq1m, hrm)
      postConstraints(m, eq2m, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=150.), hrm, eqms)
      postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=150.), hrm, eqms)
      postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=150.), hrm, eqms)

      return e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm
    end
    
    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.) # TODO: Find a better way to write this: timeStepOpen returns shiftOpen... Another use of eachShift()? And impose to have the timeStepOpen variables to be able to use their getter?
        @constraint(m, timeStepOpen(hrm, timeEnding(hrm)) == 0.) # This test ought not to verify what happens at the edges of the temporal domain. 
        @objective(m, Max, sum(on(eq1m, d) for d in eachTimeStep(hrm)))
        solve(m)
  
        # This also checks whether dependencies between processes are well encoded: if one value is not 8, then 
        # the output of some processes is lost. 
        @test getobjectivevalue(m) ≈ 6.
        @test sum(getvalue([on(eq1m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 6. 
        @test sum(getvalue([on(eq2m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 6 
      end

      @testset "Exact process duration respected" begin
        e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, start(eq1m, date) == 1.)
        @objective(m, Min, sum(on(eq1m, d) for d in eachTimeStep(hrm)))
        solve(m)

        # First process. 
        @test getvalue(start(eq1m, date + Hour(1))) ≈ 0. # Cannot yet start, not yet finished. 
        @test getvalue(on(eq1m, date)) ≈ 1. # Must be on, as started this time step. 
        @test getvalue(on(eq1m, date + Hour(1))) ≈ 1. # Must be on, as started one time step ago (the process lasts two time steps). 
        @test getvalue(on(eq1m, date + Hour(2))) ≈ 0. # Must be off, as started two time steps ago (the process lasts two time steps) 
        # and minimising the number of time steps where the process is on. 
        @test getvalue(on(eq1m, date + Hour(3))) ≈ 0.
        @test getvalue(on(eq1m, date + Hour(4))) ≈ 0.
        @test getvalue(on(eq1m, date + Hour(5))) ≈ 0.
        
        # Second process. 
        @test getvalue(on(eq2m, date)) ≈ 0. # Cannot yet start, first process not yet finished. 
        @test getvalue(on(eq2m, date + Hour(1))) ≈ 0. # Cannot yet start, first process not yet finished. 
        @test getvalue(start(eq2m, date)) ≈ 0. # Cannot yet start, not yet finished. 
        @test getvalue(on(eq2m, date + Hour(2))) ≈ 1. # Must be on, as started this time step. 
        @test getvalue(on(eq2m, date + Hour(3))) ≈ 1. # Must be on, as started one time step ago (the process lasts two time steps). 
        @test getvalue(on(eq2m, date + Hour(4))) ≈ 0. # Must be off, as started two time steps ago (the process lasts two time steps) 
        # and minimising the number of time steps where the process is on. 
        @test getvalue(on(eq2m, date + Hour(5))) ≈ 0.
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
        @test getvalue(flowOut(eq1m, date, p)) ≈ 0.
        @test getvalue(flowOut(eq2m, date, p)) ≈ 0.

        # Flows between processes are not affected by any transformation rate. 
        @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

        # Effect on the overall values. 
        @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ (16 - 2) * 150. / 2
        @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ ((16 - 2) * 150. / 2) atol=1.e-5
      end
      
      @testset "In and out flows with transformation rate" begin
        e1, e2, c, p, ob, m, hrm, eq1m, eq2m, inm, outm = getModel(0.99)
        @constraint(m, timeStepOpen(hrm, date) == 1.)
        @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm, from=timeBeginning(hrm) + Hour(16))) == 0.)
        @objective(m, Max, sum(flowOut(inm, d, p) for d in eachTimeStep(hrm)))
        solve(m)

        # At the beginning of the horizon, may have no output (just initial conditions). 
        @test getvalue(flowOut(eq2m, date, p)) ≈ .0

        # Flows between processes are not affected by any transformation rate, even though there is one applied. 
        @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
        @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

        # Flows at the borders of a process are affected by the transformation rate. 
        # Time shift between the input and the output for the same process! 
        @test .99 * getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])[1:end-2] ≈ getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)])[3:end] atol=1.e-4
        @test .99 * getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])[1:end-2] ≈ getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)])[3:end] atol=1.e-4
        
        # Effect on the overall values, with the transformation rates at the output. 
        @test getvalue(sum(flowIn(outm, d, p) for d in eachTimeStep(hrm))) ≈ ((16 - 2) * 150. / 2 * .99 * .99) atol=1.e-4 
        @test getvalue(sum(flowOut(inm, d, p) for d in eachTimeStep(hrm))) ≈ ((16 - 2) * 150. / 2) atol=1.e-4
      end
    end
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
      postConstraints(m, hrm, eqmFilter([eqm, inm, outm]))
      postConstraints(m, eqm, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e, outEquipment, t, ob, maxValue=155.), hrm, eqms)

      return e, c, p1, p2, ob, m, hrm, eqm, inm, outm
    end
    
    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e, c, p1, p2, ob, m, hrm, eqm, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e, c, p1, p2, ob, m, hrm, eqm, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
        @objective(m, Max, sum(on(eqm, d) for d in eachTimeStep(hrm)))
        solve(m)

        @test getobjectivevalue(m) ≈ 8.
        @test sum(getvalue([on(eqm, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 8. 
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
          @test getvalue(flowOut(eqm, date, p)) ≈ 0.

          # Flows between processes are not affected by any transformation rate. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])
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
          @test getvalue(flowOut(eqm, date, p)) ≈ .0

          # Flows between processes are not affected by any transformation rate, even though there is one applied. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eqm, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eqm, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

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
      postConstraints(m, hrm, eqmFilter([eq1m, eq2m, inm, outm]))
      postConstraints(m, eq1m, hrm)
      postConstraints(m, eq2m, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=155.), hrm, eqms)

      return e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm
    end

    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
        @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
        solve(m)

        # Each machine is on for one time step. However, the model only works by shifts, hence allow one shift (8 hours, 8 time steps per machine).
        # Due to the processing times, cannot reach 2*8. 
        @test getobjectivevalue(m) ≈ 2 * 8. - 1
        # Both machines are on when the time steps are allowed (i.e. the summed elements must be zero for the non-allowed time steps, 
        # and 1*0 or 1*1 for the two allowed ones). 
        @test sum(getvalue([on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 15. 
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
          @test getvalue(flowOut(eq1m, date, p)) ≈ .0

          # Flows between processes are not affected by any transformation rate. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])
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
          @test getvalue(flowOut(eq1m, date, p)) ≈ .0

          # Flows between processes are not affected by any transformation rate, even though there is one applied. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

          # Flows at the borders of a process are affected by the transformation rate. 
          # Time shift between the input and the output for the same process! 
          @test .99 * getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
          @test .99 * getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
        end
        
        # Effect on the overall values, without any transformation rates at the output. 
        @test getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. * (.99 ^ 2) atol=1.e-4 
        @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. atol=1.e-4
      end

      @testset "Fixed flow" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        e1 = Equipment("EAF", :eaf)
        e2 = Equipment("LF", :lf)
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 150.0), e2 => (150.0, 150.0)))
        p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 150.0), e2 => (150.0, 150.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p1, 50), date + Day(4) => (p2, 100)))

        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)
        eq1m = EquipmentModel(m, e1, t, ob)
        eq2m = EquipmentModel(m, e2, t, ob)
        inm = EquipmentModel(m, inEquipment, t, ob)
        outm = EquipmentModel(m, outEquipment, t, ob)
        eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eq1m, "LF" => eq2m, "out" => outm)

        postConstraints(m, hrm)
        postConstraints(m, hrm, eqmFilter([eq1m, eq2m, inm, outm]))
        postConstraints(m, eq1m, hrm)
        postConstraints(m, eq2m, hrm)
        postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=150.), hrm, eqms)
        postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=150.), hrm, eqms)
        postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=150.), hrm, eqms)

        @objective(m, Max, sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm)))
        solve(m)

        @test getobjectivevalue(m) ≈ (168 - 2) * 150.
      end
    end
  end
  
  # @testset "One process, two time steps, two products" begin
  #   # TODO: 
  # end
  
  @testset "Two processes, two time steps, two products" begin
    date = DateTime(2017, 01, 01, 12, 32, 42)
    t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
    t = Timing(timeBeginning=date, timeHorizon=Hour(16), timeStepDuration=Hour(1))
    s = Shifts(t, date, Hour(8))

    getModel(trf=1.) = begin
      e1 = Equipment("EAF", :eaf, trf, Hour(1), 0.0, 1.e6, Hour(2))
      #                                                    ^^^^^^^
      e2 = Equipment("LF", :lf, trf, Hour(1), 0.0, 1.e6, Hour(2))
      #                                                  ^^^^^^^
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
      postConstraints(m, hrm, eqmFilter([eq1m, eq2m, inm, outm]))
      postConstraints(m, eq1m, hrm)
      postConstraints(m, eq2m, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=155.), hrm, eqms)

      return e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm
    end
    
    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eq2m, d) + on(eq1m, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
        @constraint(m, timeStepOpen(hrm, date) == 1.)
        @objective(m, Max, sum(on(eq1m, d) for d in eachTimeStep(hrm)))
        solve(m)

        @test getobjectivevalue(m) ≈ 4.
        @test sum(getvalue([on(eq1m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 4. 
        @test sum(getvalue([on(eq2m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 4. 
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
          @test getvalue(flowOut(eq1m, date, p)) ≈ 0.
          @test getvalue(flowOut(eq2m, date, p)) ≈ 0.

          # Flows between processes are not affected by any transformation rate. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq1m,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])
        end
        
        # Effect on the overall values, without any transformation rates at the output. 
        @test getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 6 * 155. atol=1.e-4 
        @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 6 * 155. atol=1.e-4
        @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 6 * 155. atol=1.e-4
      end
      
      @testset "In and out flows with transformation rate" begin
        e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel(.99)
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 16.)
        @constraint(m, timeStepOpen(hrm, date) == 1.)
        @constraint(m, timeStepOpen(hrm, date + Hour(8)) == 1.)
        @objective(m, Max, sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm)))
        solve(m)

        for p in [p1, p2]
          # At the beginning of the horizon, may have no output (just initial conditions). 
          @test getvalue(flowOut(eq1m, date, p)) ≈ .0
          @test getvalue(flowOut(eq2m, date, p)) ≈ .0

          # Flows between processes are not affected by any transformation rate, even though there is one applied. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

          # Flows at the borders of a process are affected by the transformation rate. 
          # Time shift between the input and the output for the same process! 
          # TODO: Shift by one in the arrays, normal? Might also explain the strange things above (other TODO item). 
          @test_broken .99 * getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
          @test_broken .99 * getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
        end
        
        # Effect on the overall values, with the transformation rates at the output. 
        @test_broken getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 6 * 155. * .99 * .99 atol=1.e-4 
        @test_broken getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 6 * 155. atol=1.e-4
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
      postConstraints(m, hrm, eqmFilter([eq1m, eq2m, inm, outm]))
      postConstraints(m, eq1m, hrm)
      postConstraints(m, eq2m, hrm)
      postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=155.), hrm, eqms)
      postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=155.), hrm, eqms)

      return e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm
    end

    @testset "Link between pieces of equipment and timing" begin
      # No order book constraints are added into the program (otherwise, these tests will miserably fail). 

      @testset "If all time steps are disabled, then no machine may run, at any time" begin
        e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 0.)
        @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
        solve(m)
        @test getobjectivevalue(m) ≈ 0.
      end

      @testset "If one time step is allowed, then the machines may run at that time step" begin
        e1, e2, c, p1, p2, ob, m, hrm, eq1m, eq2m, inm, outm = getModel()
        @constraint(m, sum(timeStepOpen(hrm, d) for d in eachTimeStep(hrm)) == 8.)
        @objective(m, Max, sum(on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)))
        solve(m)

        # Each machine is on for one time step. However, the model only works by shifts, hence allow one shift (8 hours, 8 time steps per machine).
        # Due to the processing times, cannot reach 2*8. 
        @test getobjectivevalue(m) ≈ 2 * 8. - 1
        # Both machines are on when the time steps are allowed (i.e. the summed elements must be zero for the non-allowed time steps, 
        # and 1*0 or 1*1 for the two allowed ones). 
        @test sum(getvalue([on(eq1m, d) + on(eq2m, d) for d in eachTimeStep(hrm)]) .* getvalue([timeStepOpen(hrm, d) for d in eachTimeStep(hrm)])) ≈ 15. 
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
          @test getvalue(flowOut(eq1m, date, p)) ≈ .0

          # Flows between processes are not affected by any transformation rate. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])
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
          @test getvalue(flowOut(eq1m, date, p)) ≈ .0

          # Flows between processes are not affected by any transformation rate, even though there is one applied. 
          @test getvalue([flowOut(inm,  d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])
          @test getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)]) ≈ getvalue([flowIn(outm, d, p) for d in eachTimeStep(hrm)])

          # Flows at the borders of a process are affected by the transformation rate. 
          # Time shift between the input and the output for the same process! 
          @test .99 * getvalue([flowIn(eq1m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq1m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
          @test .99 * getvalue([flowIn(eq2m, d, p) for d in eachTimeStep(hrm)])[1:end-1] ≈ getvalue([flowOut(eq2m, d, p) for d in eachTimeStep(hrm)])[2:end] atol=1.e-4
        end
        
        # Effect on the overall values, without any transformation rates at the output. 
        @test getvalue(sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. * (.99 ^ 2) atol=1.e-4 
        @test getvalue(sum(flowOut(inm, d, p1) + flowOut(inm, d, p2) for d in eachTimeStep(hrm))) ≈ 15 * 155. atol=1.e-4
      end

      @testset "Fixed flow" begin
        date = DateTime(2017, 01, 01, 12, 32, 42)
        t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
        s = Shifts(t, date, Hour(8))

        e1 = Equipment("EAF", :eaf)
        e2 = Equipment("LF", :lf)
        c = ConstantConsumption(2.0)
        p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 150.0), e2 => (150.0, 150.0)))
        p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}(e1 => (150.0, 150.0), e2 => (150.0, 150.0)))
        ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(date + Day(2) => (p1, 50), date + Day(4) => (p2, 100)))

        m = Model(solver=CbcSolver(logLevel=0))
        hrm = TimingModel(m, t, s)
        eq1m = EquipmentModel(m, e1, t, ob)
        eq2m = EquipmentModel(m, e2, t, ob)
        inm = EquipmentModel(m, inEquipment, t, ob)
        outm = EquipmentModel(m, outEquipment, t, ob)
        eqms = Dict{AbstractString, AbstractEquipmentModel}("in" => inm, "EAF" => eq1m, "LF" => eq2m, "out" => outm)

        postConstraints(m, hrm)
        postConstraints(m, hrm, eqmFilter([eq1m, eq2m, inm, outm]))
        postConstraints(m, eq1m, hrm)
        postConstraints(m, eq2m, hrm)
        postConstraints(m, FlowModel(m, inEquipment, e1, t, ob, maxValue=150.), hrm, eqms)
        postConstraints(m, FlowModel(m, e1, e2, t, ob, maxValue=150.), hrm, eqms)
        postConstraints(m, FlowModel(m, e2, outEquipment, t, ob, maxValue=150.), hrm, eqms)

        @objective(m, Max, sum(flowIn(outm, d, p1) + flowIn(outm, d, p2) for d in eachTimeStep(hrm)))
        solve(m)

        @test getobjectivevalue(m) ≈ (168 - 2) * 150.
      end
    end
    
    @testset "Minimum up time" begin
      # TODO: 
    end 
    
    @testset "Minimum and maximum production different from flows" begin
      # TODO: 
    end 
  end
  
  @testset "Each piece of implicit equipment" begin
    # TODO: model/ds/equipment.jl, postConstraints(m::Model, eq::ImplicitEquipmentModel, hrm::TimingModel) 
  end
end