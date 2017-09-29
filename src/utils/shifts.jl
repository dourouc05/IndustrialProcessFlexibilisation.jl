"""
Agregates small, atomic shifts as longer shifts, based on the allowed shift lengths. 

This function outputs a list of tuples, containing the following information about each shift: 

  * the beginning of the shift (DateTime)
  * the duration of the shift (Hour)
  * the number of teams required for the shift (Int)
"""
function shiftsAgregation(shiftsOpenRaw::Array{Bool, 1}, timing::Timing, shifts::Shifts, solver::MathProgBase.AbstractMathProgSolver)
  # First extract long worked periods, not yet dealing with maximum shift duration. 
  shiftsOpenLong = Tuple{DateTime, Hour, Int}[]

  start = timeBeginning(timing) # Beginning of the current shift. 
  duration = 1 # Number of "unit" shifts (from shiftsOpenRaw) within the current longer shift. 

  for i in 1:length(shiftsOpenRaw)
    if shiftsOpenRaw[i] && i > 1
      # This shift is worked: either a shift starts or continues. 
      if ! shiftsOpenRaw[i - 1] # Start. 
        start = timeBeginning(timing) + (i - 1) * shiftDurationsStep(shifts)
      else # Continuation. 
        duration += 1
      end
    elseif ! shiftsOpenRaw[i] && i > 1 && shiftsOpenRaw[i - 1]
      # This shift is not worked, but the previous was: this is the end of a shift. 
      push!(shiftsOpenLong, (start, duration * shiftDurationsStep(shifts), 1))
      duration = 1
    end
  end

  # Then, split the too long shifts into more acceptable shifts. 
  shiftsOpen = Tuple{DateTime, Hour, Int}[]
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
      @constraint(m, dot(n, map(d -> d.value, shiftDurations(shifts))) == sol[2].value)
      @constraint(m, c[i=1:nShiftDurations(shifts)], n[i] * shiftDurations(shifts)[i].value + slackPlus[i] - slackMinus[i] == average)
      @objective(m, Min, sum(slackPlus) + sum(slackMinus) + 10 * sum(n))
      solve(m)

      start = sol[1]
      ns = round.(Int, getvalue(n))
      for i in 1:nShiftDurations(shifts)
        for repetition in 1:ns[i]
          push!(shiftsOpen, (start, shiftDurations(shifts)[i], 1))
          start += shiftDurations(shifts)[i]
        end
      end
    end
  end

  return shiftsOpen
end
