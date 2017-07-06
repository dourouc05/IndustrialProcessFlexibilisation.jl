struct TimingModel
  timing::Timing

  shiftOpen::Array{JuMP.Variable, 1}

  function TimingModel(m::Model, timing::Timing)
    shiftOpen = @variable(m, [t=1:nShifts(timing)], Bin)
    for t in 1:nShifts(timing)
      setname(shiftOpen[t], "shiftOpen_$(t)")
    end

    return new(timing, shiftOpen)
  end
end

timing(hr::TimingModel) = hr.timing
shiftOpen(hr::TimingModel, s::Int) = hr.shiftOpen[s]

shiftOpen(hr::TimingModel, d::DateTime) = shiftOpen(hr, dateToShift(hr, d))
timeStepOpen(hr::TimingModel, d::DateTime) = shiftOpen(hr, dateToShift(hr, d))


# Link to the methods of Timing.
timeBeginning(hr::TimingModel) = timeBeginning(timing(hr))
timeHorizon(hr::TimingModel) = timeHorizon(timing(hr))
timeEnding(hr::TimingModel) = timeEnding(timing(hr))
timeStepDuration(hr::TimingModel) = timeStepDuration(timing(hr))
shiftBeginning(hr::TimingModel) = shiftBeginning(timing(hr))
shiftDuration(hr::TimingModel) = shiftDuration(timing(hr))

nTimeSteps(hr::TimingModel, d::Period) = nTimeSteps(timing(hr), d)
nTimeSteps(hr::TimingModel) = nTimeSteps(timing(hr))
nTimeStepsPerShift(hr::TimingModel) = nTimeStepsPerShift(timing(hr))
nShifts(hr::TimingModel) = nShifts(timing(hr))
dateToTimeStep(hr::TimingModel, d::DateTime) = dateToTimeStep(timing(hr), d)
dateToShift(hr::TimingModel, d::DateTime) = dateToShift(timing(hr), d)
eachTimeStep(hr::TimingModel; kwargs...) = eachTimeStep(timing(hr); kwargs...)


# Define the constraints.
function postConstraints(m::Model, hr::TimingModel, forcedShifts::Array{Int, 1}=zeros(Int, 0))
  # No link between time steps and shifts: time steps are linked to shifts directly through indexing.

  # Some shifts have already been decided previously.
  for s in 1:length(forcedShifts)
    @constraint(m, shiftOpen(hr, s) == forcedShifts[s]) # TODO: Rewrite forcedShifts as a more common data structure for this (with DateTime rather than indices).
  end
end
