"""
Agregates small, atomic shifts as longer shifts, based on the allowed shift lengths. 
"""
function shiftsAgregation(shiftsOpenRaw::Array{Bool, 1}, timing::Timing, shifts::Shifts, solver::MathProgBase.AbstractMathProgSolver)
  # First extract long worked periods, not yet dealing with maximum shift duration. 
  shiftsOpenLong = Tuple{DateTime, Hour}[]

  start = timeBeginning(timing)
  duration = 0

  for i in 1:length(shiftsOpenRaw)
    if shiftsOpenRaw[i] && i > 1
      # This shift is worked: either a shift starts or continues. 
      if ! shiftsOpenRaw[i - 1] # Start. 
        start = timeBeginning + (i - 1) * shiftDurationsStep(shifts)
      else # Continuation. 
        duration += 1
      end
    elseif ! shiftsOpenRaw[i] && i > 1 && shiftsOpenRaw[i - 1]
      # This shift is not worked, but the previous was: this is the end of a shift. 
      push!(shiftsOpenLong, (start, duration * shiftDurationsStep(shifts)))
      duration = 0
    end
  end

  # Then, split the too long shifts into more acceptable shifts. 
  shiftsOpen = Tuple{DateTime, Hour}[]
  maximumShiftDuration = maximumShiftDurations(shifts)

  for sol in shiftsOpenLong
    if sol[2] <= maximumShiftDurations(shifts) # Shift short enough: accept it as such! 
      push!(shiftsOpen, sol)
    else # Too long: cut it into pieces. 
      # Have pieces that are as alike to each other as possible, but not too many pieces either. 
      # Could probably write an algorithm for this, but let's use an optimisation solver (ensured to be available here). 
      # After all, it's a figth-generation programming language! 
      m = Model(solver=solver)
      @variable(m, n[1:nShiftDurations(shifts)] >= 0, Int)
      @variable(m, average >= 0)
      @variable(m, slackPlus[1:nShiftDurations(shifts)] >= 0)
      @variable(m, slackMinus[1:nShiftDurations(shifts)] >= 0)
      @constraint(m, dot(n, shiftDurations(shifts)) == sol[2])
      @constraint(m, c[i=1:nShiftDurations(shifts)], n[i] * shiftDurations(shifts)[i].value + slackPlus[i] - slackMinus[i] == average)
      @objective(m, Min, sum(slackPlus) + sum(slackMinus) + sum(n))
      solve(m)

      start = sol[1]
      for i in nShiftDurations(shifts)
        for repetition in 1:getvalue(n[i])
          push!(shiftsOpen, (start, shiftDurations(shifts)[i]))
          start += shiftDurations(shifts)[i]
        end
      end
    end
  end

  return shiftsOpen
end
