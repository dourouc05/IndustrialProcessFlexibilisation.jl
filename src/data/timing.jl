"""
Describes all timing issues in a problem to solve: mostly, the time horizon and the time step length,
but also some shift information.

  * `timeBeginning`: date at which the optimisation begins (for example, `now()` or `DateTime(2016, 12, 15, 6)`)
  * `timeHorizon`: complete time horizon considered for the optimisation (for example, `Week(1)`)
  * `timeStepDuration`: duration of a time step (for example, `Hour(1)` or `Minute(20)`)
  * `shiftBeginning`: date at which the first shift begins (for example, `now()` or `DateTime(2016, 12, 15, 6)`);
    it may be before `timeBeginning`, but not after
  * `shiftDuration`: duration of a worker's shift (for example, `Hour(8)`)
"""
struct Timing
  timeBeginning::DateTime
  timeHorizon::Period
  timeStepDuration::TimePeriod

  shiftBeginning::DateTime
  shiftDuration::TimePeriod

  function Timing(;timeBeginning::DateTime=error("Missing timeBeginning"),
                   timeHorizon::Period=error("Missing timeHorizon"),
                   timeStepDuration::TimePeriod=error("Missing timeStepDuration"),
                   shiftDuration::TimePeriod=error("Missing shiftDuration"),
                   shiftBeginning::DateTime=error("Missing shiftBeginning"))
    if typeof(shiftDuration) != Hour
      error("A shift is not an integer number of hours; please only use Hour(x) for shifts of x hours.")
    end

    if Dates.toms(Hour(1)) % Dates.toms(timeStepDuration) != 0
      error("The time step length does not divide one hour (a noninteger number of timesteps corresponds to one hour). Typical values are Minute(15), Minute(20), and Hour(1).")
    end

    if shiftBeginning > timeBeginning
      error("The shifts must begin at the latest at the beginning of the optimisation horizon.")
    end

    return new(timeBeginning, timeHorizon, timeStepDuration, shiftBeginning, shiftDuration)
  end
end

timeBeginning(t::Timing) = t.timeBeginning
timeHorizon(t::Timing) = t.timeHorizon
timeStepDuration(t::Timing) = t.timeStepDuration
timeEnding(t::Timing) = timeBeginning(t) + timeHorizon(t) - timeStepDuration(t) 
shiftBeginning(t::Timing) = t.shiftBeginning
shiftDuration(t::Timing) = t.shiftDuration

nOccurrencesPerPeriod(durationPeriod::Period, durationEvent::Period) = ceil(Int, Dates.toms(durationPeriod) / Dates.toms(durationEvent))

nTimeSteps(t::Timing, d::Period) = nOccurrencesPerPeriod(d, timeStepDuration(t))
nTimeSteps(t::Timing) = nTimeSteps(t, timeHorizon(t))
nTimeStepsPerShift(t::Timing) = nTimeSteps(t, shiftDuration(t))
nDays(t::Timing) = nOccurrencesPerPeriod(timeHorizon(t), Day(1))

daysOfWeekBetween(b::DateTime, e::DateTime) = map(d -> dayofweek(d), b:Day(1):e)
daysOfWeekUntil(t::Timing, until::DateTime) = daysOfWeekBetween(timeBeginning(t), until)
daysOfWeekFor(t::Timing, duration::Period) = daysOfWeekUntil(t, timeBeginning(t) + duration)

function eachTimeStep(t::Timing; from::DateTime=timeBeginning(t), kwargs...)
  """
  Loops over the time steps, from `from` (by default, the start of the optimisation) to `to` (by default, the end of
  optimisation), not inclusive for `to`. Alternatively, instead of `to`, a `duration` can be given (also not inclusive).
  """
  if length(kwargs) == 0
    # Most usual case: loop over all time steps, from the given start to the end of optimisation.
    return from : timeStepDuration(t) : timeBeginning(t) + timeHorizon(t) - timeStepDuration(t)
  elseif length(kwargs) != 1
    error("Should give either to or duration as argument (not both, not none).")
  end

  if ! isa(kwargs[1][2], DateTime) && ! isa(kwargs[1][2], Period)
    error("Unexpected type for " * string(kwargs[1][1]) * "; this function only accepts DateTime and Period as keyword arguments")
  end

  if kwargs[1][1] == :to && ! isa(kwargs[1][2], DateTime)
    error("If giving a to keyword argument, it must be a DateTime; did you mean to use duration?")
  elseif kwargs[1][1] == :duration && ! isa(kwargs[1][2], Period)
    error("If giving a duration keyword argument, it must be a Period; did you mean to use to?")
  end

  if kwargs[1][1] == :to
    return from : timeStepDuration(t) : kwargs[1][2] - timeStepDuration(t)
  elseif kwargs[1][1] == :duration
    return from : timeStepDuration(t) : from + kwargs[1][2] - timeStepDuration(t)
  else
    error("Unexpected keyword argument: " * string(kwargs[1][1]))
  end
end

# Intricacies start when the optimisation and shifts do not start at the same time. If the shifts start sooner,
# then the first shift is only partly within the optimisation horizon (and the last one too). However, if the difference
# is larger than one complete shift, then there is at least one completely useless shift, because it corresponds to
# zero time steps. Hence the second term:
#   - Dates.toms((timeBeginning(t) - shiftBeginning(t))) / Dates.toms(shiftDuration(t)) is the raw number of
#     supplementary shifts
#   - min(Dates.toms((timeBeginning(t) - shiftBeginning(t))), Dates.toms(shiftDuration(t))) ensures that at most
#     one shift is added.
# By invariant (imposed by the constructor), timeBeginning(t) >= shiftBeginning(t).
nShifts(t::Timing) = ceil(Int, Dates.toms(timeHorizon(t)) / Dates.toms(shiftDuration(t))) +
                        ceil(Int, min(Dates.toms((timeBeginning(t) - shiftBeginning(t))), Dates.toms(shiftDuration(t))) / Dates.toms(shiftDuration(t)))

"""
Computes the number of time steps between `d` and the beginning of the optimisation horizon within `t`. If this number
is not integer, the closest integer is returned.
"""
function dateToTimeStep(t::Timing, d::DateTime)
  if d < timeBeginning(t)
    error("Time " * string(d) * " before the optimisation horizon (" * string(timeBeginning(t)) * ").")
  end

  delta = Millisecond(d - timeBeginning(t)).value
  return 1 + round(Int, delta / Dates.toms(timeStepDuration(t)))
end

"""
Computes the number of shifts between `d` and the beginning of the shifts within `t`. If this number is not integer,
the closest integer is returned.
"""
function dateToShift(t::Timing, d::DateTime)
  if d < shiftBeginning(t)
    error("Time " * string(d) * " before the shift beginning (" * string(shiftBeginning(t)) * ").")
  end

  delta = Millisecond(d - shiftBeginning(t)).value
  return 1 + floor(Int, delta / Dates.toms(shiftDuration(t)))
end

"""
Shifts the timing object by the given period `p`. This means that the beginnings (both optimisation and shifts)
will be shifted by `p`.

The optimisation horizon can be set with the `horizon` keyword argument.
"""
function shift(t::Timing, p::Period; horizon::Period=Day(0))
  if horizon > Day(0)
    newHorizon = horizon
  else
    newHorizon = timeHorizon(t)
  end
  return Timing(timeBeginning=timeBeginning(t) + p, timeHorizon=newHorizon, timeStepDuration=timeStepDuration(t),
                shiftBeginning=shiftBeginning(t) + p, shiftDuration=shiftDuration(t))
end
