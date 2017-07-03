# Note: not necessarily working (production model not fully debugged with steps taking more than one time step). 

e1 = Equipment("EAF", :eaf)
e2 = Equipment("LF", :lf)
e3 = Equipment("CC", :cc)
r1 = NormalRoute(e1, e2)
r2 = NormalRoute(e2, e3)
le = [e1, e2, e3]
lr = Route[r1, r2]
p = Plant(le, lr)

c = ConstantConsumption(2.0) # kWh/heat
p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in le])) # TODO: Transformation rate must be used in capacities.
p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (120.0, 150.0) for e in le]))
ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(DateTime(2017, 01, 06) => (p1, 450), DateTime(2017, 01, 07) => (p2, 450)))
# ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(DateTime(2017, 01, 06) => (p1, 450), DateTime(2017, 01, 13) => (p2, 450), DateTime(2017, 01, 20) => (p1, 450), DateTime(2017, 01, 27) => (p2, 450), DateTime(2017, 01, 30) => (p2, 120), DateTime(2017, 02, 06) => (p1, 450), DateTime(2017, 02, 13) => (p2, 450), DateTime(2017, 02, 20) => (p1, 450), DateTime(2017, 02, 27) => (p2, 450), DateTime(2017, 03, 06) => (p1, 450), DateTime(2017, 03, 13) => (p2, 450), DateTime(2017, 03, 20) => (p1, 450), DateTime(2017, 03, 27) => (p2, 450), DateTime(2017, 03, 30) => (p2, 120), DateTime(2017, 04, 01) => (p1, 100), DateTime(2017, 04, 06) => (p1, 450), DateTime(2017, 04, 13) => (p2, 450), DateTime(2017, 04, 20) => (p1, 450), DateTime(2017, 04, 27) => (p2, 450), DateTime(2017, 04, 30) => (p2, 120)))

date = DateTime(2017, January, 1, 6)
t = Timing(timeBeginning=date, timeHorizon=Week(4), timeStepDuration=Hour(1), shiftBeginning=date, shiftDuration=Hour(8))

epDates = collect(date:Hour(1):date + Week(52))
epRaw = 50 + 20 * sin.(1:length(epDates))
ep = TimeArray(epDates, epRaw)
# smooth(ep, 3, 3, 8)
# plot([ep[DateTime(2017, 1, 1, 6) : Hour(1) : DateTime(2017, 1, 1, 6) + Day(3 + 3 + 8) - Hour(1)].values', smooth(ep, 3, 3, 8).values']')
# plot([ep.values[1:1000]', changeVolatility(ep, 1.15).values[1:1000]', changeVolatility(ep, 1.5).values[1:1000]']')

function hrp_test(d::DateTime)
  base = 1000

  if hour(d) < 6 || hour(d) >= 22 # Night.
    base *= 1.2
  end

  if dayname(d) == "Sunday" # WE.
    base *= 2
  end

  return base
end
eo = EnergyObjective(ep, t)
hro = HRCostObjective(hrp_test)
o = ObjectiveCombination([eo, hro])

nTeams = 5
canWorkNights = Array(trues(nTeams))
canWorkDays = Array(trues(nTeams))

priorNoticeDelay = 2 # days
notificationFrequency = 1 # day
completeHorizon = 1 * 7 # days
# completeHorizon = 13 * 7 # days
optimisationHorizon = 14 # days; each iteration works on one week.
hoursPerShift = 8
timeBetweenShifts = 2
consecutiveDaysOff = (2, 9) # Two days off every nine days.
maxHoursPerWeek = 50
hoursContract = (38, 13)

m = modelMultiple(p, ob, t, o, canWorkDays, canWorkNights, priorNoticeDelay, notificationFrequency, completeHorizon, 2 * optimisationHorizon, optimisationHorizon, hoursPerShift, timeBetweenShifts, consecutiveDaysOff, maxHoursPerWeek, hoursContract, (1., 1., 1., 1., 1.), :smart, CplexSolver())
