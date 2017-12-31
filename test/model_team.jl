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