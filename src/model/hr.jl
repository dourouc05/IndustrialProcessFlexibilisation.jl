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

function teamModel(neededTeamsForShifts::Array{Int, 1}, hoursPerShift::Int, timeBetweenShifts::Int,
                   consecutiveDaysOff::Tuple{Int, Int}, maxHoursPerWeek::Int, boundsHours::Tuple{Float64, Float64},
                   canWorkDays::BitArray{1}, canWorkNights::BitArray{1},
                   coeffs::NTuple{5, Float64}=(1., 1., 500., 1000., 0.),
                   fixedSchedule::BitArray{2}=falses(0, 0),
                   initialSolution::BitArray{2}=falses(0, 0), initialSolutionMode::Symbol=:none;
                   solver::MathProgBase.AbstractMathProgSolver=JuMP.UnsetSolver(), outfile="")
  ## Derived data from inputs.
  # Basic counting and dividing.
  nTeams = length(canWorkDays)
  nShifts = length(neededTeamsForShifts)
  nDays = floor(Int, nShifts / 3)
  nWeeks = ceil(Int, nDays / 7)
  nCompleteWeeks = floor(Int, nDays / 7)

  shiftsPerDay = round(Int, 24 / hoursPerShift) # This value should be exact. TODO: Get rid of this; only useful for the `days` and `tupleDays` dictionnaries, it should be built on more robust things (what if shift lengths vary?).
  shiftsPerWeek = 7 * shiftsPerDay # TODO: Get rid of this; only useful for the `weeks` dictionnary.

  # Tables of correspondance between hours, shifts, and some periods.
  weeks = Dict(week => collect((week - 1) * shiftsPerWeek + 1 : shiftsPerWeek * week) for week in 1:nWeeks) # week number (even incomplete) -> shifts in that week
  tupleDays = Dict(day => collect((day - 1) * shiftsPerDay + 1 : min((day - 1) * shiftsPerDay + shiftsPerDay * consecutiveDaysOff[1], nShifts)) for day in 1:(nDays - 1)) # day number -> shifts in that day and consecutiveDaysOff[1] - 1 next ones (i.e. a period of consecutiveDaysOff[1] days)
  partialShiftsPerPeriod = shiftsPerDay * consecutiveDaysOff[1] # Even if a shift only has 2 hours in a day, it is counted in this value.

  # Incompatibility "graph" between worked shifts: if one shift is worked, then the others cannot be.
  forbiddenShifts = Dict{Int, Array{Int, 1}}() # (s -> ls): if shift s is worked, then the shifts in ls may not (irrespective of team).
  for s in 1:nShifts
    ls = Int[]

    # Time between shifts.
    for i in 1:timeBetweenShifts
      if s + i <= nShifts
        push!(ls, s + i)
      end
    end

    if length(ls) > 0
      forbiddenShifts[s] = unique(ls)
    end
  end

  # List of periods where there must be two consecutive days off. Each period is given as a pair of the first and the last
  # day of the period where the consecutive days off must be.
  # TODO: For the tests, ensure each day is within the optimisation horizon.
  nDaysOffPeriods = floor(Int, nDays / consecutiveDaysOff[2]) # Only complete periods (hence floor).
  # consecutiveDaysOffPeriods = [(consecutiveDaysOff[2] * (w - 1) + 1, consecutiveDaysOff[2] * w) for w in 1:nDaysOffPeriods] # Write the constraint once per period, between the first and the last day of each (complete) period.
  consecutiveDaysOffPeriods = [(i, i + consecutiveDaysOff[2]) for i in 1:(nDays - consecutiveDaysOff[2])] # Write the constraint as a rolling horizon.
  if length(consecutiveDaysOffPeriods) == 0
    error("Optimisation horizon not long enough to implement a days-off constraint: only " * string(nDays) * " days, while the constraint works with horizons of " * string(consecutiveDaysOff[2]) * " days.")
  end

  # Determine what is night and what is day. First and third shifts are night. (Considering the shifts start at midnight,
  # last for 8 hours; night hours are 22-6; a shift having one night hour is considered as a night shift.)
  days = [shiftsPerDay * (day - 1) + 2 for day in 1:nDays]
  nights = [[shiftsPerDay * (day - 1) + 1 for day in 1:nDays] [shiftsPerDay * (day - 1) + 3 for day in 1:nDays]]


  ## Actual model.
  m = Model(solver=solver)

  # Main part of the model.
  @variable(m, teamInShift[1:nTeams, 1:nShifts], Bin) # x
  @variable(m, teamInTuple[1:nTeams, 1:nDays], Bin) # y
  @variable(m, teamSlackOvertimeHours[1:nTeams, 1:nWeeks] >= 0)
  @variable(m, teamSlackMinOverallHours[1:nTeams] >= 0) # Not per week, but over the whole period.
  @variable(m, teamSlackMaxOverallHours[1:nTeams] >= 0) # Not per week, but over the whole period.

  @constraint(m, c_numberTeamsPerShift[s=1:nShifts],                                       sum(teamInShift[:, s]) == neededTeamsForShifts[s])
  @constraint(m, c_forbiddenShiftCombinations[s=keys(forbiddenShifts), i=1:nTeams],        sum([teamInShift[i, j] for j in forbiddenShifts[s]]) <= 1 - teamInShift[i, s])
  @constraint(m, c_maxHoursPerWeek[w=1:nWeeks, i=1:nTeams],                                hoursPerShift * sum(sum(teamInShift[i, j] for j in weeks[w])) <= maxHoursPerWeek + teamSlackOvertimeHours[i, w])
  @constraint(m, c_minHoursOverall[i=1:nTeams],                                            hoursPerShift * sum(sum(teamInShift[i, :])) >= boundsHours[1] - teamSlackMinOverallHours[i])
  @constraint(m, c_maxHoursOverall[i=1:nTeams],                                            hoursPerShift * sum(sum(teamInShift[i, :])) <= boundsHours[2] + teamSlackMaxOverallHours[i])
  @constraint(m, c_detectWorkedPairsDays_divide[t=1:(nDays - 1), i=1:nTeams],              teamInTuple[i, t] <= 1 - sum(sum(teamInShift[i, j] for j in tupleDays[t])) / partialShiftsPerPeriod)
  # @constraint(m, c_detectWorkedPairsDays_multiply[t=1:(nDays - 1), i=1:nTeams],            partialShiftsPerPeriod * teamInTuple[i, t] <= partialShiftsPerPeriod - sum([teamInShift[i, j] for j in tupleDays[t]]))
  # @constraint(m, c_detectWorkedPairsDays_naivebigm_divide[t=1:(nDays - 1), i=1:nTeams],    teamInTuple[i, t] <= 1 - sum([teamInShift[i, j] for j in tupleDays[t]]) / nShifts)
  # @constraint(m, c_detectWorkedPairsDays_naivebigm_multiply[t=1:(nDays - 1), i=1:nTeams],  nShifts * teamInTuple[i, t] <= nShifts - sum([teamInShift[i, j] for j in tupleDays[t]]))
  @constraint(m, c_consecutiveDaysOff[i=1:nTeams, p=consecutiveDaysOffPeriods],            sum(sum(teamInTuple[i, p[1]:p[2]])) >= 1)
  @constraint(m, c_canWorkNight[i=1:nTeams, s=nights; ! canWorkNights[i]],                 teamInShift[i, s] == 0)
  @constraint(m, c_canWorkDay[i=1:nTeams, s=days; ! canWorkDays[i]],                       teamInShift[i, s] == 0)

  # TODO: Cut? One shift per day max. No more valid with variable shift lengths... (4-hour shift + 11-hour rest < 24-hour day)

  # Implement the fixed schedule if need be.
  if length(fixedSchedule) > 0
    # First, copy the schedule so that its length fits the needed one.
    # TODO: When refactoring this as a constraint, let external user code deal with this part. (When the schedule is given for 10 days, workers do not start at the same position in the pattern for every period of 13 weeks.)
    # TODO: Generalise to have "definitely never", "yes, of course", "avoid as long as possible" (generalises day/night teams?).
    fixedScheduleCopied = hcat([fixedSchedule for i in 1:ceil(Int, nShifts / size(fixedSchedule, 2))]...)[:, 1:nShifts]

    # Then, the constraint is straightforward.
    @constraint(m, c_fixedSchedule[i=1:nTeams, s=1:nShifts],                               teamInShift[i, s] <= fixedScheduleCopied[i, s])
  end

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
  if coeffs[5] == 0.
    @constraint(m, c_unfairnessNumberShifts,                                              unfairnessNumberShifts == 0.)
  else
    formulation = :integer # :standard, :integer, :lattice

    if formulation == :standard
      @variable(m, numberShifts[1:nTeams] >= 0, Int)
      @variable(m, unfairnessNumberShiftsPositive[1:nTeams] >= 0) # Real number.
      @variable(m, unfairnessNumberShiftsNegative[1:nTeams] >= 0) # Real number.
      averageNumberShifts = sum(neededTeamsForShifts) / nTeams

      @constraint(m, c_positiveUnfairness,                                                unfairnessNumberShifts >= 0)
      @constraint(m, c_numberShifts[i=1:nTeams],                                          numberShifts[i] == sum(teamInShift[i, :]))
      @constraint(m, c_unfairnessNumberShifts,                                            nTeams * unfairnessNumberShifts == sum(unfairnessNumberShiftsPositive) + sum(unfairnessNumberShiftsNegative))
      @constraint(m, c_differencesNumberShifts[i=1:nTeams],                               numberShifts[i] == averageNumberShifts + unfairnessNumberShiftsPositive[i] - unfairnessNumberShiftsNegative[i])
    elseif formulation == :integer
      @variable(m, numberShifts[1:nTeams] >= 0, Int)
      @variable(m, unfairnessNumberShiftsPositive[1:nTeams] >= 0, Int)
      @variable(m, unfairnessNumberShiftsNegative[1:nTeams] >= 0, Int)
      totalNumberShifts = sum(neededTeamsForShifts)

      @constraint(m, c_positiveUnfairness,                                                unfairnessNumberShifts >= 0)
      @constraint(m, c_numberShifts[i=1:nTeams],                                          numberShifts[i] == sum(teamInShift[i, :]))
      @constraint(m, c_unfairnessNumberShifts,                                            nTeams * unfairnessNumberShifts == sum(unfairnessNumberShiftsPositive) + sum(unfairnessNumberShiftsNegative))
      @constraint(m, c_differencesNumberShifts[i=1:nTeams],                               nTeams * numberShifts[i] == totalNumberShifts + unfairnessNumberShiftsPositive[i] - unfairnessNumberShiftsNegative[i])
    elseif formulation == :lattice
      @variable(m, unfairnessNumberShiftsPerTeam[1:nTeams])
      @constraint(m, unfairnessNumberShifts == sum(unfairnessNumberShiftsPerTeam))

      # Build the constraint matrix for these constraints.
      M1 = 10_000 # Completing the identity matrix with the right-hand side
      M2 = 10_000 # Constraint coefficients
      M3 = 10 # Slack variables
      totalNumberShifts = 12 # sum(neededTeamsForShifts)

      nVars = nTeams * nShifts + nTeams
      nConstrs = nTeams
      A = zeros(Int, nVars + nConstrs + 1, nVars + 1)
      A[1:nVars, 1:nVars] = eye(Int, nVars)
      A[nVars + 1, nVars + 1] = M1
      for teamIdx in 1:nTeams
        # nTeams * numberShifts[i] == totalNumberShifts + unfairnessNumberShiftsPositive[i] - unfairnessNumberShiftsNegative[i]
        # First nTeams * nShifts teamInShift (hence numberShifts), then nTeams unfairnessNumberShifts
        A[nVars + 1 + teamIdx, (teamIdx - 1) * nShifts + 1 : teamIdx * nShifts] = M2 * nTeams # teamInShift
        A[nVars + 1 + teamIdx, nTeams * nShifts + teamIdx] = M2 * M3 # slack
        A[nVars + 1 + teamIdx, end] = - M2 * totalNumberShifts
      end

      # Perform the LLL decomposition.
      S = MatrixSpace(ZZ, size(A, 2), size(A, 1))
      B = lll(S(A'))'; # [B[i, j] for i in 1:size(B, 1), j in 1:size(B, 2)]

      # Solutions to the homogeneous equation (Nemo does not allow ranges, hence the transpositions):
      pIdx = find([all([B[j, i] == 0 for j in size(B, 1) - nConstrs + 1:size(B, 1)]) for i in 1:size(B, 2)])
      # Solution to the nonhomogeneous equation:
      qIdx = find([B[size(B, 1) - nConstrs + 1, i] == M1 && all([B[j, i] == 0 for j in size(B, 1) - nConstrs + 2:size(B, 1)]) for i in 1:size(B, 2)])

      # Ensure there are no two identical basis vectors.
      filter!(pIdx) do p
        # Always keep the first vector (no other one to compare it to).
        if p == pIdx[1]
          return true
        end

        # Compare the current vector to all the previous ones.
        idx = find(pIdx .== p)[1]
        for otherIdx in pIdx[1 : idx - 1]
          if norm(Int[B[i, idx] for i in 1:nVars] - Int[B[i, otherIdx] for i in 1:nVars]) <= 1.e-5
            # Found a vector that is identical (working only with integers) in the beginning of the basis: reject this one.
            return false
          end
        end

        # No similar vector found: keep this one!
        return true
      end

      # Due to the form the reduced basis, there is no basis vector after the nonhomogeneous solution.
      # Expected form: first all the basis vectors, then the nonhomogeneous solution, then useless lattice basis vectors.
      # This has a large impact on the consistency tests performed just after.
      if length(qIdx) > 0
        filter!((p) -> p < minimum(qIdx), pIdx)
      end

      # Consistency tests for the basis decomposition (if there is a problem here, other values of M should be tried).
      if length(pIdx) != nVars - nConstrs
        warn("Not the right number of vectors in the reduced basis: ", length(pIdx), " instead of ", nVars - nConstrs, ".")
        println(pIdx)
      end
      if length(qIdx) != 1
        warn("Not the right number of nonhomogeneous solutions: ", length(qIdx), " obtained instead of exactly 1.")

        # Keep the first nonhomogeneous solution if there are multiple ones (arbitrarily).
        if length(qIdx) > 1
          qIdx = minimum(qIdx)
        end
      end

      q = Int[B[i, j] for i in 1:nVars, j in qIdx]
      p = Int[B[i, j] for i in 1:nVars, j in pIdx]

      if length(qIdx) == 0
        warn("Determining a nonhomogeneous solution.")

        # Build the solution team per team, as the constraints only involve one team at a time.
        q = zeros(Int, nVars)
        for teamIdx in 1:nTeams
          # sum of M2 * nTeams * teamInShift, then M2 * unfairness == M2 * totalNumberShifts
          # Fill as many teamInShift at the beginning of the vector. Then, put the rest in the unfairness. (Be general,
          # in case the code is used when multiple teams are required for a given shift.)
          consideredShifts = min(totalNumberShifts, nShifts)
          nSurplusShifts = mod(consideredShifts, nTeams)
          nTeamInShift = floor(Int, (consideredShifts - nSurplusShifts) / nTeams)
          nShiftsUnfairness = totalNumberShifts - nTeams * nTeamInShift

          q[(teamIdx - 1) * nShifts + 1 : (teamIdx - 1) * nShifts + nTeamInShift] = 1
          q[nTeams * nShifts + teamIdx] = nShiftsUnfairness / M3
        end
      end

      # Write the new constraints.
      @variable(m, lambda[1:size(p, 2)], Int)
      @constraint(m, c_differencesNumberShiftsA[i=1:nTeams, t=1:nShifts],                 teamInShift[i, t] == q[nTeams * (i - 1) + t + 1] + dot(lambda, vec(p[nTeams * (i - 1) + t + 1, :])))
      @constraint(m, c_differencesNumberShiftsB[i=1:nTeams],                              unfairnessNumberShiftsPerTeam[i] == q[nTeams * nTeams + i] + dot(lambda, vec(p[nTeams * nTeams + i, :])))
    end
  end

  # Finally, the objective function.
  @objective(m, Min, coeffs[1] * sum(teamSlackMinOverallHours)
                   + coeffs[2] * sum(teamSlackMaxOverallHours)
                   + coeffs[3] * sum(teamSlackOvertimeHours)
                   + coeffs[4] * initialSolutionDifference
                   + coeffs[5] * unfairnessNumberShifts)

  # Solve and propose services around the model.
  # writeLP(m, outfile, genericnames=false)
  status = solve(m)
  println(status)

  if status != :Infeasible && status != :Unbounded && status != :InfeasibleOrUnbounded && status != :Error
    # When a slack variable has a zero cost in the objective function, its value is arbitrary
    hrSlackMin = (coeffs[1] == 0.) ? 0. : getvalue(teamSlackMinOverallHours)
    hrSlackMax = (coeffs[2] == 0.) ? 0. : getvalue(teamSlackMaxOverallHours)
    hrSlackOver = (coeffs[3] == 0.) ? 0. : getvalue(teamSlackOvertimeHours)
    hrInitialSolDelta = (coeffs[4] == 0.) ? 0. : getvalue(initialSolutionDifference)
    hrUnfair = (coeffs[5] == 0.) ? 0. : getvalue(unfairnessNumberShifts)

    return true, m, getvalue(teamInShift), getvalue(teamInShiftDifferentLess), getvalue(teamInShiftDifferentMore),
           getobjectivevalue(m),
           hrSlackMin, hrSlackMax, hrSlackOver, hrInitialSolDelta, hrUnfair
  else
    if length(outfile) > 0
      writeLP(m, outfile, genericnames=false)
    end
    return false, m, Bool[], Bool[], Bool[],
           0.0, Float64[], Float64[], Float64[], 0.0, 0.0
  end
end
