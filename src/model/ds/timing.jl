struct TimingModel
  timing::Timing
  shifts::Shifts

  shiftOpen::Array{Array{JuMP.Variable, 1}, 1} # For each possible shift, a list of JuMP variables. 

  function TimingModel(m::Model, timing::Timing, shifts::Shifts)
    shiftOpen = Array{JuMP.Variable, 1}[]
    for shift in shiftDurations(shifts)
      so = @variable(m, [t=1:nShifts(Timing, shifts, shift)], Bin)
      for t in 1:nShifts(Timing, shifts, shift)
        # TODO: ensure the name makes sense... Just a number? Would be much better to have a start date, but must be encoded properly... 
        setname(shiftOpen[t], "shiftOpen_start$(t)_duration$(shift.value)") # shift is always a Hour() object. 
      end
      push!(shiftOpen, so)
    end

    return new(timing, shifts, shiftOpen)
  end
end

timing(hr::TimingModel) = hr.timing
shifts(hr::TimingModel) = hr.shifts
shiftOpen(hr::TimingModel, s::Int) = hr.shiftOpen[s]

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
shiftDurationsStart(s::Shifts) = shiftDurationsStart(shifts(hr))
shiftDurationsStep(s::Shifts) = shiftDurationsStep(shifts(hr))
shiftDurationsStop(s::Shifts) = shiftDurationsStop(shifts(hr))
nShiftDurations(hr::TimingModel) = nShiftDurations(shifts(hr))
shiftDuration(hr::TimingModel) = shiftDuration(shifts(hr))
nShifts(hr::TimingModel) = nShifts(shifts(hr))
dateToShift(hr::TimingModel, d::DateTime) = dateToShift(shifts(hr), d)


# Define the constraints.
function postConstraints(m::Model, hr::TimingModel, forcedShifts::Array{Int, 1}=zeros(Int, 0))
  # No link between time steps and shifts: time steps are linked to shifts directly through indexing.

  # Some shifts have already been decided previously.
  for s in 1:length(forcedShifts)
    @constraint(m, shiftOpen(hr, s) == forcedShifts[s]) # TODO: Rewrite forcedShifts as a more common data structure for this (with DateTime rather than indices).
  end
end
