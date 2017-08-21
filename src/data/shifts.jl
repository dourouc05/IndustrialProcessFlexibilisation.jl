"""
Describes all shift issues in a problem to solve: the beginning of the first shift (which may be before the beginning
of the optimisation, as described in a `Timing` object), and the possible durations for the shifts.

  * `beginning`: date at which the first shift begins (for example, `now()` or `DateTime(2016, 12, 15, 6)`);
    it may be before `timeBeginning`, but not after
  * `durations`: duration of a worker's shift (for example, `Hour(8)`). It may be either a duration or a range
    of durations (if the shift length may vary). If values are given as integers, they are considered as hours. 
"""
struct Shifts
  beginning::DateTime
  durations::StepRange{Hour, Hour}
  
  function Shifts(beginning::DateTime, durations::StepRange{Hour, Hour})
    if length(shiftDurations) == 0
      error("No shift duration given. Please provide at least one.")
    end

    if durations.start == Hour(0)
      error("The minimum shift duration must be at least one hour; it is currently zero.")
    end

    # The next two hypotheses are used when building the model, to ease the use of the created variables. 
    if durations.start % durations.step != Hour(0)
      error("The minimum shift duration ($(durations.start)) is not a multiple of the step ($(durations.step)).")
    end
    if durations.stop % durations.step != Hour(0)
      error("The maximum shift duration ($(durations.stop)) is not a multiple of the step ($(durations.step)).")
    end

    return new(beginning, durations)
  end
end

function Shifts(timing::Timing, beginning::DateTime, durations)
  if beginning > timeBeginning(timing)
    error("The shifts must begin at the latest at the beginning of the optimisation horizon.")
  end

  return Shifts(beginning, durations)
end

Shifts(timing::Timing, beginning::DateTime, durations::StepRange{Int, Int}) = 
  Shifts(timing, beginning, Hour(durations.start) : Hour(durations.step) : Hour(durations.stop))
Shifts(timing::Timing, beginning::DateTime, shiftDuration::Hour) = 
  Shifts(timing, beginning, shiftDuration : Hour(1) : shiftDuration)
Shifts(timing::Timing, beginning::DateTime, shiftDuration::Int) = 
  Shifts(timing, beginning, Hour(shiftDuration) : Hour(1) : Hour(shiftDuration))

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
  allowedDurations = shiftDurations(s)
  push!(allowedDurations, shiftDurationsStep(s))

  if sl in allowedDurations
    return ceil(Int, Dates.toms(timeHorizon(t)) / Dates.toms(sl)) +
      ceil(Int, min(Dates.toms((timeBeginning(t) - shiftBeginning(s))), Dates.toms(sl)) / Dates.toms(sl))
  else
    error("Given duration $(sl) not found in the durations allowed by the Shifts object. Allowed durations are: $(allowedDurations)")
  end
end

"""
Computes the number of minimum-length shifts between `d` and the beginning of the shifts within `t`. If this number is not integer,
the closest integer is returned.
"""
function dateToShift(s::Shifts, d::DateTime)
  if d < shiftBeginning(t)
    error("Time " * string(d) * " before the shift beginning (" * string(shiftBeginning(t)) * ").")
  end

  delta = Millisecond(d - shiftBeginning(t)).value
  return 1 + floor(Int, delta / Dates.toms(shiftDurationsStep(s))) 
end

"""
Shifts the shifts object by the given period `p`. This means that the beginning will be shifted by `p`.

See the corresponding method for `Timing`. 
"""
shift(s::Shifts, p::Period) = Shifts(beginning=shiftBeginning(s) + p, duration=shiftDuration(s))
