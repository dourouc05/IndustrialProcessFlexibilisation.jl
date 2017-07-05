"""
Prepares a time series so that it looks like a prediction: the first few days are exactly known, then a few more days
are known with a lower accuracy, and finally only some average for the last few days.

The input time series can be much longer than the sum of the three duration arguments; in this case, the supplementary
information is used for smoothing.
"""
function smooth(ts::TimeArray, daysExact::Int, daysSmoothed::Int, daysApproximate::Int; smoothingConstant::Int=12, approximatingConstant::Int=72, approximatingWidth::Int=48)
  beginning = first(timestamp(ts))
  limitedTS = ts[beginning : beginning + Day(daysExact + daysSmoothed + daysApproximate)]
  timestamps = limitedTS.timestamp

  # First, the exact part.
  values = ts[beginning : Hour(1) : beginning + Day(daysExact)].values[1:end-1]

  # Second, the (slightly) smoothed part. Use moving average for this.
  smoothedTS = moving(ts[beginning + Day(daysExact) - Day(1) : Hour(1) : beginning + Day(daysExact + daysSmoothed) + Hour(smoothingConstant) + Day(1)], mean, smoothingConstant) # The first smoothingConstant-1 values disappear!
  push!(values, smoothedTS[beginning + Day(daysExact) + Hour(smoothingConstant - 6) : Hour(1) : beginning + Day(daysExact + daysSmoothed) + Hour(smoothingConstant - 6)].values[1:end-1]...)

  # Third, the approximate part (highly smoothed). Use a Gaussian filter for this (forward and backward).
  # The first few values (until approximatingConstant/2) and the last few are not impacted by this transformation,
  # but it is very unlikely they are needed to build the output.
  weightsCenter = approximatingConstant / 2 # Where the Gaussian function has a maximum.
  weights = [exp(- (i - weightsCenter) ^ 2 / approximatingWidth) for i in 1:approximatingConstant]
  weights /= sum(weights) # Normalisation step.

  approximateValues = similar(ts.values)
  for i in 1 : length(approximateValues)
    if i - weightsCenter < 1 || i + weightsCenter - 1 > length(approximateValues)
      approximateValues[i] = ts.values[i]
    else
      firstIndex = ceil(Int, i - weightsCenter)
      lastIndex = floor(Int, i + weightsCenter - 1)
      approximateValues[i] = sum(weights .* ts.values[firstIndex : lastIndex])
    end
  end

  approximatedTS = TimeArray(timestamp(ts), approximateValues, colnames(ts))
  push!(values, approximatedTS[beginning + Day(daysExact + daysSmoothed) : Hour(1) : beginning + Day(daysExact + daysSmoothed + daysApproximate)].values[1:end-1]...)

  # Done!
  return TimeArray(filter(t -> t >= beginning && t < beginning + Day(daysExact + daysSmoothed + daysApproximate), timestamp(ts)), values, colnames(ts))
end


"""
Emulates an increase in volatility for the given price scenario. Volatility is defined as the variation around
the average.

If `factor` is greater than one, then volatility is increased. If it is less than one, then it is decreased.
If it is one, this function has no effect.
"""
function changeVolatility(ts::TimeArray, factor::Float64)
  # Increase the difference wrt the average, but only day by day.
  v = values(ts)
  nDays = floor(Int, length(v) / 24)
  for d in 1:nDays
    avg = mean(v[24 * (d - 1) + 1 : 24 * d])

    for h in 1:24
      i = 24 * (d - 1) + h
      v[i] = avg + (v[i] - avg) * factor
    end
  end
  return TimeArray(timestamp(ts), v, colnames(ts))
end



smooth(eo::EnergyObjective, daysExact::Int, daysSmoothed::Int, daysApproximate::Int; kwargs...) = EnergyObjective(smooth(electricityPrice(eo), daysExact, daysSmoothed, daysApproximate; kwargs...), ) 
changeVolatility(eo::EnergyObjective, factor::Float64) = EnergyObjective(changeVolatility(electricityPrice(eo), factor))
