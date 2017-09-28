"""
Transforms a binary array of shifts into an array of upper-case letters indicating which shift in the day is worked:

  - `M` for the morning shift (first one)
  - `A` for the afternoon shift (second one)
  - `N` for the night shift (third one)

By hypothesis, a worker/team can only work one shift per day.

The input matrix is organised as follows:

  - the first index corresponds to the workers/teams
  - the second index corresponds to the successive *shifts*

The output matrix is organised as follows:

  - the first index corresponds to the workers/teams
  - the second index corresponds to the successive *days*
  - the first line (i.e. `[:, 1]`) is the order of the day in the week (1 for Monday, 2 for Tuesday, up to 7
    7 for Sunday), but only if the keyword argument `firstDay` is given.
    It may be either a date (such as `DateTime(2017, 1, 1)`) or directly the number of the first day.
"""
function shiftsAsLetters(solution::BitArray{2}; firstDay::Union{DateTime, Int}=0) # TODO: To test!
  nTeams = size(solution, 1)
  nShifts = size(solution, 2)
  nDays = floor(Int, nShifts / 3)

  if nShifts != 3 * nDays # TODO: To test explicitly!
    error("shiftsAsLetters considers exactly three shifts per day.")
  end

  # Allocate the output array.
  if firstDay == 0
    letters = Array{Char}(nTeams, nDays)
  else
    letters = Array{Char}(1 + nTeams, nDays)
  end

  # Fill this array.
  for team in 1:nTeams
    for d in 1:nDays
      # The day in week is in the first line, i.e. the rest of the data must be shifted.
      if firstDay == 0
        teamSolIdx = team
      else
        teamSolIdx = team + 1
      end

      # Comput the day of week if needed.
      if firstDay != 0
        # First determine the day of week as an integer.
        if isa(firstDay, Int)
          rawCurrentDayOfWeek = (firstDay + (iter - 1) * nDaysBetweenIterations + d - 1) % 7
          dow = (rawCurrentDayOfWeek == 0) ? 7 : rawCurrentDayOfWeek # 1: Monday; 7: Sunday
        else
          dow = dayofweek(firstDay + Day(d - 1))
        end

        # Then convert it as a character and put it in the array. char() assumes it is given a code point, hence string().
        letters[1, d] = string(dow)[1]
      end

      # Check at most one shift is worked over the day.
      if sum(solution[team, (3 * (d - 1) + 1) : (3 * (d - 1) + 1) + 2]) > 1 # TODO: To test explicitly!
        error("At day " * string(d) * ", more than one shift is worked.")
      end

      # Fill the matrix for the actual shift.
      if solution[team, (3 * (d - 1) + 1)] == 1 # Morning
        letters[teamSolIdx, d] = 'M'
      elseif solution[team, (3 * (d - 1) + 1) + 1] == 1 # Afernoon
        letters[teamSolIdx, d] = 'A'
      elseif solution[team, (3 * (d - 1) + 1) + 2] == 1 # Night
        letters[teamSolIdx, d] = 'N'
      else # Rest.
        letters[teamSolIdx, d] = 'R'
      end
    end
  end

  # Done!
  return letters
end

"""
Counts the number of time a specific shift appears in the given solution (as returned by `shiftsAsLetters`).
The shift is given by a letter, following the same conventions as `shiftsAsLetters`. The output is a vector,
with one element for each worker/team.

To count all worked shifts, use `'w'` as `shift` (a lower-case W, as opposed to upper-case shifts).

To count worked shifts for only specific days, use the keyword argument `days` and assign it to an array of integers
corresponding to the days to count (1 for Monday, just like `shiftsAsLetters`). For ease, you can also use `weekend`
to select the weekend (Saturday and Sunday); this option cannot be used at the same time as `days`.
"""
function countShifts(solution::Array{Char, 2}, shift::Char; weekend::Bool=false, days::Array{Int, 1}=Int[])
  # TODO: To test! shift = M, A, N, R, w (w == M + A + N). weekend. days ([6, 7] == weekend).
  # TODO: To test specifically: week ends seem to be wrong for now (or used to). 
  nTeams = size(solution, 1)
  nDays = size(solution, 2)

  # First detect whether the first line indicates days of week, or is directly shift data.
  if parse(Int, solution[1, 1]) >= 1 && parse(Int, solution[1, 1]) <= 7
    hasWeeks = true
    nTeams -= 1
  else
    hasWeeks = false
  end

  # Deal with specific days.
  if weekend && length(days) > 0
    error("Cannot specify both weekend and days at the same time. ")
  end
  if (length(days) > 0 || weekend) && ! hasWeeks
    error("The input array does not have the day information; cannot count only for specific days.")
  end

  if weekend
    days = [6, 7]
  end

  # Main loop.
  n = zeros(Int, nTeams)
  for team in 1:nTeams
    if hasWeeks
      teamSolIdx = team + 1
    else
      teamSolIdx = team
    end

    for d in 1:nDays
      # Skip days that should not be taken into account.
      if length(days) > 0 && ! in(solution[1, d], days)
        continue
      end

      # Count if the sought shift is worked on this day.
      if solution[teamSolIdx, d] == shift || (shift == 'w' && in(solution[teamSolIdx, d], ['M', 'A', 'N']))
        n[team] += 1
      end
    end
  end

  # Done!
  return n
end

"""
Counts the number of time a specific sequence of shifts appears in the given solution (as returned by `shiftsAsLetters`).
The shift sequence is given by a vector of letters, following the same conventions as `shiftsAsLetters`.
The output is a vector, with one element for each worker/team.

To count worked shifts for only specific days, use the keyword argument `days` and assign it to an array of integers
corresponding to the days to count (1 for Monday, just like `shiftsAsLetters`). For ease, you can also use `weekend`
to select the weekend (Saturday and Sunday); this option cannot be used at the same time as `days`.
"""
function countShiftSequences(solution::Array{Char, 2}, shiftSequence::Array{Char, 1}; weekend::Bool=false, days::Array{Int, 1}=Int[]) # TODO: To test!
  nTeams = size(solution, 1)
  nDays = size(solution, 2)

  # First detect whether the first line indicates days of week, or is directly shift data.
  if parse(Int, solution[1, 1]) >= 1 && parse(Int, solution[1, 1]) <= 7
    hasWeeks = true
    nTeams -= 1
  else
    hasWeeks = false
  end

  # Deal with specific days.
  if weekend && length(days) > 0
    error("Cannot specify both weekend and days at the same time. ")
  end
  if (length(days) > 0 || weekend) && ! hasWeeks
    error("The input array does not have the day information; cannot count only for specific days.")
  end

  if weekend
    days = [6, 7]
  end

  # Main loop.
  n = zeros(Int, nTeams)
  for team in 1:nTeams
    if hasWeeks
      teamSolIdx = team + 1
    else
      teamSolIdx = team
    end

    # Very basic search algorithm for a sequence, this could be heavily optimised
    # (https://en.wikipedia.org/wiki/String_searching_algorithm has many ideas on the topic). However, this is not
    # really required. (Before going into implementing this algorithm, try to transform the sequences as strings,
    # and then use regular expressions.)
    for d in 1:(nDays - length(shiftSequence) + 1)
      # Skip days that should not be taken into account.
      if length(days) > 0 && ! in(solution[1, d], days)
        continue
      end

      # Count if a sought sequence starts on this day.
      if all(solution[teamSolIdx, d : d + length(shiftSequence) - 1] .== shiftSequence)
        n[team] += 1
      end
    end
  end

  # Done!
  return n
end

"""
Finds work cycles in the shifts, i.e. worked periods separated by at least two rest days. The returned data structure
is an array, each element corresponding to a team and being an array of pairs (the beginning and end of each cycle).
"""
function findCycles(solution::Array{Char, 2}) # TODO: To test!
  nTeams = size(solution, 1)
  nDays = size(solution, 2)

  # First detect whether the first line indicates days of week, or is directly shift data.
  if parse(Int, solution[1, 1]) >= 1 && parse(Int, solution[1, 1]) <= 7
    hasWeeks = true
    nTeams -= 1
  else
    hasWeeks = false
  end

  # Allocate the output array. One array for each team. The elements are the pairs of each cycle (beginning, end).
  cycles = Array{Array{Pair{Int, Int}, 1}, 1}(nTeams)

  # Main loop.
  for team in 1:nTeams
    if hasWeeks
      teamSolIdx = team + 1
    else
      teamSolIdx = team
    end

    # Initialise the cycle lookup for this team.
    cycles[team] = []
    b = 0 # Beginning of a cycle (first worked day)
    e = 0 # End of a cycle (last worked day)

    # Loop over days, look for beginnings and ends of cycles.
    for d in 1:nDays
      # If a cycle has not yet begun (b == 0), let's start it.
      if b == 0 && solution[1 + team, d] != 'R'
        b = d
        continue # Nothing else to do in this iteration.
      end

      # If there are two consecutive Rs when the cycle has begun, then it ends.
      if b > 0 && d >= 3 && solution[teamSolIdx, d] == 'R' && solution[teamSolIdx, d - 1] == 'R'
        e = d - 2
        push!(cycles[team], b => e)
        b = 0
        e = 0
        continue # Nothing else to do in this iteration.
      end

      # If a cycle has begun and is not yet finised as of the last shift, still consider a cycle.
      if d == nDays && b > 0
        if solution[teamSolIdx, d] == 'R'
          e = d - 1
        else
          e = d
        end

        push!(cycles[team], b => e)
      end
    end
  end

  # Done!
  return cycles
end

function modelMultiple(p::Plant, ob::OrderBook, timing::Timing, shifts::Shifts, obj::ProductionObjective,
                       priorNoticeDelay::Int, notificationFrequency::Int, completeHorizon::Int, optimisationHorizonForOrderBook::Int, optimisationHorizonForHR::Int, hoursPerShift::Int,
                       timeBetweenShifts::Int, consecutiveDaysOff::Tuple{Int, Int}, maxHoursPerWeek::Int, hoursContract::Tuple{Int, Int},
                       coeffs::Tuple{Float64, Float64, Float64, Float64, Float64, Float64}, hrAlgo::Symbol, nTeams::Int,
                       solver;
                       outFolder::AbstractString="./")
  # TODO: Find a better name for optimisationHorizonForHR (not really an optimisation horizon, as a larger horizon is computed, but only this part is communicated to the workers).

  # Graphically, the iteration horizons vary according to:
  #          +---------------------+------------ ⋯
  #   it 1:  |  priorNoticeDelay   |
  #          +---------------------+------------ ⋯
  #          ^
  #          timeBeginning(timing)
  #
  #               +---------------------+------------ ⋯
  #   it 2:       |  priorNoticeDelay   |
  #               +---------------------+------------ ⋯
  #          ^---^
  #          notificationFrequency
  #
  #                    +---------------------+------------ ⋯
  #   it 3:            |  priorNoticeDelay   |
  #                    +---------------------+------------ ⋯
  #          ^--------^
  #          2 * notificationFrequency
  #
  # The term `priorNoticeDelay - notificationFrequency` gives the part of the solution of the subsequent iterations
  # (i >= 2) that is forced by the previous iteration(s). The part that is kept for the next iterations is thus
  # `priorNoticeDelay - (priorNoticeDelay - notificationFrequency)` (i.e. `notificationFrequency`).

  # Structure of the output HDF5 file:
  #  \ params: global parameters for the simulation
  #    \ arguments: arguments to the simulation function
  #      - priorNoticeDelay
  #      - notificationFrequency
  #      - completeHorizon
  #      - optimisationHorizonForOrderBook
  #      - optimisationHorizonForHR
  #      - hoursPerShift
  #      - timeBetweenShifts
  #      - consecutiveDaysOff
  #      - consecutiveDaysOffEvery
  #      - maxHoursPerWeek
  #      - hoursContract
  #      - hoursContractEvery
  #      - hrCoeffs
  #    \ production: derived parameters regarding the production model
  #      - electricityPrice: price of electricity over the complete time horizon, with a time step of one hour
  #    \ hr: derived parameters regarding the HR model
  #    \ simulation: derived parameters regarding the whole simulation (but not a model specifically)
  #      - numberIterations: number of iterations to perform
  #    \ time: derived parameters regarding timing
  #      - firstDay: the first day of the optimisation horizon, as a string (such as 2017-01-01T05:00:00)
  #      - firstDayName: name of the first day (Monday, Tuesday, etc.)
  #      - firstDayOfWeek: day of the week of the first day (0 for Monday, 1 for Tuesday, etc.)
  #  \ itX: parameters and results of iteration X
  #    \ production
  #      - electricityPrice
  #    \ hr
  #      - solutionTime
  #      - bounds
  #      \ communicated
  #        - shifts
  #        - shiftsMore (X > 1)
  #        - shiftsLess (X > 1)
  #      \ global
  #        - shifts
  #        - estimatedShifts
  #        - shiftsMore (X > 1)
  #        - shiftsMore (X > 1)
  #        - numberShiftsMore (X > 1)
  #        - numberShiftsLess (X > 1)
  #      \ objective
  #        - total
  #        - slackBudgetMin
  #        - slackBudgetMax
  #        - slackOvertime
  #        - initialSolutionDifference
  #        - unfairness
  #  \ results: results of the whole simulation, gathering the results of each iteration
  # TODO: Plant description and the other arguments?

  ## Do some error checking.
  if optimisationHorizonForOrderBook < 8
    # Required for price smoothing to work.
    # TODO: 3 days for good price, 4 days for lower-quality prediction, the rest as poor predictions -> parameter!
    error("Optimisation horizon too short: you must use at least eight days for the production model (current value: optimisationHorizonForOrderBook = " * string(optimisationHorizonForOrderBook) * ").")
  end

  if notificationFrequency > priorNoticeDelay
    error("The solution must be computed at least as often (notificationFrequency = " * string(notificationFrequency) * ") as the notification are done (priorNoticeDelay = " * string(priorNoticeDelay) * "). ")
  end

  if optimisationHorizonForOrderBook < optimisationHorizonForHR
    error("The optimisation horizon for the production part (optimisationHorizonForOrderBook = " * string(optimisationHorizonForOrderBook) * ") is smaller than that of HR (optimisationHorizonForHR = " * string(optimisationHorizonForHR) * ").")
  end

  # Ensure exporting can be done, i.e. remove the file if it exists. Otherwise, adding new data sets will cause troubles.
  outFile = outFolder * "details.h5"
  if isfile(outFile)
    rm(outFile)
  end

  ## Compute the basic global parameters.
  shiftsPerDay = round(Int, 24 / hoursPerShift) # TODO: TO REMOVE! No more makes sense. 

  # The first iteration provides the solution for `priorNoticeDelay` days.
  # Each subsequent iteration provides the solution for `notificationFrequency` days.
  # In other words, the complete horizon is given by (I is the number of iterations):
  #     completeHorizon = priorNoticeDelay + (I - 1) * notificationFrequency
  # The following formula is obtained by solving this equation for I.
  nIterations = ceil(Int, (completeHorizon - priorNoticeDelay) / notificationFrequency) + 1
  wholeTiming = Timing(timeBeginning=timeBeginning(timing), timeHorizon=Day(completeHorizon), timeStepDuration=timeStepDuration(timing))

  # Write it down.
  h5open(outFile, "w") do f
    write(f, "params/production/orderBook", convert(Array, ob, timing))
    if hasObjective(:electricity, obj)
      priceScenario = electricityPrice(find(EnergyObjective, obj))
      priceScenario = priceScenario[timeBeginning(wholeTiming) : Hour(1) : timeEnding(wholeTiming)]
      write(f, "params/production/electricityPrice", values(priceScenario))
    end
    write(f, "params/hr/numberTeams", nTeams)
    write(f, "params/hr/unfairnessFormulation", "integer")

    write(f, "params/time/firstDay", string(timeBeginning(timing)))
    write(f, "params/time/firstDayName", dayname(timeBeginning(timing)))
    write(f, "params/time/firstDayOfWeek", dayofweek(timeBeginning(timing)))
    write(f, "params/simulation/numberIterations", nIterations)
    write(f, "params/arguments/priorNoticeDelay", priorNoticeDelay)
    write(f, "params/arguments/notificationFrequency", notificationFrequency)
    write(f, "params/arguments/completeHorizon", completeHorizon)
    write(f, "params/arguments/optimisationHorizonForOrderBook", optimisationHorizonForOrderBook)
    write(f, "params/arguments/optimisationHorizonForHR", optimisationHorizonForHR)
    write(f, "params/arguments/hoursPerShift", hoursPerShift)
    write(f, "params/arguments/timeBetweenShifts", timeBetweenShifts)
    write(f, "params/arguments/consecutiveDaysOff", consecutiveDaysOff[1])
    write(f, "params/arguments/consecutiveDaysOffEvery", consecutiveDaysOff[2])
    write(f, "params/arguments/maxHoursPerWeek", maxHoursPerWeek)
    write(f, "params/arguments/hoursContract", hoursContract[1])
    write(f, "params/arguments/hoursContractEvery", hoursContract[2])
    write(f, "params/arguments/hrCoeffs", [coeffs[1], coeffs[2], coeffs[3], coeffs[4], coeffs[5]])
  end

  ## Prepare to store the results of all iterations.
  productionResults = ProductionModelResults[]
  hrResults = HRModelResults[]

  solutions = BitArray{2}[]
  committedSolutions = BitArray{2}[]
  communicatedSolutions = BitArray{2}[]
  shiftsLess = BitArray{2}[]
  shiftsMore = BitArray{2}[]
  allBounds = zeros(2, nIterations)
  workedHours = zeros(nTeams, nIterations) # Cumulative number of hours decided at each iteration.
  producedQuantities = Array{Dict{Product, Float64}, 1}() # What is produced during the committed part of each iteration, cumulative.
  dailyObjectives = Array{Array{Any, 2}, 1}() # The daily values of the production stage.
  committedDailyObjectives = Array{Array{Any, 2}, 1}() # The daily values of the production stage.

  ## Now, can go to work. Try to export results as soon as possible, in case of a crash.
  for i in 1:nIterations
    println(" ========================================================================================================= ")
    println(" =============== Iteration number: " * string(i) * " out of " * string(nIterations) * " ========================================================== ")
    println(" ========================================================================================================= ")

    ## Rework the data for this new iteration.
    # Alter the timing for this window.
    nt = shift(timing, (i - 1) * Day(notificationFrequency); horizon=Day(optimisationHorizonForOrderBook))

    # Change electricity prices (if they are part of the objective function).
    nobj = obj
    if hasObjective(:electricity, obj)
      # Apply some smoothing of the price to mimic uncertainty about the future prices.
      priceScenario = electricityPrice(find(EnergyObjective, obj))
      priceScenario = priceScenario[timeBeginning(nt) : Hour(1) : last(timestamp(priceScenario))] # Get rid of the part from the previous iteration, if any.
      newPrices = smooth(priceScenario, 3, 4, optimisationHorizonForOrderBook - 3 - 4)
      nobj = replace(obj, :electricity, EnergyObjective(newPrices, nt)) # Replace the prices in the objective function
    end

    ## Optimisation: production.
    # Set of shift indices that should carry over from previous iteration (if any). 
    forcedShiftsIndices = (i == 1) ? Int[] : filter(1:length(productionResults[i - 1].shiftsOpen)) do s
      # Take the shifts that have not yet been worked (notificationFrequency) but that were still decided by the previous iteration (priorNoticeDelay). 
      d = productionResults[i - 1].shiftsOpen[s][1]
      return d >= timeBeginning(nt) + Day(notificationFrequency) && d <= timeBeginning(nt) + Day(priorNoticeDelay)
    end

    # Compute the HR requirements with a production model.
    println(" --------------- Production model ------------------------------------------------------------------------ ")
    if i == 1 # No initial solution to respect.
      pr = productionModel(p, ob, nt, shifts, nobj, outfile=outFolder * "m_prod_" * string(i) * ".lp", solver=solver)
    else # Has already something that is produced
      forcedShifts = vec(sum(solutions[i - 1][:, forcedShiftsIndices], 1))
      pr = productionModel(p, ob, nt, shifts, nobj, alreadyProduced=producedQuantities[i - 1], forcedShifts=forcedShifts, outfile=outFolder * "m_prod_" * string(i) * ".lp", solver=solver)
    end
    push!(productionResults, pr)

    if ! pr.feasibility
      println(" --------------- Production model infeasible! ---------------------------------------------------------- ")
      return false, :Production
    else
      println(" --------------- Production model objective: $(getobjectivevalue(mP)) -------------------------------------------------- ")
    end

    iterationQuantities = vec(sum(pr.productionPlanOutput[1:nTimeSteps(timing, Day(priorNoticeDelay)), :], 1))

    ## Optimisation: HR.
    # Now try to make the teams. Distinction based on the number of iterations performed: if this is the first
    # iteration, or a later one.
    println(" --------------- HR model -------------------------------------------------------------------------------- ")
    if i == 1 # No initial solution to respect.
      ## Determine the global budget.
      boundsHours = (3 * 8., 6 * 8.) # Basic bounds for now, first iteration.
      # Can between 3 and 6 shifts (24 and 48 hours), hence a lot of flexibility.
      # These bounds are used for all the teams.

      ## Perform team assignment.
      hrr = teamModel(pr.shiftsOpen, timeBetweenShifts,
                      consecutiveDaysOff, maxHoursPerWeek, boundsHours,
                      nTeams, coeffs,
                      (hrAlgo == :smart) ? falses(0, 0) : shiftFixedSchedule(shiftsFiveEight, (i - 1) * notificationFrequency),
                      outfile=outFolder * "m_hr_" * string(i) * ".lp", solver=solver)
      push!(hrResults, hrr)

      if ! hrr.feasibility
        println(" --------------- HR model infeasible! ---------------------------------------------------------------- ")
        return false, :HR
      else
        println(" --------------- HR model objective: $(getobjectivevalue(mH)) ---------------------------------------------------------- ")
      end

      ## Save some results from this iteration.
      # Number of hours each time has worked during the shifts that are fixed in this iteration (i.e. priorNoticeDelay days).
      # This variable is cumulative over the iterations.
      workedHours[:, i] = sum(productionResults[i].shiftsOpen[s][2].value * hrr.teamAssignment[:, s] for idx in 1:length(productionResults[i].shiftsOpen), 2)

      # Quantity of each product made during this iteration.
      iterationQuantitiesDict = Dict{Product, Float64}(productFromId(ob, pid) => iterationQuantities[pid] for pid in 1:nProducts(ob))
      push!(producedQuantities, iterationQuantitiesDict)
    else # Use the previous iteration as an initial solution.
      ## Determine the global budget.
      totalBudget = hoursContract[2] * hoursContract[1] # TODO: Hypothesis, the complete optimisation loop is performed on hoursContract[2] weeks.
      consumedBudget = sum(vec(workedHours[:, i - 1])) / nTeams # How many hours have already been worked?
      remainingBudget = (totalBudget - consumedBudget) / nTeams

      # These bounds are used for all the teams, independently of how much they have worked: only the average is used.
      # First start with a rough approximation, then see if it is needed to modify it, with respect to the remaining
      # budget (the upper bound may never go over this remaining budget).
      boundsH = Float64[3 * 8, 6 * 8]
      if boundsH[2] >= remainingBudget
        boundsH[2] = remainingBudget
      end

      # At the last iteration, consume the remaining budget.
      if i == nIterations
        boundsH[1] = remainingBudget
      end

      # No negative values are allowed.
      boundsH[boundsH .<= 0] = 0.

      # The upper bound must be greater than or equal to the lower bound.
      if boundsH[2] <= boundsH[1]
        boundsH[2] = boundsH[1]
      end

      # Make the tuple out of the array.
      boundsHours = (boundsH[1], boundsH[2])

      ## Perform team assignment.
      hrr = teamModel(pr.shiftsOpen, timeBetweenShifts,
                      consecutiveDaysOff, maxHoursPerWeek, boundsHours,
                      nTeams, coeffs,
                      (hrAlgo == :smart) ? falses(0, 0) : shiftFixedSchedule(shiftsFiveEight, (i - 1) * notificationFrequency),
                      solutions[i - 1][:, forcedShiftsIndices], :forceThenHint, 
                      outfile=outFolder * "m_hr_" * string(i) * ".lp", solver=solver)>
      push!(hrResults, hrr)

      if ! hrr.feasibility
        println(" --------------- HR model infeasible! ---------------------------------------------------------------- ")
        return false, :HR
      else
        println(" --------------- HR model objective: $(getobjectivevalue(mH)) ---------------------------------------------------------- ")
      end

      ## Save some results from this iteration.
      # Number of worked hours (details in the comment for i == 1). 
      workedHours[:, i] = workedHours[:, i - 1] + sum(productionResults[i].shiftsOpen[s][2].value * hrr.teamAssignment[:, s] for idx in 1:length(productionResults[i].shiftsOpen), 2)

      # Quantity of each product made during this iteration.
      iterationQuantitiesDict = Dict{Product, Float64}(productFromId(ob, pid) => iterationQuantities[pid] + producedQuantities[i - 1][productFromId(ob, pid)] for pid in 1:nProducts(ob))
      push!(producedQuantities, iterationQuantitiesDict)
    end

    ## Fill internal data structures.
    # Raw solution in internal data structures.
    push!(solutions, round.(Bool, round.(Int, hrResults[i].teamAssignment)))
    push!(shiftsLess, round.(Bool, round.(Int, hrResults[i].objectiveDifferenceInitialSolutionLess)))
    push!(shiftsMore, round.(Bool, round.(Int, hrResults[i].objectiveDifferenceInitialSolutionMore)))

    # Parts of the solution that make sense for the HR, internal data structures.
    committedIndices = filter((s) -> productionResults[i - 1].shiftsOpen[s][1] <= timeBeginning(nt) + Day(priorNoticeDelay), 1:length(productionResults[i].shiftsOpen)) # Take the shifts that have been decided by the current iteration (priorNoticeDelay). 
    communicatedIndices = filter((s) -> productionResults[i - 1].shiftsOpen[s][1] <= timeBeginning(nt) + Day(optimisationHorizonForHR), 1:length(productionResults[i].shiftsOpen))

    committedShifts = hrResults[i].teamAssignment[:, committedIndices]
    communicatedEstimatedShifts = hrResults[i].teamAssignment[:, 1:communicatedIndices]
    push!(committedSolutions, round.(Bool, round.(Int, committedShifts)))
    push!(communicatedSolutions, round.(Bool, round.(Int, communicatedEstimatedShifts)))

    h5open(outFile, "r+") do f
      ## Export production details.
      if hasObjective(:electricity, obj)
        write(f, "it" * string(i) * "/production/electricityPrice", values(newPrices))
      end
      write(f, "it" * string(i) * "/production/orderBook", convert(Array, ob, nt))

      write(f, "it" * string(i) * "/production/solutionTime", getsolvetime(mP))
      write(f, "it" * string(i) * "/production/shifts", round.(Int, shifts))

      if isa(obj, ObjectiveCombination)
        objectiveNames = Array{String}(nObjectives(obj))
        objectives = Array{Float64}(nObjectives(obj), floor(Int, length(shifts) / 3)) # One value per day.
        for o in 1:nObjectives(obj)
          if symbol(obj, o) == :electricity
            objectiveNames[o] = "Electricity"
          elseif symbol(obj, o) == :hr
            objectiveNames[o] = "HR"
          elseif symbol(obj, o) == :hr_fake
            objectiveNames[o] = "HR penalisation"
          else
            objectiveNames[o] = "unknown"
          end
          objectives[o, :] = getvalue(AffExpr[objective(mP, objective(obj, o), pm, d, d + Day(1)) for d in timeBeginning(nt):Day(1):(timeBeginning(nt) + timeHorizon(nt) - timeStepDuration(pm))])
        end

        write(f, "it" * string(i) * "/production/objectiveNames", objectiveNames)
        write(f, "it" * string(i) * "/production/objectives", objectives)
        push!(dailyObjectives, objectives)
        push!(committedDailyObjectives, objectives[:, 2:min(priorNoticeDelay + 1, size(objectives, 2))])
      end

      ## Export HR details.
      write(f, "it" * string(i) * "/hr/solutionTime", getsolvetime(mH))

      # Raw solution and differences with the previous iteration (if any).
      write(f, "it" * string(i) * "/hr/global/shifts", round.(Int, solutions[i]))
      if i > 1 # At the first iteration, there is no previous solution, so no difference to the previous solution.
        write(f, "it" * string(i) * "/hr/global/shiftsMore", round.(Int, shiftsMore[i]))
        write(f, "it" * string(i) * "/hr/global/shiftsLess", round.(Int, shiftsLess[i]))
      end

      # The bounds mechanism.
      allBounds[:, i] = [boundsHours[1], boundsHours[2]]
      write(f, "it" * string(i) * "/hr/bounds", [boundsHours[1], boundsHours[2]])

      # Parts of the solution for the HR.
      write(f, "it" * string(i) * "/hr/communicated/committedShifts", committedShifts)
      write(f, "it" * string(i) * "/hr/communicated/estimatedShifts", communicatedEstimatedShifts)
      if i > 1 # At the first iteration, there is no previous solution, so no difference to the previous solution.
        smi = round.(Int, shiftsMore[i][:, communicatedIndices])
        sli = round.(Int, shiftsLess[i][:, communicatedIndices])
        write(f, "it" * string(i) * "/hr/communicated/shiftsMore", smi)
        write(f, "it" * string(i) * "/hr/communicated/shiftsLess", sli)
        write(f, "it" * string(i) * "/hr/communicated/numberShiftsMore", sum(smi, 2))
        write(f, "it" * string(i) * "/hr/communicated/numberShiftsLess", sum(sli, 2))
      end

      # Objective function.
      write(f, "it" * string(i) * "/hr/objective/total", hrObj)
      write(f, "it" * string(i) * "/hr/objective/slackBudgetMin", hrSlackMin)
      write(f, "it" * string(i) * "/hr/objective/slackBudgetMax", hrSlackMax)
      write(f, "it" * string(i) * "/hr/objective/slackOvertime", hrSlackOver)
      write(f, "it" * string(i) * "/hr/objective/initialSolutionDifference", hrInitialSolDelta)
      write(f, "it" * string(i) * "/hr/objective/unfairness", hrUnfair)

      ## HR: perform a few analyses (just this iteration).
      # This only applies when shifts follow predictable patterns, i.e. not when they are being optimised! 
      # Most analyses require three shifts a day, i.e. 8-hour shifts. 
      if nShiftDurations(shifts) == 1 && shiftDuration(shift) == Hour(8)
        shiftsBool = round.(Bool, round.(Int, solutions[i]))
        letters = shiftsAsLetters(shiftsBool, firstDay=timeBeginning(nt))
        lettersSerialisable = String[join(map(string, letters[i, :]), ",") for i in 1:size(letters, 1)]
        # cycles = findCycles(letters)
        # cycleLengths = [[cycle[2] - cycle[1] + 1 for cycle in cycles[team]] for team in 1:nTeams]

        write(f, "it" * string(i) * "/analysis/hr/shiftsAsLetters", lettersSerialisable)
        # write(f, "it" * string(i) * "/analysis/hr/cycles", cycles) # Cycles are no more used.

        write(f, "it" * string(i) * "/analysis/ucl/SYNT", lettersSerialisable)

        write(f, "it" * string(i) * "/analysis/ucl/nShifts", countShifts(letters, 'w'))
        write(f, "it" * string(i) * "/analysis/ucl/nWE", countShifts(letters, 'w', weekend=true))

        for l1 in "MANR"
          write(f, "it" * string(i) * "/analysis/ucl/n$(l1)", countShifts(letters, l1))
          write(f, "it" * string(i) * "/analysis/ucl/nWE$(l1)", countShifts(letters, l1, weekend=true))
          for l2 in "MANR"
            write(f, "it" * string(i) * "/analysis/ucl/n$(l1)$(l2)", countShiftSequences(letters, [l1, l2]))
            for l3 in "MANR"
              write(f, "it" * string(i) * "/analysis/ucl/n$(l1)$(l2)$(l3)", countShiftSequences(letters, [l1, l2, l3]))
            end
          end
        end

        write(f, "it" * string(i) * "/analysis/ucl/LS", 8 * countShifts(letters, 'w'))
        # write(f, "it" * string(i) * "/analysis/ucl/CYCL", [mean(cycleLengths[team]) for team in 1:nTeams])
        # write(f, "it" * string(i) * "/analysis/ucl/LW", [mean([sum([if letters[1 + team, d] == 'R'; 8; else; 0; end for d in cycle[1]:cycle[2]]) for cycle in cycles[team]]) for team in 1:nTeams])

        if isa(obj, ObjectiveCombination) || isa(obj, HRCostObjective)
          hrObj = (isa(obj, ObjectiveCombination)) ? find(HRCostObjective, obj) : obj
          write(f, "it" * string(i) * "/analysis/ucl/PAY", hrPrice(hrObj, timeBeginning(nt), shiftsBool, nt))
          write(f, "it" * string(i) * "/analysis/ucl/PAYt", sum(hrPrice(hrObj, timeBeginning(nt), shiftsBool, nt), 2))

          PAYm = sum(hrPrice(hrObj, timeBeginning(nt), shiftsBool, nt), 2) ./ (8 * countShifts(letters, 'w'))
          PAYm[isnan.(PAYm)] = 0.
          write(f, "it" * string(i) * "/analysis/ucl/PAYm", PAYm)
        end
      end
    end
  end

  h5open(outFile, "r+") do f
    ## Output global information.
    write(f, "results/analysis/hr/bounds", allBounds)

    ## HR: perform a few global analyses (same as per iteration).
    # Agregate the HR solution from all iterations. Take all shifts from the first iteration, then the last few ones
    # for each subsequent iteration (exactly, the shifts for the last notificationFrequency days).
    if nIterations == 1
      # One iteration: only copy the results from that iteration.
      write(f, "results/production/objectiveNames", read(f, "it1/production/objectiveNames"))
      write(f, "results/production/objectives", read(f, "it1/production/objectives"))
      write(f, "results/hr/shifts", read(f, "it1/hr/global/shifts"))
      write(f, "results/analysis/hr/shiftsAsLetters", read(f, "it1/analysis/hr/shiftsAsLetters"))
      # write(f, "results/analysis/hr/cycles", read(f, "it1/analysis/hr/cycles"))
      write(f, "results/analysis/ucl/SYNT", read(f, "it1/analysis/ucl/SYNT"))
      write(f, "results/analysis/ucl/nShifts", read(f, "it1/analysis/ucl/nShifts"))
      write(f, "results/analysis/ucl/nWE", read(f, "it1/analysis/ucl/nWE"))
      for l1 in "MANR"
        write(f, "results/analysis/ucl/n$(l1)", read(f, "it1/analysis/ucl/n$(l1)"))
        write(f, "results/analysis/ucl/nWE$(l1)", read(f, "it1/analysis/ucl/nWE$(l1)"))
        for l2 in "MANR"
          write(f, "results/analysis/ucl/n$(l1)$(l2)", read(f, "it1/analysis/ucl/n$(l1)$(l2)"))
          for l3 in "MANR"
            write(f, "results/analysis/ucl/n$(l1)$(l2)$(l3)", read(f, "it1/analysis/ucl/n$(l1)$(l2)$(l3)"))
          end
        end
      end
      write(f, "results/analysis/ucl/LS", read(f, "it1/analysis/ucl/LS"))
      # write(f, "results/analysis/ucl/CYCL", read(f, "it1/analysis/ucl/CYCL"))
      # write(f, "results/analysis/ucl/LW", read(f, "it1/analysis/ucl/LW"))
      write(f, "results/analysis/ucl/PAY", read(f, "it1/analysis/ucl/PAY"))
      write(f, "results/analysis/ucl/PAYt", read(f, "it1/analysis/ucl/PAYt"))
      write(f, "results/analysis/ucl/PAYm", read(f, "it1/analysis/ucl/PAYm"))
    else
      nDaysBetweenIterations = priorNoticeDelay - notificationFrequency

      # Gather the complete solutions (HR and costs) from the results of each iteration.
      solution = hcat(committedSolutions...)

      if length(dailyObjectives) >= 1
        objectiveNames = Array{String}(nObjectives(obj))
        for o in 1:nObjectives(obj)
          if symbol(obj, o) == :electricity
            objectiveNames[o] = "Electricity"
          elseif symbol(obj, o) == :hr
            objectiveNames[o] = "HR"
          elseif symbol(obj, o) == :hr_fake
            objectiveNames[o] = "HR penalisation"
          else
            objectiveNames[o] = "unknown"
          end
        end
        # Take the first committed part completely, then only what the next committed parts add to it.
        objDaily = map(Float64, hcat(committedDailyObjectives[1], map((cdo) -> cdo[:, (end - notificationFrequency + 1):end], committedDailyObjectives[2:end])...))

        write(f, "results/production/objectiveNames", objectiveNames)
        write(f, "results/production/objectives", objDaily)
      end

      # Perform a few analyses and write the results down.
      # This only applies when shifts follow predictable patterns, i.e. not when they are being optimised! 
      # Most analyses require three shifts a day, i.e. 8-hour shifts. 
      if nShiftDurations(shifts) == 1 && shiftDuration(shift) == Hour(8)
        letters = shiftsAsLetters(solution, firstDay=timeBeginning(timing))
        lettersSerialisable = String[join(map(string, letters[i, :]), ",") for i in 1:size(letters, 1)]
        # cycles = findCycles(letters)
        # cycleLengths = [[cycle[2] - cycle[1] + 1 for cycle in cycles[team]] for team in 1:nTeams]

        write(f, "results/hr/shifts", round.(Int, solution))

        write(f, "results/analysis/hr/shiftsAsLetters", lettersSerialisable)
        # write(f, "results/analysis/hr/cycles", cycles) # Cycles are no more used.

        write(f, "results/analysis/ucl/SYNT", lettersSerialisable)

        write(f, "results/analysis/ucl/nShifts", countShifts(letters, 'w'))
        write(f, "results/analysis/ucl/nWE", countShifts(letters, 'w', weekend=true))

        for l1 in "MANR"
          write(f, "results/analysis/ucl/n$(l1)", countShifts(letters, l1))
          write(f, "results/analysis/ucl/nWE$(l1)", countShifts(letters, l1, weekend=true))
          for l2 in "MANR"
            write(f, "results/analysis/ucl/n$(l1)$(l2)", countShiftSequences(letters, [l1, l2]))
            for l3 in "MANR"
              write(f, "results/analysis/ucl/n$(l1)$(l2)$(l3)", countShiftSequences(letters, [l1, l2, l3]))
            end
          end
        end

        write(f, "results/analysis/ucl/LS", 8 * countShifts(letters, 'w'))
        # write(f, "results/analysis/ucl/CYCL", [mean(cycleLengths[team]) for team in 1:nTeams])
        # write(f, "results/analysis/ucl/LW", [mean([sum([if letters[1 + team, d] == 'R'; 8; else; 0; end for d in cycle[1]:cycle[2]]) for cycle in cycles[team]]) for team in 1:nTeams])

        if isa(obj, ObjectiveCombination) || isa(obj, HRCostObjective)
          hrObj = (isa(obj, ObjectiveCombination)) ? find(HRCostObjective, obj) : obj
          write(f, "results/analysis/ucl/PAY", hrPrice(hrObj, timeBeginning(timing), solution, timing))
          write(f, "results/analysis/ucl/PAYt", sum(hrPrice(hrObj, timeBeginning(timing), solution, timing), 2))

          PAYm = sum(hrPrice(hrObj, timeBeginning(timing), solution, timing), 2) ./ (8 * countShifts(letters, 'w'))
          PAYm[isnan.(PAYm)] = 0.
          write(f, "results/analysis/ucl/PAYm", PAYm)
        end
      end
    end
  end

  return true, :None
end
