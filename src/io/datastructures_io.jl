function convert(::Type{Array}, ob::OrderBook, timing::Timing; shiftly::Bool=true, restrictToTiming::Bool=true)
  if ! shiftly # TODO: Implement.
    error("Not yet implemented: can only export the orders per shift for now.")
  end

  # Order book restricted to the period of the timing object if required. Mostly equivalent to removing the orders
  # before the beginning of Timing. 
  if restrictToTiming
    nob = fromto(ob, timeBeginning(timing), timeEnding(timing))
  else
    nob = ob
  end

  # Main loop over each product.
  obMatrix = zeros(nShifts(timing), nProducts(nob))
  for pid in 1:nProducts(nob)
    prod = productFromId(nob, pid)
    db = dueBy(nob, timeBeginning(timing), cumulative=true)
    t = 1 # Time index in obMatrix.
    if haskey(db, prod) # If order at the first time index, fill it.
      obMatrix[t, pid] = db[prod]
    end

    # Loop over all time indices, starting at the second. Pay attention to the way time is handled: the orders do not
    # necessarily have the same frequency as the output of this function. Hence integrate between two output time
    # indices. dueBy allows integrating from the beginning of times.
    d = timeBeginning(timing) + shiftDuration(timing)
    while d < timeEnding(timing)
      # Go to the next output time index.
      t += 1
      d += shiftDuration(timing)

      # Integrate the new orders between the last output time index and this one.
      db = dueBy(nob, d, cumulative=true)
      if haskey(db, prod)
        dbOld = dueBy(nob, d - shiftDuration(timing), cumulative=true)
        if haskey(dbOld, prod)
          obMatrix[t, pid] = db[prod] - dbOld[prod]
        else
          obMatrix[t, pid] = db[prod]
        end
      end
    end
  end

  # Output the matrix.
  return obMatrix
end

writecsv(io, ob::OrderBook, timing::Timing; shiftly::Bool=true, restrictToTiming::Bool=true) =
  writecsv(io, convert(Array, ob, timing, shiftly=shiftly, restrictToTiming=restrictToTiming))
  # TODO: Add the dates in the output?
