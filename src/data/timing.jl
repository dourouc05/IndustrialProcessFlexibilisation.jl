"""
Describes all abstract timing issues in a problem to solve: mostly, the time horizon and the time step length. 
Shift information is stored in a `Shifts` object.

  * `timeBeginning`: date at which the optimisation begins (for example, `now()` or `DateTime(2016, 12, 15, 6)`)
  * `timeHorizon`: complete time horizon considered for the optimisation (for example, `Week(1)`)
  * `timeStepDuration`: duration of a time step (for example, `Hour(1)` or `Minute(20)`)
"""
struct Timing
  timeBeginning::DateTime
  timeHorizon::Period
  timeStepDuration::TimePeriod

  function Timing(;timeBeginning::DateTime=error("Missing timeBeginning"),
                   timeHorizon::Period=error("Missing timeHorizon"),
                   timeStepDuration::TimePeriod=error("Missing timeStepDuration"))
    if Dates.toms(Hour(1)) % Dates.toms(timeStepDuration) != 0
      error("The time step length does not divide one hour (a noninteger number of timesteps corresponds to one hour). Typical values are Minute(15), Minute(20), and Hour(1).")
    end

    return new(timeBeginning, timeHorizon, timeStepDuration)
  end
end

timeBeginning(t::Timing) = t.timeBeginning
timeHorizon(t::Timing) = t.timeHorizon
timeStepDuration(t::Timing) = t.timeStepDuration
timeEnding(t::Timing) = timeBeginning(t) + timeHorizon(t) - timeStepDuration(t)

nOccurrencesPerPeriod(durationPeriod::Period, durationEvent::Period) = ceil(Int, Dates.toms(durationPeriod) / Dates.toms(durationEvent))

nTimeSteps(t::Timing, d::Period) = nOccurrencesPerPeriod(d, timeStepDuration(t))
nTimeSteps(t::Timing) = nTimeSteps(t, timeHorizon(t))
nDays(t::Timing) = nOccurrencesPerPeriod(timeHorizon(t), Day(1))

daysOfWeekBetween(b::DateTime, e::DateTime) = map(d -> dayofweek(d), b:Day(1):e)
daysOfWeekUntil(t::Timing, until::DateTime) = daysOfWeekBetween(timeBeginning(t), until)
daysOfWeekFor(t::Timing, duration::Period) = daysOfWeekUntil(t, timeBeginning(t) + duration)

"""
Loops over the time steps, from `from` (by default, the start of the optimisation) to `to` (by default, the end of
optimisation), not inclusive for `to`. Alternatively, instead of `to`, a `duration` can be given (also not inclusive).
"""
function eachTimeStep(t::Timing; from::DateTime=timeBeginning(t), kwargs...)
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
