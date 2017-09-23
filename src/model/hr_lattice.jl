# @variable(m, unfairnessNumberShiftsPerTeam[1:nTeams])
# @constraint(m, unfairnessNumberShifts == sum(unfairnessNumberShiftsPerTeam))

# # Build the constraint matrix for these constraints.
# M1 = 10_000 # Completing the identity matrix with the right-hand side
# M2 = 10_000 # Constraint coefficients
# M3 = 10 # Slack variables
# totalNumberShifts = 12 # sum(neededTeamsForShifts)

# nVars = nTeams * nShifts + nTeams
# nConstrs = nTeams
# A = zeros(Int, nVars + nConstrs + 1, nVars + 1)
# A[1:nVars, 1:nVars] = eye(Int, nVars)
# A[nVars + 1, nVars + 1] = M1
# for teamIdx in 1:nTeams
#   # nTeams * numberShifts[i] == totalNumberShifts + unfairnessNumberShiftsPositive[i] - unfairnessNumberShiftsNegative[i]
#   # First nTeams * nShifts teamInShift (hence numberShifts), then nTeams unfairnessNumberShifts
#   A[nVars + 1 + teamIdx, (teamIdx - 1) * nShifts + 1 : teamIdx * nShifts] = M2 * nTeams # teamInShift
#   A[nVars + 1 + teamIdx, nTeams * nShifts + teamIdx] = M2 * M3 # slack
#   A[nVars + 1 + teamIdx, end] = - M2 * totalNumberShifts
# end

# # Perform the LLL decomposition.
# S = MatrixSpace(ZZ, size(A, 2), size(A, 1))
# B = lll(S(A'))'; # [B[i, j] for i in 1:size(B, 1), j in 1:size(B, 2)]

# # Solutions to the homogeneous equation (Nemo does not allow ranges, hence the transpositions):
# pIdx = find([all([B[j, i] == 0 for j in size(B, 1) - nConstrs + 1:size(B, 1)]) for i in 1:size(B, 2)])
# # Solution to the nonhomogeneous equation:
# qIdx = find([B[size(B, 1) - nConstrs + 1, i] == M1 && all([B[j, i] == 0 for j in size(B, 1) - nConstrs + 2:size(B, 1)]) for i in 1:size(B, 2)])

# # Ensure there are no two identical basis vectors.
# filter!(pIdx) do p
#   # Always keep the first vector (no other one to compare it to).
#   if p == pIdx[1]
#     return true
#   end

#   # Compare the current vector to all the previous ones.
#   idx = find(pIdx .== p)[1]
#   for otherIdx in pIdx[1 : idx - 1]
#     if norm(Int[B[i, idx] for i in 1:nVars] - Int[B[i, otherIdx] for i in 1:nVars]) <= 1.e-5
#       # Found a vector that is identical (working only with integers) in the beginning of the basis: reject this one.
#       return false
#     end
#   end

#   # No similar vector found: keep this one!
#   return true
# end

# # Due to the form the reduced basis, there is no basis vector after the nonhomogeneous solution.
# # Expected form: first all the basis vectors, then the nonhomogeneous solution, then useless lattice basis vectors.
# # This has a large impact on the consistency tests performed just after.
# if length(qIdx) > 0
#   filter!((p) -> p < minimum(qIdx), pIdx)
# end

# # Consistency tests for the basis decomposition (if there is a problem here, other values of M should be tried).
# if length(pIdx) != nVars - nConstrs
#   warn("Not the right number of vectors in the reduced basis: ", length(pIdx), " instead of ", nVars - nConstrs, ".")
#   println(pIdx)
# end
# if length(qIdx) != 1
#   warn("Not the right number of nonhomogeneous solutions: ", length(qIdx), " obtained instead of exactly 1.")

#   # Keep the first nonhomogeneous solution if there are multiple ones (arbitrarily).
#   if length(qIdx) > 1
#     qIdx = minimum(qIdx)
#   end
# end

# q = Int[B[i, j] for i in 1:nVars, j in qIdx]
# p = Int[B[i, j] for i in 1:nVars, j in pIdx]

# if length(qIdx) == 0
#   warn("Determining a nonhomogeneous solution.")

#   # Build the solution team per team, as the constraints only involve one team at a time.
#   q = zeros(Int, nVars)
#   for teamIdx in 1:nTeams
#     # sum of M2 * nTeams * teamInShift, then M2 * unfairness == M2 * totalNumberShifts
#     # Fill as many teamInShift at the beginning of the vector. Then, put the rest in the unfairness. (Be general,
#     # in case the code is used when multiple teams are required for a given shift.)
#     consideredShifts = min(totalNumberShifts, nShifts)
#     nSurplusShifts = mod(consideredShifts, nTeams)
#     nTeamInShift = floor(Int, (consideredShifts - nSurplusShifts) / nTeams)
#     nShiftsUnfairness = totalNumberShifts - nTeams * nTeamInShift

#     q[(teamIdx - 1) * nShifts + 1 : (teamIdx - 1) * nShifts + nTeamInShift] = 1
#     q[nTeams * nShifts + teamIdx] = nShiftsUnfairness / M3
#   end
# end

# # Write the new constraints.
# @variable(m, lambda[1:size(p, 2)], Int)
# @constraint(m, c_differencesNumberShiftsA[i=1:nTeams, t=1:nShifts],                 teamInShift[i, t] == q[nTeams * (i - 1) + t + 1] + dot(lambda, vec(p[nTeams * (i - 1) + t + 1, :])))
# @constraint(m, c_differencesNumberShiftsB[i=1:nTeams],                              unfairnessNumberShiftsPerTeam[i] == q[nTeams * nTeams + i] + dot(lambda, vec(p[nTeams * nTeams + i, :])))