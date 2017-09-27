# TODO: How does a predefined schedule work with fully flexible schedules? 

shiftsFiveEight = Array(falses(5, 30)) # [team, shift]
# Copied from https://fr.wikipedia.org/wiki/5_%C3%97_8
shiftsFiveEight[1, [1,  4,  8,  11, 15, 18]] = 1 # MMAANNRRRR
shiftsFiveEight[2, [2,  5,  9,  12, 25, 28]] = 1 # AANNRRRRMM
shiftsFiveEight[3, [3,  6,  19, 22, 26, 29]] = 1 # NNRRRRMMAA
shiftsFiveEight[4, [13, 16, 20, 23, 27, 30]] = 1 # RRRRMMAANN
shiftsFiveEight[5, [7,  10, 14, 17, 21, 24]] = 1 # RRMMAANNRR
# There are workers each and every day:
#     all(any(shiftsFiveEight, 1))

# TODO: More predefined schedules like this one, also used to perform more tests on shiftFixedSchedule.

"""
Shifts the given fixed schedule `fixedSchedule` by the given number of days `nDays`.
"""
function shiftFixedSchedule(fixedSchedule::Array{Bool,2}, nDays::Int)
  # Take the first nDays days and put them at the end.
  nShifts = mod(3 * nDays, size(fixedSchedule, 2))
  newSchedule = similar(fixedSchedule)
  newSchedule[:, 1 : end - nShifts] = fixedSchedule[:, 1 + nShifts : end]
  newSchedule[:, end - nShifts + 1 : end] = fixedSchedule[:, 1 : nShifts]
  return newSchedule
end

function teamModel(neededTeamsForShifts::Array{Tuple{DateTime, Hour, Int}, 1}, timeBetweenShifts::Int,
                   consecutiveDaysOff::Tuple{Int, Int}, maxHoursPerWeek::Int, boundsHours::Tuple{Float64, Float64},
                   nTeams::Int, # TODO: NEW! Second parameter deleted. 
                   coeffs::NTuple{6, Float64}=(1., 1., 500., 1000., 0., 0.),
                   fixedSchedule::BitArray{2}=falses(0, 0),
                   initialSolution::BitArray{2}=falses(0, 0), initialSolutionMode::Symbol=:none;
                   solver::MathProgBase.AbstractMathProgSolver=JuMP.UnsetSolver(), outfile="")
  ## Check hypotheses. 
  # At least one shift required. 
  if length(neededTeamsForShifts) < 1
    error("No shifts are required. ")
  end

  # Shifts follow each other (sorted along time). 
  for i in 1:length(neededTeamsForShifts)
    currentTime = neededTeamsForShifts[i][1]
    for j in (i + 1):length(neededTeamsForShifts)
      if neededTeamsForShifts[j][1] <= currentTime
        error("Shift number $(j) starts before shift $(i) while it is after in the given list ($(i): $(currentTime); $(j): $(neededTeamsForShifts[j][1])). ")
      end
    end
  end
  
  # Days off require some horizon. 
  if nDays <= consecutiveDaysOff[2]
    warn("Optimisation horizon not long enough to implement a days-off constraint: only " * string(nDays) * " days, while the constraint works with horizons of " * string(consecutiveDaysOff[2]) * " days.")
  end

  # If fixed schedule, then all shifts have a given length. 
  # TODO: get a PlantModel or something here to check this hypothesis! 

  ## Derived data from inputs.
  # Tables of correspondance between shifts and some periods of time.
  encodeDay(dt::DateTime) = 10_000 * year(dt) + 100 * month(dt) + day(dt)
  encodeWeek(dt::DateTime) = 100 * year(dt) + week(dt)

  days = sort(unique([encodeDay(tuple[1]) for tuple in neededTeamsForShifts]))
  weeks = sort(unique([encodeWeek(tuple[1]) for tuple in neededTeamsForShifts]))

  dayToShifts  = Dict(day -> [s for s in 1:nShifts if encodeDay(neededTeamsForShifts[s][1]) == day] for day in days) # Day index -> list of shift indices for that day
  weekToShifts = Dict(week -> [s for s in 1:nShifts if encodeWeek(neededTeamsForShifts[s][1]) == week] for week in weeks) # Week index -> list of shift indices for that week
  
  # Prepare the sets for implement the days off constraint. 
  #   - tupleDays: tuples of consecutiveDaysOff[1] consecutive days. These are potential "week ends". 
  #   - offTupleDays: sets of tuples where the constraint is written. For each of them, at least one tuple must be active. 
  tupleDays = [[days[i - j] for j in 0:-1:consecutiveDaysOff[1]] for i in consecutiveDaysOff[1]:length(days)]
  offTupleDays = Array{Int, 1}[]
  firstDay = minimum(tuple[1] for tuple in neededTeamsForShifts)
  lastDay = maximum(tuple[1] for tuple in neededTeamsForShifts)
  for startDayOff in 1:(nDays - consecutiveDaysOff[2])
    # Consider every tuple completely between startDayOff and startDayOff + consecutiveDaysOff[2]
    push!(offTupleDays, 
      filter(
        (tuple) -> tuple[1] >= encodeDay(firstDay + Day(startDayOff - 1)) && tuple[end] <= encodeDay(firstDay + Day(startDayOff + consecutiveDaysOff[2] - 1)), 
        tupleDays
      )
    )
  end

  tupleDayToShifts = Dict(tupleDay -> [s for s in 1:nShifts if encodeDay(neededTeamsForShifts[s][1]) in tupleDay] for tupleDay in tupleDays) # Day tuple as index -> list of shift indices for that tuple (for any number of days within that tuple)
  # consecutiveDaysOffPeriods = [hcat([]...) for i in 1:(nDays - consecutiveDaysOff[2])] # Write the constraint as a rolling horizon.

  # Basic counting and dividing.
  dates = [pair[1] for pair in neededTeamsForShifts]

  nShifts = length(neededTeamsForShifts)
  nWorkedHours = sum(tuple[2] for tuple in neededTeamsForShifts).value

  nWorkedDays = length(nDays) # Only days when workers are required: not necessarily nWeeks / 7! 
  nDays = days(max(dates) - min(dates)) # All days in the horizon. 
  nWeeks = length(weeks) # Only weeks when workers are required: not necessarily nCompleteWeeks \pm 1! 
  nCompleteWeeks = floor(Int, nDays / 7) # All complete weeks in the horizon. 

  # Incompatibility "graph" between worked shifts: if one shift is worked, then the others cannot be.
  # Used to implement the fact that a given amount of rest must be respected between shifts (timeBetweenShifts hours). 
  forbiddenShifts = Dict{Int, Array{Int, 1}}() # (s -> ls): if shift s is worked, then the shifts in ls may not (irrespective of team).
  for s in 1:nShifts
    ls = Int[]

    # Compare to the beginnings of the next shifts. Stop adding shifts once the start is further away than timeBetweenShifts. 
    for t in (s + 1):nShifts
      if hour(neededTeamsForShifts[t][1] - neededTeamsForShifts[s][1]) < timeBetweenShifts
        push!(ls, t)
      else
        break
      end
    end 

    if length(ls) > 0
      forbiddenShifts[s] = unique(ls)
    end
  end

  ## Actual model.
  m = Model(solver=solver)

  # Main part of the model.
  @variable(m, teamInShift[1:nTeams, 1:nShifts], Bin) 
  @variable(m, teamInTuple[1:nTeams, tupleDays], Bin) 
  @variable(m, teamSlackOvertimeHours[1:nTeams, weeks] >= 0)
  @variable(m, teamSlackMinOverallHours[1:nTeams] >= 0) # Not per week, but over the whole period.
  @variable(m, teamSlackMaxOverallHours[1:nTeams] >= 0) # Not per week, but over the whole period.

  @constraint(m, c_numberTeamsPerShift[s=1:nShifts],                                 sum(teamInShift[:, s]) == neededTeamsForShifts[s][3])
  @constraint(m, c_forbiddenShiftCombinations[s=keys(forbiddenShifts), i=1:nTeams],  sum([teamInShift[i, j] for j in forbiddenShifts[s]]) <= 1 - teamInShift[i, s])
  @constraint(m, c_maxHoursPerWeek[w=weeks, i=1:nTeams],                             sum(neededTeamsForShifts[s][2].value * teamInShift[i, s] for s in weekToShifts[w]) <= maxHoursPerWeek + teamSlackOvertimeHours[i, w])
  @constraint(m, c_minHoursOverall[i=1:nTeams],                                      sum(neededTeamsForShifts[s][2].value * teamInShift[i, s] for s in 1:nShifts) >= boundsHours[1] - teamSlackMinOverallHours[i])
  @constraint(m, c_maxHoursOverall[i=1:nTeams],                                      sum(neededTeamsForShifts[s][2].value * teamInShift[i, s] for s in 1:nShifts) <= boundsHours[2] + teamSlackMaxOverallHours[i])
  @constraint(m, c_detectWorkedPairsDays[d=tupleDays, i=1:nTeams],                   nShifts * teamInTuple[i, d] <= nShifts - sum([teamInShift[i, s] for s in tupleDayToShifts[d]]))
  @constraint(m, c_consecutiveDaysOff[i=1:nTeams, lt=offTupleDays],                  sum(teamInTuple[i, d] for d in lt) >= 1)

  # TODO: Cut? One shift per day max, due to the fact that two shifts must be timeBetweenShifts hours apart (think: 11h). No more valid with variable shift lengths... (4-hour shift + 11-hour rest < 24-hour day)

  # TODO: How to do this now? Only conditionnally acceptable: if fully flexible, this does not make sense! Only allowed when shifts have a fixed length. (To be done when factorising this function to use constraint objects as parameters?)
  # # Implement the fixed schedule if need be.
  # if length(fixedSchedule) > 0
  #   # First, copy the schedule so that its length fits the needed one.
  #   # TODO: When refactoring this as a constraint, let external user code deal with this part. (When the schedule is given for 10 days, workers do not start at the same position in the pattern for every period of 13 weeks.)
  #   # TODO: Generalise to have "definitely never", "yes, of course", "avoid as long as possible" (generalises day/night teams?).
  #   fixedScheduleCopied = hcat([fixedSchedule for i in 1:ceil(Int, nShifts / size(fixedSchedule, 2))]...)[:, 1:nShifts]

  #   # Then, the constraint is straightforward.
  #   @constraint(m, c_fixedSchedule[i=1:nTeams, s=1:nShifts],                               teamInShift[i, s] <= fixedScheduleCopied[i, s])
  # end

  # Handle initial solutions, if any.
  @variable(m, initialSolutionDifference >= 0, Int)
  @variable(m, teamInShiftDifferentLess[1:nTeams, 1:size(initialSolution, 2)], Bin)
  @variable(m, teamInShiftDifferentMore[1:nTeams, 1:size(initialSolution, 2)], Bin)
  if initialSolutionMode == :none
    # Force nothing.
    @constraint(m, c_isd_none,                                                            initialSolutionDifference == 0)
    @constraint(m, c_tisdl_none[i=1:nTeams, s=1:size(initialSolution, 2)],                teamInShiftDifferentLess[i, s] == 0)
    @constraint(m, c_tisdm_none[i=1:nTeams, s=1:size(initialSolution, 2)],                teamInShiftDifferentMore[i, s] == 0)
  elseif initialSolutionMode == :force
    @constraint(m, c_forcedShifts[i=1:nTeams, s=1:size(initialSolution, 2)],              teamInShift[i, s] == initialSolution[i, s])
    @constraint(m, c_isd_force,                                                           initialSolutionDifference == 0)
    @constraint(m, c_tisdl_force[i=1:nTeams, s=1:size(initialSolution, 2)],               teamInShiftDifferentLess[i, s] == 0)
    @constraint(m, c_tisdm_force[i=1:nTeams, s=1:size(initialSolution, 2)],               teamInShiftDifferentMore[i, s] == 0)
  elseif initialSolutionMode == :hint
    @constraint(m, c_teamInShiftDelta[i=1:nTeams, s=1:size(initialSolution, 2)],          teamInShift[i, s] == initialSolution[i, s] - teamInShiftDifferentLess[i, s] + teamInShiftDifferentMore[i, s])
    @constraint(m, c_teamInShiftDeltaExclusive[i=1:nTeams, s=1:size(initialSolution, 2)], teamInShiftDifferentMore[i, s] + teamInShiftDifferentLess[i, s] <= 1)
    @constraint(m, c_isd_force_hint,                                                      initialSolutionDifference == sum(teamInShiftDifferentLess) + sum(teamInShiftDifferentMore))
  elseif initialSolutionMode == :forceThenHint
    toForce = 3 # TODO: parameterise me! TODO TODO
    if size(initialSolution, 2) < toForce
      error("The initial solution has fewer shifts (" * string(size(initialSolution, 2)) * ") than the number of shifts that must be forced (" * string(toForce) * ")")
    end

    # Force part.
    @constraint(m, c_forcedShifts[i=1:nTeams, s=1:toForce],                               teamInShift[i, s] == initialSolution[i, s])
    @constraint(m, c_tisdl_none[i=1:nTeams, s=1:toForce],                                 teamInShiftDifferentLess[i, s] == 0)
    @constraint(m, c_tisdm_none[i=1:nTeams, s=1:toForce],                                 teamInShiftDifferentMore[i, s] == 0)

    # Hint part.
    @constraint(m, c_teamInShiftDelta[i=1:nTeams, s=(toForce + 1):size(initialSolution, 2)],          teamInShift[i, s] == initialSolution[i, s] - teamInShiftDifferentLess[i, s] + teamInShiftDifferentMore[i, s])
    @constraint(m, c_teamInShiftDeltaExclusive[i=1:nTeams, s=(toForce + 1):size(initialSolution, 2)], teamInShiftDifferentMore[i, s] + teamInShiftDifferentLess[i, s] <= 1)
    @constraint(m, c_isd_force_hint,                                                      initialSolutionDifference == sum(teamInShiftDifferentLess) + sum(teamInShiftDifferentMore))
  end

  # Implement fairness criteria, if needed (they may have a large detrimental effect on the model performance).
  @variable(m, unfairnessNumberShifts)
  @variable(m, unfairnessNumberHours)

  if coeffs[5] == 0.
    @constraint(m, c_unfairnessNumberShifts,                                              unfairnessNumberShifts == 0.)
  else
    @variable(m, numberShifts[1:nTeams] >= 0, Int)
    @variable(m, unfairnessNumberShiftsPositive[1:nTeams] >= 0, Int)
    @variable(m, unfairnessNumberShiftsNegative[1:nTeams] >= 0, Int)

    @constraint(m, c_positiveUnfairnessShifts,                                          unfairnessNumberShifts >= 0)
    @constraint(m, c_numberShifts[i=1:nTeams],                                          numberShifts[i] == sum(teamInShift[i, :]))
    @constraint(m, c_unfairnessNumberShifts,                                            nTeams * unfairnessNumberShifts == sum(unfairnessNumberShiftsPositive) + sum(unfairnessNumberShiftsNegative))
    @constraint(m, c_differencesNumberShifts[i=1:nTeams],                               nTeams * numberShifts[i] == nShifts + unfairnessNumberShiftsPositive[i] - unfairnessNumberShiftsNegative[i])
    # See hr_lattice.jl for current developments about a lattice reformulation. 
  end
  
  if coeffs[6] == 0.
    @constraint(m, c_unfairnessNumberHours,                                              unfairnessNumberHours == 0.)
  else
    @variable(m, numberHours[1:nTeams] >= 0, Int)
    @variable(m, unfairnessNumberHoursPositive[1:nTeams] >= 0, Int)
    @variable(m, unfairnessNumberHoursNegative[1:nTeams] >= 0, Int)

    @constraint(m, c_positiveUnfairnessHours,                                          unfairnessNumberHours >= 0)
    @constraint(m, c_numberHours[i=1:nTeams],                                          numberHours[i] == sum(neededTeamsForShifts[s][2].value * teamInShift[i, s] for s in 1:nShifts))
    @constraint(m, c_unfairnessNumberHours,                                            nTeams * unfairnessNumberHours == sum(unfairnessNumberHoursPositive) + sum(unfairnessNumberHoursNegative))
    @constraint(m, c_differencesNumberHours[i=1:nTeams],                               nTeams * numberHours[i] == nWorkedHours + unfairnessNumberHoursNegative[i] - unfairnessNumberHoursNegative[i])
  end

  # Finally, the objective function.
  @objective(m, Min, coeffs[1] * sum(teamSlackMinOverallHours)
                   + coeffs[2] * sum(teamSlackMaxOverallHours)
                   + coeffs[3] * sum(teamSlackOvertimeHours)
                   + coeffs[4] * initialSolutionDifference
                   + coeffs[5] * unfairnessNumberShifts
                   + coeffs[6] * unfairnessNumberHours)

  # Solve and propose services around the model.
  # writeLP(m, outfile, genericnames=false)
  status = solve(m)
  println(status)

  if status != :Infeasible && status != :Unbounded && status != :InfeasibleOrUnbounded && status != :Error
    # When a slack variable has a zero cost in the objective function, its value is arbitrary: 
    # force it to be meaningful (i.e. zero). 
    hrSlackMin = (coeffs[1] == 0.) ? 0. : getvalue(teamSlackMinOverallHours)
    hrSlackMax = (coeffs[2] == 0.) ? 0. : getvalue(teamSlackMaxOverallHours)
    hrSlackOver = (coeffs[3] == 0.) ? 0. : getvalue(teamSlackOvertimeHours)
    hrInitialSolDelta = (coeffs[4] == 0.) ? 0. : getvalue(initialSolutionDifference)
    hrUnfairShifts = (coeffs[5] == 0.) ? 0. : getvalue(unfairnessNumberShifts)
    hrUnfairHours = (coeffs[6] == 0.) ? 0. : getvalue(unfairnessNumberHours)

    return HRModelResults(m, getvalue(teamInShift), 
                          getobjectivevalue(m), hrInitialSolDelta, getvalue(teamInShiftDifferentLess), getvalue(teamInShiftDifferentMore), 
                          hrSlackMin, hrSlackMax, hrSlackOver, hrUnfairShifts, hrUnfairHours)
  else
    if length(outfile) > 0
      writeLP(m, outfile, genericnames=false)
    end
    return HRModelResults(m)
  end
end
