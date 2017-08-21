"""
Agregates small, atomic shifts as longer shifts, based on the allowed shift lengths. 
"""
function shiftsAgregation(shiftsOpenRaw::Array{Bool, 1}, timing::Timing, shifts::Shifts)
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
    end
  end

  return shiftsOpen
end
