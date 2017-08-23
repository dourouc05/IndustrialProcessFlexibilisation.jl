struct TimingModel
  timing::Timing
  shifts::Shifts

  shiftOpen::Array{JuMP.Variable, 1} # Discretisation: step of shift lengths. 

  function TimingModel(m::Model, timing::Timing, shifts::Shifts)
    # Create the shift variables. 
    discretisation = shiftDurationsStep(shifts)
    shiftOpen = @variable(m, [t=1:nShifts(timing, shifts, discretisation)], Bin)
    for t in 1:nShifts(Timing, shifts, discretisation)
      setname(so[t], "shiftOpen_$(t)") 
    end

    return new(timing, shifts, shiftOpen)
  end
end

timing(hr::TimingModel) = hr.timing
shifts(hr::TimingModel) = hr.shifts
shiftOpen(hr::TimingModel, s::Int) = s.periodOpen[s]

shiftOpen(hr::TimingModel, d::DateTime) = shiftOpen(hr, dateToShift(hr, d))
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
shiftDurationsStart(s::TimingModel) = shiftDurationsStart(shifts(hr))
shiftDurationsStep(s::TimingModel) = shiftDurationsStep(shifts(hr))
shiftDurationsStop(s::TimingModel) = shiftDurationsStop(shifts(hr))
nShiftDurations(hr::TimingModel) = nShiftDurations(shifts(hr))
shiftDuration(hr::TimingModel) = shiftDuration(shifts(hr))
nShifts(hr::TimingModel) = nShifts(shifts(hr))
dateToShift(hr::TimingModel, d::DateTime) = dateToShift(shifts(hr), d)


# Define the constraints.
function postConstraints(m::Model, hr::TimingModel, forcedShifts::Array{Int, 1})
  # No link between time steps and shifts: time steps are linked to shifts directly through indexing.

  # TODO: Use a post-processor (for shifts 2:2:8, only implement 2-hour shifts in the model to keep it small, then choose how to make longer shifts outside the model, by merging small shifts so that, for each sequence, the number of combined shifts is minimum, with a minimum discrepancy between the lengths: prefer to have two 6-hour shifts rather than 8 then 4 hours)

  # Some shifts have already been decided previously.
  for s in 1:length(forcedShifts)
    @constraint(m, shiftOpen(hr, s) == forcedShifts[s]) # TODO: Rewrite forcedShifts as a more common data structure for this (with DateTime rather than indices).
  end
end
