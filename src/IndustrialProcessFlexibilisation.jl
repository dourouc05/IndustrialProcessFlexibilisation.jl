module IndustrialProcessFlexibilisation
  ## Exports for data structures (data/).
  # Genera data structures (data/)
  export Timing
  export timeBeginning, timeHorizon, timeStepDuration, timeEnding, shiftBeginning, shiftDuration, nOccurrencesPerPeriod, nTimeSteps, nTimeStepsPerShift, nDays, daysOfWeekBetween, daysOfWeekUntil, daysOfWeekFor, eachTimeStep, nShifts, dateToTimeStep, dateToShift, shift
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
  export AbstractEquipmentModel, EquipmentModel, ImplicitEquipmentModel, EquipmentModel,
         FlowModel,
         OrderBookModel,
         ProductionObjective, ObjectiveCombination, NoObjective, EnergyObjective, HRCostObjective,
         TimingModel,
         PlantModel
  export postConstraints, timing, orderBook
  export equipment, quantity, flowIn, flowOut, on, off, start, stop, currentProduct, checkDate, productId,
         origin, destination, timing, orderBook, minimumValue, maximumValue, orderBookDetails,
         objectiveTimeStep, objectiveShift, objective, objectives, symbols, weights, weight, nObjectives, objectiveObject, objective, symbol, weight, nonzeroObjectives, hasObjective, electricityPrice, hrPrice,
         timing, shiftOpen, shiftOpen, timeStepOpen,
         plant, timingModel, equipmentModels, flowModels, orderBookModel, equipmentModel, flowModel, nEquipments



  ## Exports for IO (io/).
  # Only adding methods to Base functions.

  ## Exports for utilities (utils/).
  export smooth, changeVolatility

  using Base.Iterators
  using Base.Dates
  using Base.Random
  using TimeSeries

  using MathProgBase
  using JuMP
  using Nemo

  using HDF5

  solve = JuMP.solve # Resolve conflict between Nemo and JuMP

  import Base: start, next, done, eltype, length, copy, find, ==, hash, writecsv, replace, convert
  import Base.Random: rand

  include("data/data.jl")
  include("model/model.jl")
  include("io/datastructures_io.jl")
  include("io/results_io.jl")
  include("utils/price.jl")
end
