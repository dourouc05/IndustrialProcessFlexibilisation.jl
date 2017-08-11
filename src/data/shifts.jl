"""
Describes all shift issues in a problem to solve: the beginning of the first shift (which may be before the beginning
of the optimisation, as described in a `Timing` object), and the possible durations for the shifts.

  * `shiftBeginning`: date at which the first shift begins (for example, `now()` or `DateTime(2016, 12, 15, 6)`);
    it may be before `timeBeginning`, but not after
  * `shiftDuration`: duration of a worker's shift (for example, `Hour(8)`). It may be either a duration or a range
    of durations (if the shift length may vary). If values are given as integers, they are considered as hours. 
"""
struct Shifts
  beginning::DateTime
  durations::StepRange{Hour, Hour}
  
  function Shifts(beginning::DateTime, durations::StepRange{Hour, Hour})
    if length(shiftDurations) == 0
      error("No shift duration given. Please provide at least one.")
    end

    return new(beginning, durations)
  end
end

Shifts(beginning::DateTime, durations::StepRange{Int, Int}) = Shifts(beginning, Hour(durations.start) : Hour(durations.step) : Hour(durations.stop))
Shifts(beginning::DateTime, shiftDuration::Hour) = Shifts(beginning, shiftDuration : Hour(1) : shiftDuration)
Shifts(beginning::DateTime, shiftDuration::Int) = Shifts(beginning, Hour(shiftDuration) : Hour(1) : Hour(shiftDuration))

function Shifts(timing::Timing, beginning::DateTime, durations)
  if beginning > timeBeginning(timing)
    error("The shifts must begin at the latest at the beginning of the optimisation horizon.")
  end

  return Shifts(beginning, durations)
end

shiftBeginning(s::Shifts) = s.beginning
shiftDurations(s::Shifts) = collect(s.durations)
shiftDurationsStart(s::Shifts) = s.durations.start
shiftDurationsStep(s::Shifts) = s.durations.step
shiftDurationsStop(s::Shifts) = s.durations.stop
nShiftDurations(s::Shifts) = length(s.durations)

shiftDuration(s::Shifts) = if nShiftDurations(s) == 1; s.durations[1]; else; error("There are multiple shift durations. Use the functions shiftDurations and nShiftDurations instead."); end
nTimeStepsPerShift(t::Timing, s::Shifts) = map((sd) -> nTimeSteps(t, sd), shiftDurations(s)) 

"""
Returns the number of shifts from `s` that are contained within the optimisation horizon of `t`. If there are multiple shift
lengths, this function considers the longest possible length, i.e. the minimum number of shifts. 

Another version of the function uses a third argument that gives the shift duration (instead of taking the maximum one). 
This duration must pertain to the `s` object. 
"""
function nShifts(t::Timing, s::Shifts) 
  # Intricacies start when the optimisation and shifts do not start at the same time. If the shifts start sooner,
  # then the first shift is only partly within the optimisation horizon (and the last one too). However, if the difference
  # is larger than one complete shift, then there is at least one completely useless shift, because it corresponds to
  # zero time steps. Hence the second term:
  #   - Dates.toms((timeBeginning(t) - shiftBeginning(t))) / Dates.toms(shiftDuration(s)) is the raw number of
  #     supplementary shifts
  #   - min(Dates.toms((timeBeginning(t) - shiftBeginning(t))), Dates.toms(shiftDuration(s))) ensures that at most
  #     one shift is added.
  # By invariant (imposed by the constructor), timeBeginning(t) >= shiftBeginning(t).
  
  # When there are multiple shift lengths, only the largest one is taken into account. 
  # TODO: Make it a parameter to the function? 

  sd = maximum(shiftDurations(s))
  return ceil(Int, Dates.toms(timeHorizon(t)) / Dates.toms(sd)) +
    ceil(Int, min(Dates.toms((timeBeginning(t) - shiftBeginning(s))), Dates.toms(sd)) / Dates.toms(sd))
end

function nShifts(t::Timing, s::Shifts, sl::TimePeriod)
  allDurations = shiftDurations(s)
  if sl in allDurations
    return ceil(Int, Dates.toms(timeHorizon(t)) / Dates.toms(sl)) +
      ceil(Int, min(Dates.toms((timeBeginning(t) - shiftBeginning(s))), Dates.toms(sl)) / Dates.toms(sl))
  else
    error("Given duration $(sl) not found in the durations allowed by the Shifts object. Allowed durations are: $(allDurations)")
  end
end
