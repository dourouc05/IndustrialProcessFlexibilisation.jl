struct TimingModel
  timing::Timing
  shifts::Shifts

  shiftOpen::Array{Array{JuMP.Variable, 1}, 1} # For each possible shift length, a list of JuMP variables. 
  periodOpen::Array{JuMP.Variable, 2} # For each period (think: time step) -- 1st index --, a list of JuMP variables for each shift length -- 2nd index.
  # The period corresponds to the step between shift lengths: if the lengths are 2:2:8 hours, the discretisation will be 2 hours. 
  # As a consequence, the same variable may be present more than once (only for shifts that are longer than these 2 hours). 

  function TimingModel(m::Model, timing::Timing, shifts::Shifts)
    # Create the shift variables. 
    shiftOpen = Array{JuMP.Variable, 1}[]
    for shift in shiftDurations(shifts)
      so = @variable(m, [t=1:nShifts(Timing, shifts, shift)], Bin)
      for t in 1:nShifts(Timing, shifts, shift)
        # TODO: ensure the name makes sense... Just a number? Would be much better to have a start date, but must be encoded properly... 
        setname(so[t], "shiftOpen_duration$(shift.value)h_number$(t)") # shift is always a Hour() object. 
      end
      push!(shiftOpen, so)
    end

    # Create the easy-to-access data structure periodOpen. 
    periodOpen = Array(JuMP.Variable, nShifts(Timing, shifts, shiftDurationsStep(shifts)), nShiftDurations(shifts))
    for sdIdx in 1:nShiftDurations(shifts)
      sd = shiftDurations(shifts)[sdIdx]
      nShortestShifts = round(Int, Dates.toms(shiftDurations(shifts)[sdIdx]) / Dates.toms(shiftDurations(shifts)[1]))

      for ts in 1:nShifts(Timing, shifts, sd)
        # sdIdx == 1: the variable is used only once, as it corresponds to the discretisation of periodOpen. 
        # sdIdx == 2: the variable is used twice, due to the way the shift lengths are constrained. 
        # This uses the hypothesis that the starting and stopping points are multiples of the step. 
        periodOpen[1 + (nShortestShifts - 1) * ts : nShortestShifts * ts, sdIdx] = shiftOpen[sdIdx][ts]
      end
    end

    return new(timing, shifts, shiftOpen)
  end
end

timing(hr::TimingModel) = hr.timing
shifts(hr::TimingModel) = hr.shifts
shiftOpen(hr::TimingModel, s::Int, sd::Int) = sum(s.periodOpen[s, sd]) 
shiftOpen(hr::TimingModel, s::Int) = sum(s.periodOpen[s, :]) 

timeStepOpen(hr::TimingModel, d::DateTime) = shiftOpen(hr, dateToShift(hr, d))


# Link to the methods of Timing. 
timeBeginning(hr::TimingModel) = timeBeginning(timing(hr))
timeHorizon(hr::TimingModel) = timeHorizon(timing(hr))
timeEnding(hr::TimingModel) = timeEnding(timing(hr))
timeStepDuration(hr::TimingModel) = timeStepDuration(timing(hr))

nTimeSteps(hr::TimingModel, d::Period) = nTimeSteps(timing(hr), d)
nTimeSteps(hr::TimingModel) = nTimeSteps(timing(hr))
nTimeStepsPerShift(hr::TimingModel) = nTimeStepsPerShift(timing(hr))
dateToTimeStep(hr::TimingModel, d::DateTime) = dateToTimeStep(timing(hr), d)
eachTimeStep(hr::TimingModel; kwargs...) = eachTimeStep(timing(hr); kwargs...)

# Link to the methods of Shifts. 
shiftBeginning(hr::TimingModel) = shiftBeginning(shifts(hr))
shiftDurations(hr::TimingModel) = shiftDurations(shifts(hr))
shiftDurationsStart(s::Shifts) = shiftDurationsStart(shifts(hr))
shiftDurationsStep(s::Shifts) = shiftDurationsStep(shifts(hr))
shiftDurationsStop(s::Shifts) = shiftDurationsStop(shifts(hr))
nShiftDurations(hr::TimingModel) = nShiftDurations(shifts(hr))
shiftDuration(hr::TimingModel) = shiftDuration(shifts(hr))
nShifts(hr::TimingModel) = nShifts(shifts(hr))
dateToShift(hr::TimingModel, d::DateTime) = dateToShift(shifts(hr), d)


# Define the constraints.
function postConstraints(m::Model, hr::TimingModel)
  # No link between time steps and shifts: time steps are linked to shifts directly through indexing.

  # At most one shift length can be selected for each duration. 
  for ts in eachTimeStep(hr)
    @constraint(m, timeStepOpen(hr, ts) <= 1)
  end

  # Strengthen the formulation. 
  # Disallow using short shifts when they make a larger "island". For example, the combination 0 1 1 0 for a given shift length is 
  # disabled: the corresponding longer-duration shift must be chosen. 
  # TODO: Implementation: [(1 - shift0,d1) + shift1,d1 + shift2,d1 + (1 - shift3, d1)]/4 + shift1,d2 <= 1

  # TODO: Objective to penalise short shifts!
  # TODO: Allow to use a post-processor (for shifts 2:2:8, only implement 2-hour shifts in the model to keep it small, then choose how to make longer shifts outside the model, by merging small shifts so that, for each sequence, the number of combined shifts is minimum, with a minimum discrepancy between the lengths: prefer to have two 6-hour shifts rather than 8 then 4 hours)
end

function postConstraints(m::Model, hr::TimingModel, forcedShifts::Array{Int, 1})
  # TODO: Use me! 
  # Some shifts have already been decided previously.
  for s in 1:length(forcedShifts)
    @constraint(m, shiftOpen(hr, s) == forcedShifts[s]) # TODO: Rewrite forcedShifts as a more common data structure for this (with DateTime rather than indices).
  end
end
