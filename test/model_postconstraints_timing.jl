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