@testset "Data structures" begin
  @testset "Equipment" begin
    # Test the constructor and the basic getters.
    e1 = Equipment("EAF", :eaf)
    @test(name(e1) == "EAF")
    @test(kind(e1) == :eaf)
    @test(transformationRate(e1) == 1.0)

    # It should not be a problem to define a second equipment with the same kind or name (for the latter, as long as they do not belong to the same plant).
    e2 = Equipment("EAF B", :eaf)
    @test(name(e2) == "EAF B")
    @test(kind(e2) == :eaf)
    @test(transformationRate(e1) == 1.0)
    @test(e1 != e2)

    # Setting the transformation rate should overwrite the default value.
    e1 = Equipment("EAF", :eaf, 0.9)
    @test(name(e1) == "EAF")
    @test(kind(e1) == :eaf)
    @test(transformationRate(e1) == 0.9)

    # Some transformation rates are not allowed.
    @test_throws(ErrorException, Equipment("EAF", :eaf, 0.0))
    @test_throws(ErrorException, Equipment("EAF", :eaf, -0.1))
    @test_throws(ErrorException, Equipment("EAF", :eaf, 1.1))

    # Test all constructor arguments and the relevant accessors.
    e1 = Equipment("EAF", :eaf, .5, Hour(2), 5.0, 6.0, Hour(5))
    @test(name(e1) == "EAF")
    @test(kind(e1) == :eaf)
    @test(transformationRate(e1) == .5)
    @test(minimumUpTime(e1) == Hour(2))
    @test(minimumProduction(e1) == 5.0)
    @test(maximumProduction(e1) == 6.0)
    @test(processTime(e1) == Hour(5))

    # Ensure the production minimum is below the maximum (or equal to it).
    @test_throws(ErrorException, Equipment("EAF", :eaf, .5, Hour(2), 20.0, 6.0, Hour(5)))

    # Checking for equality does not only check the name.
    e1 = Equipment("EAF", :eaf)
    e2 = Equipment("EAF B", :eaf)
    e3 = Equipment("EAF", :lf)
    e4 = Equipment("EAF", :eaf)
    @test(e1 != e2)
    @test(e1 != e3)
    @test(e1 == e4)

    # Basic tests for implicit equipments.
    @test(name(inEquipment) == "in")
    @test(kind(inEquipment) == :in)
    @test(transformationRate(inEquipment) == 1.0)
    @test(minimumUpTime(inEquipment) == Hour(0))

    @test(name(outEquipment) == "out")
    @test(kind(outEquipment) == :out)
    @test(transformationRate(outEquipment) == 1.0)
    @test(minimumUpTime(outEquipment) == Hour(0))

    # Taking the name or the kind of an implicit equipment is not allowed.
  end

  @testset "Routes" begin
    # Test the normal routes.
    e1 = Equipment("EAF", :eaf)
    e2 = Equipment("LF", :lf)
    r1 = NormalRoute(e1, e2)
    @test(from(r1) == e1)
    @test(to(r1) == e2)
    @test(origin(r1) == from(r1))
    @test(destination(r1) == to(r1))
    @test(isnormal(r1))
    @test(! isabnormal(r1))

    # Test the abnormal routes.
    e1 = Equipment("EAF", :eaf)
    e2 = Equipment("LF", :lf)
    r1 = AbnormalRoute(e1, e2)
    @test(from(r1) == e1)
    @test(to(r1) == e2)
    @test(origin(r1) == from(r1))
    @test(destination(r1) == to(r1))
    @test(! isnormal(r1))
    @test(isabnormal(r1))

    # Implementing a custom route without respecting the interface.
    cr = ConcreteRoute()
    @test_throws ErrorException from(cr)
    @test_throws ErrorException to(cr)
    @test_throws ErrorException origin(cr)
    @test_throws ErrorException destination(cr)
    @test_throws ErrorException isnormal(cr)
    @test_throws ErrorException isabnormal(cr)
  end

  @testset "Plant" begin
    @testset "Constructors" begin
      # Test well-formed input (only check there is no exception when calling the constructor).
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      le = [e1, e2, e3]
      ele = [e1, e2, e3, inEquipment, outEquipment]
      elk = [:eaf, :lf, :cc, :in, :out]
      lr = Route[r1, r2]
      # @test(Plant(le, lr) == Plant(le, lr)) # Check whether there is no error when building the plant object. TODO: How to check the object is built without error? See when migrating to Julia 0.5's test infrastructure.
      p = Plant(le, lr)

      @test(all((r) -> in(r, equipments(p)), ele))
      @test(all((r) -> in(r, ele), equipments(p)))
      @test(length(ele) == length(equipments(p)))

      @test(all((r) -> in(r, kinds(p)), elk))
      @test(all((r) -> in(r, elk), kinds(p)))
      @test(length(elk) == length(kinds(p)))

      @test(all((r) -> in(r, routes(p)), lr))
      @test(all((r) -> in(r, lr), routes(p)))
      @test(length(lr) == length(routes(p)))

      @test(hasEquipment(p, :eaf))
      @test(hasEquipment(p, :lf))
      @test(hasEquipment(p, :cc))

      @test(equipments(p, :eaf) == [e1])
      @test(equipments(p, :lf) == [e2])
      @test(equipments(p, :cc) == [e3])

      @test(hasEquipment(p, "EAF"))
      @test(hasEquipment(p, "LF"))
      @test(hasEquipment(p, "CC"))

      @test(equipment(p, "EAF") == e1)
      @test(equipment(p, "LF") == e2)
      @test(equipment(p, "CC") == e3)

      @test_throws(ErrorException, equipment(p, "I don't exist"))

      # Test ill-formed input: nonunique names.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("EAF", :lf) # Not "LF"
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      le = [e1, e2, e3]
      lr = Route[r1, r2]
      @test_throws(ErrorException, Plant(lr))
    end

    @testset "Debug constructor" begin
      # Test ill-formed input: multiple pieces of equipments, but no routes.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      le = [e1, e2, e3]
      lr = Route[]
      @test_throws(ErrorException, Plant(le, lr))

      # Test ill-formed input: nonunique names.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("EAF", :lf) # Not "LF"
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      le = [e1, e2, e3]
      lr = Route[r1, r2]
      @test_throws(ErrorException, Plant(le, lr))

      # Test ill-formed input: equipment in no route.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      e4 = Equipment("AOD", :aod) # Strange equipment that is never used.
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      le = [e1, e2, e3, e4]
      lr = Route[r1, r2]
      @test_throws(ErrorException, Plant(le, lr))

      # Test ill-formed input: origin equipment of a route missing.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      le = [e2, e3] # No e1.
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      lr = Route[r1, r2]
      @test_throws(ErrorException, Plant(le, lr))

      # Test ill-formed input: end equipment of a route missing.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      le = [e1, e2] # No e3.
      lr = Route[r1, r2]
      @test_throws(ErrorException, Plant(le, lr))

      # Test ill-formed input: multiple pieces of equipment, no routes.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      le = [e1, e2, e3]
      lr = Route[]
      @test_throws(ErrorException, Plant(le, lr))

      # Test ill-formed input: one piece of equipment, routes.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      le = [e1]
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      lr = Route[r1, r2]
      @test_throws(ErrorException, Plant(le, lr))
    end

    @testset "Requirements between a product and a plant" begin
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      le = [e1, e2]
      lr = Route[r1]
      p = Plant(le, lr)

      c = ConstantConsumption(2.0)
      p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (150.0, 155.0) for e in [e1, e2]]))
      p2 = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (150.0, 155.0) for e in [e1, e2, e3]]))
      @test(hasRequiredEquipments(p, p1))
      @test(! hasRequiredEquipments(p, p2))
    end

    @testset "Route getters" begin
      # Test the basic getters. Routes: cannot check the two lists are equal, as the order may change; however, even element
      # of a list must be in the other, and vice-versa, which is actually the property to ensure.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      lr = Route[r1, r2]
      p = Plant(lr)
      @test(all((r) -> in(r, routes(p)), lr))
      @test(all((r) -> in(r, lr), routes(p)))
      @test(length(lr) == length(routes(p)))

      # Test the more intelligent route getter, based on source and destination. Only one route in output.
      e1 = Equipment("EAF", :eaf)
      e2 = Equipment("LF", :lf)
      e3 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e2)
      r2 = NormalRoute(e2, e3)
      lr = Route[r1, r2]
      p = Plant(lr)

      @test(routes(p, from=e1) == [r1])
      @test(routes(p, from=:eaf) == [r1])
      @test(routes(p, to=e2) == [r1])
      @test(routes(p, to=:lf) == [r1])

      @test(routes(p, from=e1, mode=:Normal) == routes(p, from=e1))
      @test(routes(p, from=:eaf, mode=:Normal) == routes(p, from=:eaf))
      @test(routes(p, to=e2, mode=:Normal) == routes(p, to=e2))
      @test(routes(p, to=:lf, mode=:Normal) == routes(p, to=:lf))
      @test(routes(p, from=e1, mode=:Abnormal) == Route[])
      @test(routes(p, from=:eaf, mode=:Abnormal) == Route[])
      @test(routes(p, to=e2, mode=:Abnormal) == Route[])
      @test(routes(p, to=:lf, mode=:Abnormal) == Route[])

      # Multiple routes in output.
      e1 = Equipment("EAF A", :eaf)
      e2 = Equipment("EAF B", :eaf)
      e3 = Equipment("LF A", :lf)
      e4 = Equipment("LF B", :lf)
      e5 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e3)
      r2 = NormalRoute(e2, e4)
      r3 = NormalRoute(e1, e4) # This one is just for the sake of testing, as it makes no practical sense.
      r4 = NormalRoute(e3, e5)
      r5 = NormalRoute(e4, e5)
      lr = Route[r1, r2, r3, r4, r5]
      p = Plant(lr)
      @test(routes(p, from=e1) == [r1, r3])
      @test(routes(p, from=:eaf) == [r1, r2, r3])
      @test(routes(p, to=e5) == [r4, r5])
      @test(routes(p, to=:cc) == [r4, r5])

      # Distinguish normal and abnormal routes.
      e1 = Equipment("EAF A", :eaf)
      e2 = Equipment("EAF B", :eaf)
      e3 = Equipment("LF A", :lf)
      e4 = Equipment("LF B", :lf)
      e5 = Equipment("CC", :cc)
      r1 = NormalRoute(e1, e3)
      r2 = NormalRoute(e2, e4)
      r3 = AbnormalRoute(e1, e4)
      r4 = NormalRoute(e3, e5)
      r5 = AbnormalRoute(e4, e5)
      lr = Route[r1, r2, r3, r4, r5]
      p = Plant(lr)
      @test(routes(p, from=e1) == [r1, r3])
      @test(routes(p, from=e1, mode=:Normal) == [r1])
      @test(routes(p, from=e1, mode=:Abnormal) == [r3])
      @test(routes(p, from=:eaf) == [r1, r2, r3])
      @test(routes(p, from=:eaf, mode=:Normal) == [r1, r2])
      @test(routes(p, from=:eaf, mode=:Abnormal) == [r3])
      @test(routes(p, to=e5) == [r4, r5])
      @test(routes(p, to=e5, mode=:Normal) == [r4])
      @test(routes(p, to=e5, mode=:Abnormal) == [r5])
      @test(routes(p, to=:cc) == [r4, r5])
      @test(routes(p, to=:cc, mode=:Normal) == [r4])
      @test(routes(p, to=:cc, mode=:Abnormal) == [r5])
    end
  end

  @testset "Consumption models" begin
    # Constant consumption.
    cc = ConstantConsumption(1.0)
    @test(consumption(cc) == 1.0)

    # Linear consumption.
    lc = LinearConsumption(1.0, 2.0)
    @test(intercept(lc) == 1.0)
    @test(slope(lc) == 2.0)

    # Quadratic consumption.
    qc = QuadraticConsumption(1.0, 2.0, 3.0)
    @test(intercept(qc) == 1.0)
    @test(slope(qc) == 2.0)
    @test(quadratic(qc) == 3.0)

    @test_throws(ErrorException, QuadraticConsumption(1.0, 2.0, -3.0)) # Nonconvex.

    # Piecewise linear consumption.
    plc = PiecewiseLinearConsumption([1.0, 2.0], [2.0, 3.0])
    @test(xs(plc) == [1.0, 2.0])
    @test(ys(plc) == [2.0, 3.0])

    @test_throws(ErrorException, PiecewiseLinearConsumption([1.0, 0.0], [2.0, 3.0]))
  end

  @testset "Product" begin
    c = ConstantConsumption(2.0)
    e1 = Equipment("EAF", :eaf)
    e2 = Equipment("LF", :lf)
    e3 = Equipment("CC", :cc)
    e4 = Equipment("AOD", :aod) # No consumption for this piece of equipment! Hence no capacities.
    p = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (150.0, 155.0) for e in [e1, e2, e3]]))

    @test(name(p) == "Steel")

    @test(all((e) -> in(e, collect(keys(consumptions(p)))), [e1, e2, e3])) # Consumption keys.
    @test(all((e) -> in(e, [e1, e2, e3]), keys(consumptions(p))))
    @test(length([e1, e2, e3]) == length(keys(consumptions(p))))

    @test(consumptions(p)[e1] == c) # Consumption values.
    @test(consumptions(p)[e2] == c)
    @test(consumptions(p)[e3] == c)
    @test(consumption(p, e1) == c)
    @test(consumption(p, e2) == c)
    @test(consumption(p, e3) == c)

    @test_throws(ErrorException, consumption(p, e4)) # Missing equipment.
    # consumption on ImplicitEquipment is not defined.

    @test(hasConsumption(p, e1))
    @test(hasConsumption(p, e2))
    @test(hasConsumption(p, e3))
    @test(! hasConsumption(p, e4))
    @test(! hasConsumption(p, inEquipment))
    @test(! hasConsumption(p, outEquipment))

    @test(hasConsumption(p, "EAF")) # Look up by name.
    @test(hasConsumption(p, "LF"))
    @test(hasConsumption(p, "CC"))
    @test(! hasConsumption(p, "AOD"))
    @test(! hasConsumption(p, "I don't exist"))
    @test(consumption(p, "EAF") == c)
    @test(consumption(p, "LF") == c)
    @test(consumption(p, "CC") == c)
    @test_throws(ErrorException, consumption(p, "AOD"))
    @test_throws(ErrorException, consumption(p, "I don't exist"))

    @test(hasConsumption(p, :eaf)) # Look up by symbol.
    @test(hasConsumption(p, :lf))
    @test(hasConsumption(p, :cc))
    @test(! hasConsumption(p, :aod))
    @test(! hasConsumption(p, :anythingelse))
    @test(consumption(p, :eaf) == Dict(e1 => c))
    @test(consumption(p, :lf) == Dict(e2 => c))
    @test(consumption(p, :cc) == Dict(e3 => c))
    @test(consumption(p, :aod) == Dict{Equipment, ConsumptionModel}())
    @test(consumption(p, :anythingelse) == Dict{Equipment, ConsumptionModel}())

    @test(all((e) -> in(e, requiredEquipments(p)), [:eaf, :lf, :cc]))
    @test(all((e) -> in(e, [:eaf, :lf, :cc]), requiredEquipments(p)))
    @test(length([:eaf, :lf, :cc]) == length(requiredEquipments(p)))

    @test(batchSizes(p) == Dict{Equipment, Tuple{Float64, Float64}}([e => (150.0, 155.0) for e in [e1, e2, e3]]))
    @test(minBatchSize(p, e1) == 150.0)
    @test(minBatchSize(p, e2) == minBatchSize(p, e1))
    @test(minBatchSize(p, e3) == minBatchSize(p, e1))
    @test(maxBatchSize(p, e1) == 155.0)
    @test(maxBatchSize(p, e2) == maxBatchSize(p, e1))
    @test(maxBatchSize(p, e3) == maxBatchSize(p, e1))
    @test(minBatchSize([p], e1) == 150.0)
    @test(minBatchSize([p], e2) == minBatchSize([p], e1))
    @test(minBatchSize([p], e3) == minBatchSize([p], e1))
    @test(maxBatchSize([p], e1) == 155.0)
    @test(maxBatchSize([p], e2) == maxBatchSize([p], e1))
    @test(maxBatchSize([p], e3) == maxBatchSize([p], e1))

    # Batch sizes for multiple products.
    c = ConstantConsumption(2.0)
    e1 = Equipment("EAF", :eaf)
    e2 = Equipment("LF", :lf)
    e3 = Equipment("CC", :cc)
    p = Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (150.0, 155.0) for e in [e1, e2, e3]]))
    p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (140.0, 145.0) for e in [e1, e2, e3]]))
    @test(minBatchSize([p, p2], e1) == 140.0)
    @test(minBatchSize([p, p2], e2) == minBatchSize([p, p2], e1))
    @test(minBatchSize([p, p2], e3) == minBatchSize([p, p2], e1))
    @test(maxBatchSize([p, p2], e1) == 155.0)
    @test(maxBatchSize([p, p2], e2) == maxBatchSize([p, p2], e1))
    @test(maxBatchSize([p, p2], e3) == maxBatchSize([p, p2], e1))

    # Consistency checks: both consumption and batch sizes must be present at the same time.
    # e3 in batch sizes, not consumption models.
    @test_throws(ErrorException, Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (150.0, 155.0) for e in [e1, e2, e3]])))
    # e3 in consumption models, not batch sizes.
    @test_throws(ErrorException, Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c, e3 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (150.0, 155.0) for e in [e1, e2]])))

    # Consistency checks: for batch sizes, the minimum must be less than or equal to the maximum.
    @test_throws(ErrorException, Product("Steel", Dict{Equipment, ConsumptionModel}(e1 => c, e2 => c), Dict{Equipment, Tuple{Float64, Float64}}([e => (10050.0, 155.0) for e in [e1, e2]])))
  end

  @testset "Order book" begin
    @testset "Simple case: one order per product" begin
      # No need for merging: both ways should give the same results for dueBy.
      c = ConstantConsumption(2.0)
      e = Equipment("EAF", :eaf)
      p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(DateTime(2010) => (p1, 50), DateTime(2011) => (p2, 50)))

      @test(orderBook(ob) == collect(Dict(DateTime(2010) => (p1, 50), DateTime(2011) => (p2, 50))))
      @test(dates(ob) == [DateTime(2010), DateTime(2011)])
      @test(all((r) -> in(r, products(ob)), [p1, p2]))
      @test(all((r) -> in(r, [p1, p2]), products(ob)))
      @test(nProducts(ob) == length([p1, p2]))
      @test(nProducts(ob) == 2)

      @test(length(productIds(ob)) == 2)
      @test(all((r) -> in(r, collect(keys(productIds(ob)))), [p1, p2]))
      @test(all((r) -> in(r, [p1, p2]), collect(keys(productIds(ob)))))
      @test(length(keys(productIds(ob))) == length([p1, p2]))
      @test(length(unique(collect(values(productIds(ob))))) == length([p1, p2]))
      @test(sort(collect(values(productIds(ob)))) == sort(unique(collect(values(productIds(ob))))))
      @test(sort([productId(ob, p) for p in products(ob)]) == sort(unique([productId(ob, p) for p in products(ob)])))
      @test(all((r) -> in(r, [productFromId(ob, pid) for pid in 1:nProducts(ob)]), [p1, p2]))
      @test(all((r) -> in(r, [p1, p2]), [productFromId(ob, pid) for pid in 1:nProducts(ob)]))
      @test(all(Bool[p == productFromId(ob, productId(ob, p)) for p in products(ob)]))

      @test(nOrders(ob) == 2)
      @test(earliest(ob) == DateTime(2010))
      @test(latest(ob) == DateTime(2011))

      @test(dueBy(ob, DateTime(2009)) == Dict{Product, Float64}())
      @test(dueBy(ob, DateTime(2010)) == Dict(p1 => 50))
      @test(dueBy(ob, DateTime(2011)) == Dict(p1 => 50, p2 => 50))
      @test(dueBy(ob, DateTime(2012)) == dueBy(ob, DateTime(2011)))

      @test(dueBy(ob, DateTime(2009)) == dueBy(ob, DateTime(2009), cumulative=true))
      @test(dueBy(ob, DateTime(2010)) == dueBy(ob, DateTime(2010), cumulative=true))
      @test(dueBy(ob, DateTime(2011)) == dueBy(ob, DateTime(2011), cumulative=true))
      @test(dueBy(ob, DateTime(2012)) == dueBy(ob, DateTime(2012), cumulative=true))

      @test(dueBy(ob, DateTime(2009), cumulative=false) == [])
      @test(dueBy(ob, DateTime(2010), cumulative=false) == [(p1, 50)])
      @test(dueBy(ob, DateTime(2011), cumulative=false) == [(p1, 50), (p2, 50)])
      @test(dueBy(ob, DateTime(2012), cumulative=false) == dueBy(ob, DateTime(2011), cumulative=false))

      @test(dueBy(fromto(ob, DateTime(2010), DateTime(2011)), DateTime(2012)) == Dict(p1 => 50, p2 => 50))
      @test(dueBy(fromto(ob, DateTime(2009), DateTime(2010)), DateTime(2012)) == Dict(p1 => 50))
      @test(dueBy(fromto(ob, DateTime(2011), DateTime(2012)), DateTime(2012)) == Dict(p2 => 50))
      @test(dueBy(fromto(ob, DateTime(2008), DateTime(2009)), DateTime(2012)) == Dict{Product, Float64}())
    end

    @testset "More complex case: multiple orders per product" begin
      # A product is ordered multiple times.
      c = ConstantConsumption(2.0)
      e = Equipment("EAF", :eaf)
      p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      p2 = Product("Inox", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))
      lp = [p1, p2]
      ob = OrderBook(Dict{DateTime, Tuple{Product, Float64}}(DateTime(2010) => (p1, 50), DateTime(2011) => (p2, 50), DateTime(2012) => (p1, 100)))

      @test(orderBook(ob) == collect(Dict(DateTime(2010) => (p1, 50), DateTime(2011) => (p2, 50), DateTime(2012) => (p1, 100))))
      @test(dates(ob) == [DateTime(2010), DateTime(2011), DateTime(2012)])

      @test(all((r) -> in(r, products(ob)), lp))
      @test(all((r) -> in(r, lp), products(ob)))
      @test(nProducts(ob) == length(lp))
      @test(nProducts(ob) == length(products(ob)))

      @test(nOrders(ob) == 3)
      @test(earliest(ob) == DateTime(2010))
      @test(latest(ob) == DateTime(2012))

      @test(dueBy(ob, DateTime(2009)) == Dict{Product, Float64}())
      @test(dueBy(ob, DateTime(2010)) == Dict(p1 => 50))
      @test(dueBy(ob, DateTime(2011)) == Dict(p1 => 50, p2 => 50))
      @test(dueBy(ob, DateTime(2012)) == Dict(p1 => 150, p2 => 50))
      @test(dueBy(ob, DateTime(2013)) == dueBy(ob, DateTime(2012)))

      @test(dueBy(ob, DateTime(2009)) == dueBy(ob, DateTime(2009), cumulative=true))
      @test(dueBy(ob, DateTime(2010)) == dueBy(ob, DateTime(2010), cumulative=true))
      @test(dueBy(ob, DateTime(2011)) == dueBy(ob, DateTime(2011), cumulative=true))
      @test(dueBy(ob, DateTime(2012)) == dueBy(ob, DateTime(2012), cumulative=true))
      @test(dueBy(ob, DateTime(2013)) == dueBy(ob, DateTime(2013), cumulative=true))

      @test(dueBy(ob, DateTime(2009), cumulative=false) == [])
      @test(dueBy(ob, DateTime(2010), cumulative=false) == [(p1, 50)])
      @test(dueBy(ob, DateTime(2011), cumulative=false) == [(p1, 50), (p2, 50)])
      @test(dueBy(ob, DateTime(2012), cumulative=false) == [(p1, 50), (p2, 50), (p1, 100)])
      @test(dueBy(ob, DateTime(2013), cumulative=false) == dueBy(ob, DateTime(2012), cumulative=false))

      @test(dueBy(fromto(ob, DateTime(2010), DateTime(2011)), DateTime(2012)) == Dict(p1 => 50, p2 => 50))
      @test(dueBy(fromto(ob, DateTime(2009), DateTime(2010)), DateTime(2012)) == Dict(p1 => 50))
      @test(dueBy(fromto(ob, DateTime(2011), DateTime(2012)), DateTime(2012)) == Dict(p1 => 100, p2 => 50))
      @test(dueBy(fromto(ob, DateTime(2008), DateTime(2009)), DateTime(2012)) == Dict{Product, Float64}())
    end

    @testset "Random generation" begin
      c = ConstantConsumption(2.0)
      e = Equipment("EAF", :eaf)
      p1 = Product("Steel", Dict{Equipment, ConsumptionModel}(e => c), Dict{Equipment, Tuple{Float64, Float64}}(e => (150.0, 155.0)))

      dateList = map(DateTime, 2010:2015)
      dateAvg = 50.

      srand(0)
      ob = rand(OrderBook, dateList, dateAvg, p1)

      @test(dates(ob) == dateList)
      @test(length(products(ob)) == 1)
      @test(products(ob)[1] == p1)
    end
  end

  @testset "Timing" begin
    @testset "Generic helpers" begin
      @test(nOccurrencesPerPeriod(Week(1), Day(1)) == 7)
      @test(nOccurrencesPerPeriod(Week(1), Hour(1)) == 168)
      @test(nOccurrencesPerPeriod(Month(1), Day(1)) == 31) # Rounding up.
      @test(nOccurrencesPerPeriod(Month(1), Day(2)) == 16) # Rounding up.

      @test(daysOfWeekBetween(DateTime(2017, 01, 01, 00), DateTime(2016, 12, 31)) == [])
      @test(daysOfWeekBetween(DateTime(2017, 01, 01, 00), DateTime(2017, 01, 01, 02)) == [7])
      @test(daysOfWeekBetween(DateTime(2017, 01, 01, 00), DateTime(2017, 01, 02, 02)) == [7, 1])
    end

    @testset "Constructor and getters" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
      @test(timeBeginning(t) == date)
      @test(timeHorizon(t) == Week(1))
      @test(timeEnding(t) == date + Week(1) - Hour(1))
      @test(timeStepDuration(t) == Hour(1))

      @test(nTimeSteps(t) == 168)
      @test(nTimeSteps(t, Minute(15)) == 1) # Something that lasts 15 minutes has to be represented as one time step here (even though it is much shorter than one hour).
      @test(nTimeSteps(t, Day(1)) == 24)
      @test(nDays(t) == 7)

      @test(daysOfWeekUntil(t, DateTime(2016, 12, 31)) == [])
      @test(daysOfWeekUntil(t, DateTime(2017, 01, 01, 13)) == [7]) # Must be after 12:32:42.
      @test(daysOfWeekUntil(t, DateTime(2017, 01, 02, 13)) == [7, 1]) # Must be after the day after, 12:32:42.
      @test(daysOfWeekFor(t, Day(1)) == [7, 1])
      @test(daysOfWeekFor(t, Day(2)) == [7, 1, 2])
      @test(daysOfWeekFor(t, Week(2)) == [7, 1, 2, 3, 4, 5, 6, 7, 1, 2, 3, 4, 5, 6, 7])
    end

    @testset "Constructor error handling" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)

      # Throw an error when a noninteger number of time steps are required for one hour.
      @test_throws(ErrorException, Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Minute(25)))
    end

    @testset "Converting dates to time steps and shifts" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
      @test_throws(ErrorException, dateToTimeStep(t, date - Hour(1)))
      @test(dateToTimeStep(t, date) == 1)
      @test(dateToTimeStep(t, date + Hour(1)) == 2)
    end

    @testset "Shifting in time" begin
      # Shifting objects: first by 0 days (i.e. do nothing), then by one day, and finally also tweak the horizon.
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
      @test(timeBeginning(shift(t, Day(0))) == date)
      @test(timeHorizon(shift(t, Day(0))) == timeHorizon(t))
      @test(timeEnding(shift(t, Day(0))) == date + Week(1) - Hour(1))
      @test(timeStepDuration(shift(t, Day(0))) == Hour(1))

      @test(timeBeginning(shift(t, Day(1))) == date + Day(1))
      @test(timeHorizon(shift(t, Day(1))) == timeHorizon(t))
      @test(timeEnding(shift(t, Day(1))) == date + Day(1) + Week(1) - Hour(1))
      @test(timeStepDuration(shift(t, Day(1))) == Hour(1))

      @test(timeBeginning(shift(t, Day(1), horizon=Week(1))) == date + Day(1))
      @test(timeHorizon(shift(t, Day(1), horizon=Week(1))) == Week(1))
      @test(timeEnding(shift(t, Day(1), horizon=Week(1))) == date + Day(1) + Week(1) - Hour(1))
      @test(timeStepDuration(shift(t, Day(1), horizon=Week(1))) == Hour(1))

      @test(timeBeginning(shift(t, Day(1), horizon=Week(2))) == date + Day(1))
      @test(timeHorizon(shift(t, Day(1), horizon=Week(2))) == Week(2))
      @test(timeEnding(shift(t, Day(1), horizon=Week(2))) == date + Day(1) + Week(2) - Hour(1))
      @test(timeStepDuration(shift(t, Day(1), horizon=Week(2))) == Hour(1))
    end

    @testset "Iterators" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

      # eachTimeStep, base call
      d = timeBeginning(t)
      it = eachTimeStep(t)
      state = start(it)
      while d <= timeEnding(t)
        @test(! done(it, state))
        (i, state) = next(it, state) # Calling next() on start() yields the first element.

        @test(i == d)
        d += timeStepDuration(t)
      end
      @test(done(it, state))

      # eachTimeStep, with the from argument
      d = timeBeginning(t) + Day(3)
      it = eachTimeStep(t, from=d)
      state = start(it)
      while d <= timeEnding(t)
        @test(! done(it, state))
        (i, state) = next(it, state) # Calling next() on start() yields the first element.

        @test(i == d)
        d += timeStepDuration(t)
      end
      @test(done(it, state))

      # eachTimeStep, problematic use of keyword arguments
      @test_throws(ErrorException, eachTimeStep(t, to=d, duration=d)) # Can't set both
      @test_throws(ErrorException, eachTimeStep(t, duration=d)) # Bad type for duration
      @test_throws(ErrorException, eachTimeStep(t, to=Hour(1))) # Bad type for to
      @test_throws(ErrorException, eachTimeStep(t, thiskeywordparameterdoesnotexist=Hour(1))) # Unknown keyword argument
      @test_throws(ErrorException, eachTimeStep(t, to=1)) # Invalid argument type.

      @test_throws(ErrorException, eachTimeStep(t, from=d, to=d, duration=d)) # Can't set all parameters at once
      @test_throws(ErrorException, eachTimeStep(t, from=d, duration=d)) # Bad type for duration
      @test_throws(ErrorException, eachTimeStep(t, from=d, to=Hour(1))) # Bad type for to
      @test_throws(ErrorException, eachTimeStep(t, from=d, thiskeywordparameterdoesnotexist=Hour(1))) # Unknown keyword argument
      @test_throws(TypeError, eachTimeStep(t, from=1)) # Invalid argument type.

      # eachTimeStep, with the to argument
      dur = Day(3)
      d = timeBeginning(t)
      it = eachTimeStep(t, to=d + dur)
      state = start(it)
      while d < timeBeginning(t) + dur
        @test(! done(it, state))
        (i, state) = next(it, state) # Calling next() on start() yields the first element.

        @test(i == d)
        d += timeStepDuration(t)
      end
      @test(done(it, state))

      # eachTimeStep, with the duration argument
      dur = Day(4)
      d = timeBeginning(t)
      it = eachTimeStep(t, duration=dur)
      state = start(it)
      while d < timeBeginning(t) + dur
        @test(! done(it, state))
        (i, state) = next(it, state) # Calling next() on start() yields the first element.

        @test(i == d)
        d += timeStepDuration(t)
      end
      @test(done(it, state))
    end
  end
  
  @testset "Shifts" begin
    @testset "Constructors and getters: one shift duration" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

      s = Shifts(t, date - Hour(4), Hour(8))
      @test shiftBeginning(s) == date - Hour(4)
      @test shiftDuration(s) == Hour(8)
      @test shiftDurations(s) == [shiftDuration(s)]
      @test shiftDurationsStart(s) == shiftDuration(s)
      @test shiftDurationsStep(s) == shiftDuration(s)
      @test shiftDurationsStop(s) == shiftDuration(s)
      @test minimumShiftDurations(s) == shiftDuration(s)
      @test maximumShiftDurations(s) == shiftDuration(s)
      @test nShiftDurations(s) == 1
      @test nTimeStepsPerShift(t, s) == [8]
      @test nShifts(t, s) == 22
      @test nShifts(t, s, Hour(8)) == nShifts(t, s)
      
      s = Shifts(t, date - Hour(4), Hour(8):Hour(8):Hour(8))
      @test shiftBeginning(s) == date - Hour(4)
      @test shiftDuration(s) == Hour(8)
      @test shiftDurations(s) == [shiftDuration(s)]
      @test shiftDurationsStart(s) == shiftDuration(s)
      @test shiftDurationsStep(s) == shiftDuration(s)
      @test shiftDurationsStop(s) == shiftDuration(s)
      @test minimumShiftDurations(s) == shiftDuration(s)
      @test maximumShiftDurations(s) == shiftDuration(s)
      @test nShiftDurations(s) == 1
      @test nTimeStepsPerShift(t, s) == [8]
      @test nShifts(t, s) == 22
      @test nShifts(t, s, Hour(8)) == nShifts(t, s)
      
      s = Shifts(t, date - Hour(4), 8)
      @test shiftBeginning(s) == date - Hour(4)
      @test shiftDuration(s) == Hour(8)
      @test shiftDurations(s) == [shiftDuration(s)]
      @test shiftDurationsStart(s) == shiftDuration(s)
      @test shiftDurationsStep(s) == shiftDuration(s)
      @test shiftDurationsStop(s) == shiftDuration(s)
      @test minimumShiftDurations(s) == shiftDuration(s)
      @test maximumShiftDurations(s) == shiftDuration(s)
      @test nShiftDurations(s) == 1
      @test nTimeStepsPerShift(t, s) == [8]
      @test nShifts(t, s) == 22
      @test nShifts(t, s, Hour(8)) == nShifts(t, s)
      
      s = Shifts(t, date - Hour(4), 8:8:8)
      @test shiftBeginning(s) == date - Hour(4)
      @test shiftDuration(s) == Hour(8)
      @test shiftDurations(s) == [shiftDuration(s)]
      @test shiftDurationsStart(s) == shiftDuration(s)
      @test shiftDurationsStep(s) == shiftDuration(s)
      @test shiftDurationsStop(s) == shiftDuration(s)
      @test minimumShiftDurations(s) == shiftDuration(s)
      @test maximumShiftDurations(s) == shiftDuration(s)
      @test nShiftDurations(s) == 1
      @test nTimeStepsPerShift(t, s) == [8]
      @test nShifts(t, s) == 22
      @test nShifts(t, s, Hour(8)) == nShifts(t, s)
    end
    
    @testset "Constructors and getters: one shift duration" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
      
      s = Shifts(t, date - Hour(4), Hour(2):Hour(2):Hour(8))
      @test shiftBeginning(s) == date - Hour(4)
      @test_throws ErrorException shiftDuration(s)
      @test shiftDurations(s) == collect(Hour(2):Hour(2):Hour(8))
      @test shiftDurationsStart(s) == Hour(2)
      @test shiftDurationsStep(s) == Hour(2)
      @test shiftDurationsStop(s) == Hour(8)
      @test minimumShiftDurations(s) == Hour(2)
      @test maximumShiftDurations(s) == Hour(8)
      @test nShiftDurations(s) == 4
      @test nTimeStepsPerShift(t, s) == [2, 4, 6, 8]
      @test nShifts(t, s) == 22 # Maximum length shifts!
      @test nShifts(t, s, Hour(2)) == 85
      @test nShifts(t, s, Hour(4)) == 43
      @test nShifts(t, s, Hour(6)) == 29
      @test nShifts(t, s, Hour(8)) == 22
      
      s = Shifts(t, date - Hour(4), 2:2:8)
      @test shiftBeginning(s) == date - Hour(4)
      @test_throws ErrorException shiftDuration(s)
      @test shiftDurations(s) == collect(Hour(2):Hour(2):Hour(8))
      @test shiftDurationsStart(s) == Hour(2)
      @test shiftDurationsStep(s) == Hour(2)
      @test shiftDurationsStop(s) == Hour(8)
      @test minimumShiftDurations(s) == Hour(2)
      @test maximumShiftDurations(s) == Hour(8)
      @test nShiftDurations(s) == 4
      @test nTimeStepsPerShift(t, s) == [2, 4, 6, 8]
      @test nShifts(t, s) == 22 # Maximum length shifts! 
      @test nShifts(t, s, Hour(2)) == 85
      @test nShifts(t, s, Hour(4)) == 43
      @test nShifts(t, s, Hour(6)) == 29
      @test nShifts(t, s, Hour(8)) == 22
    end

    @testset "Constructor error handling" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

      # Throw an error when the shift duration is not a number of hours.
      @test_throws MethodError Shifts(t, date - Hour(4), Second(744))

      # Throw an error when the shifts start later than the optimisation.
      @test_throws ErrorException Shifts(t, date + Hour(4), Hour(8))

      # Throw an error when no shift durations are given. 
      @test_throws ErrorException Shifts(t, date, Hour(2):Hour(2):Hour(0))
      
      # Throw an error when the shortest shift is nonexistent (i.e. lasts zero hours). 
      @test_throws ErrorException Shifts(t, date, Hour(0):Hour(2):Hour(4))

      # Current limitation: both the first and the last values of shift lengths must be divisible by the step. 
      # For this not to fail, the test on start and step must be performed later; hence not a great problem if this no more passes. 
      @test_throws ErrorException Shifts(t, date, Hour(3):Hour(2):Hour(5)) 

      # Current limitation: the shortest shift must have the same duration as the step. 
      @test_throws ErrorException Shifts(t, date, Hour(4):Hour(2):Hour(8))
    end

    @testset "Converting dates to time steps and shifts: one shift duration" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
      s = Shifts(t, date - Hour(4), Hour(8))

      @test_throws ErrorException dateToShift(s, date - Hour(4) - Hour(1))
      @test dateToShift(s, date - Hour(4)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(5)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(7)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(8)) == 2
      @test dateToShift(s, date - Hour(4) + Hour(12)) == 2
      
      @test_throws ErrorException dateToShift(s, date - Hour(4), Hour(1)) == 1
      @test dateToShift(s, date - Hour(4), Hour(8)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(5), Hour(8)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(7), Hour(8)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(8), Hour(8)) == 2
      @test dateToShift(s, date - Hour(4) + Hour(12), Hour(8)) == 2
    end
    
    @testset "Converting dates to time steps and shifts: multiple shift durations" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
      s = Shifts(t, date - Hour(4), 4:4:8)

      @test_throws ErrorException dateToShift(s, date - Hour(4) - Hour(1))
      @test dateToShift(s, date - Hour(4)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(5)) == 2
      @test dateToShift(s, date - Hour(4) + Hour(7)) == 2
      @test dateToShift(s, date - Hour(4) + Hour(8)) == 3
      @test dateToShift(s, date - Hour(4) + Hour(12)) == 4
      
      @test_throws ErrorException dateToShift(s, date - Hour(4), Hour(1)) == 1

      @test dateToShift(s, date - Hour(4), Hour(4)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(5), Hour(4)) == 2
      @test dateToShift(s, date - Hour(4) + Hour(7), Hour(4)) == 2
      @test dateToShift(s, date - Hour(4) + Hour(8), Hour(4)) == 3
      @test dateToShift(s, date - Hour(4) + Hour(12), Hour(4)) == 4
      
      @test dateToShift(s, date - Hour(4), Hour(8)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(5), Hour(8)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(7), Hour(8)) == 1
      @test dateToShift(s, date - Hour(4) + Hour(8), Hour(8)) == 2
      @test dateToShift(s, date - Hour(4) + Hour(12), Hour(8)) == 2
    end

    @testset "Shifting in time" begin
      # Shifting objects: first by 0 days (i.e. do nothing), then by one day.
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))
      s = Shifts(t, date - Hour(4), Hour(8))

      @test shiftBeginning(shift(t, s, Day(0))) == date - Hour(4)
      @test shiftDurations(shift(t, s, Day(0))) == shiftDurations(s)
      
      @test shiftBeginning(shift(shift(t, Day(1)), s, Day(1))) == date - Hour(4) + Day(1)
      @test shiftDurations(shift(shift(t, Day(1)), s, Day(1))) == shiftDurations(s)
    end
    
    @testset "Number of shifts: one shift duration" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

      # Focus on number of shifts: when optimisation and shifts start simultaneously, the computation is easy; if shifts start
      # before, there must be one more shift at most.
      s = Shifts(t, date, Hour(8))
      @test nShifts(t, s) == 3 * 7
      @test nShifts(t, s, Hour(8)) == 3 * 7
      @test_throws ErrorException nShifts(t, s, Hour(2))

      s = Shifts(t, date - Hour(4), Hour(8))
      @test nShifts(t, s) == 3 * 7 + 1
      @test nShifts(t, s, Hour(8)) == 3 * 7 + 1
      @test_throws ErrorException nShifts(t, s, Hour(2))

      s = Shifts(t, date - Hour(12), Hour(8))
      @test nShifts(t, s) == 3 * 7 + 1
      @test nShifts(t, s, Hour(8)) == 3 * 7 + 1
      @test_throws ErrorException nShifts(t, s, Hour(2))
    end
    
    @testset "Number of shifts: multiple shift durations" begin
      date = DateTime(2017, 01, 01, 12, 32, 42)
      t = Timing(timeBeginning=date, timeHorizon=Week(1), timeStepDuration=Hour(1))

      # Focus on number of shifts: when optimisation and shifts start simultaneously, the computation is easy; if shifts start
      # before, there must be one more shift at most.
      s = Shifts(t, date, 2:2:8)
      @test nShifts(t, s) == 3 * 7
      @test nShifts(t, s, Hour(8)) == 3 * 7
      @test nShifts(t, s, Hour(6)) == 4 * 7
      @test nShifts(t, s, Hour(4)) == 6 * 7
      @test nShifts(t, s, Hour(2)) == 12 * 7
      @test_throws ErrorException nShifts(t, s, Hour(1))

      s = Shifts(t, date - Hour(4), 2:2:8)
      @test nShifts(t, s) == 3 * 7 + 1
      @test nShifts(t, s, Hour(8)) == 3 * 7 + 1
      @test nShifts(t, s, Hour(6)) == 4 * 7 + 1
      @test nShifts(t, s, Hour(4)) == 6 * 7 + 1
      @test nShifts(t, s, Hour(2)) == 12 * 7 + 1
      @test_throws ErrorException nShifts(t, s, Hour(1))

      s = Shifts(t, date - Hour(12), 2:2:8)
      @test nShifts(t, s) == 3 * 7 + 1
      @test nShifts(t, s, Hour(8)) == 3 * 7 + 1
      @test nShifts(t, s, Hour(6)) == 4 * 7 + 1
      @test nShifts(t, s, Hour(4)) == 6 * 7 + 1
      @test nShifts(t, s, Hour(2)) == 12 * 7 + 1
      @test_throws ErrorException nShifts(t, s, Hour(1))
    end
  end
end
