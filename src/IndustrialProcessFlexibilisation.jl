module IndustrialProcessFlexibilisation
  ## Exports for data structures (data/).
  # Genera data structures (data/)
  export Timing
  export timeBeginning, timeHorizon, timeStepDuration, timeEnding, nOccurrencesPerPeriod, nTimeSteps, nDays, daysOfWeekBetween, daysOfWeekUntil, daysOfWeekFor, eachTimeStep, eachShift, nShifts, dateToTimeStep
  export Shifts
  export shiftBeginning, shiftDuration, shiftDurations, nShiftDurations, shiftDurationsStart, shiftDurationsStep, shiftDurationsStop, minimumShiftDurations, maximumShiftDurations, nTimeStepsPerShift, dateToShift, shift
  # Plant data structures (data/plant/)
  export ConsumptionModel, NoConsumption, ConstantConsumption, LinearConsumption, QuadraticConsumption, PiecewiseLinearConsumption,
         AbstractEquipment, Equipment, ImplicitEquipment, InImplicitEquipment, OutImplicitEquipment, inEquipment, outEquipment,
         Route, NormalRoute, AbnormalRoute,
         Plant
  export consumption, intercept, slope, quadratic, xs, ys,
         name, kind, transformationRate, minimumUpTime, minimumProduction, maximumProduction, processTime,
         from, to, origin, destination, isnormal, isabnormal,
         equipments, kinds, hasEquipment, equipment, routes, hasRequiredEquipments
  # Order book data structures (data/orderbook/)
  export OrderBook, Product
  export orderBook, dates, productIds, orders, nOrders, products, nProducts, productId, productFromId, earliest, latest, dueBy, fromto,
         name, consumptions, hasConsumption, requiredEquipments, consumption, batchSizes, minBatchSize, maxBatchSize

  ## Exports for models (model/).
  # Actual optimisation models (model/).
  export productionModel,
         teamModel, shiftFixedSchedule, shiftsFiveEight,
         modelMultiple, shiftsAsLetters, countShifts, countShiftSequences, findCycles
  # Model data structures, mimicking the previous data structures (model/ds/).
  export AbstractEquipmentModel, EquipmentModel, ImplicitEquipmentModel, 
         FlowModel,
         OrderBookModel,
         ProductionObjective, ObjectiveCombination, NoObjective, EnergyObjective, HRCostObjective,
         TimingModel,
         PlantModel
  export postConstraints, timing, orderBook
  export equipment, quantityAfter, quantityBefore, quantity, flowIn, flowOut, on, off, start, stop, currentProduct, checkDate, productId,
         origin, destination, timing, orderBook, minimumValue, maximumValue, orderBookDetails,
         objectiveTimeStep, objectiveShift, objective, objectives, symbols, weights, weight, nObjectives, objectiveObject, symbol, nonzeroObjectives, hasObjective, electricityPrice, hrPrice,
         shifts, shiftOpen, timeStepOpen,
         plant, timingModel, equipmentModels, flowModels, orderBookModel, equipmentModel, flowModel, nEquipments
  export ProductionModelResults, HRModelResults



  ## Exports for IO (io/).
  # Only adding methods to Base functions, explicitly imported below.

  ## Exports for utilities (utils/).
  export smooth, changeVolatility
  export shiftsAgregation

  using Base.Iterators
  using Base.Dates
  using Base.Random
  using TimeSeries

  using MathProgBase
  using JuMP

  using HDF5

  # Nemo disabled for now (could be used for a reformulation of the HR problem, but not working right now). 
  # using Nemo
  # solve = JuMP.solve # Resolve conflict between Nemo and JuMP

  import Base: start, next, done, eltype, length, copy, find, ==, hash, writecsv, replace, convert
  import Base.Random: rand
  import TimeSeries: from, to

  include("data/data.jl")
  include("utils/shifts.jl")
  include("model/model.jl")
  include("io/datastructures_io.jl")
  include("io/results_io.jl")
  include("utils/price.jl")
end
