abstract type AbstractEquipment end

"""
One piece of equipment that is available in the factory. A factory may have multiple equivalent machines:
for example, a steel mill might have two EAFs; in this case, each EAF has its own `name` (like `EAF South` and
`EAF East`), but the same `kind` (`:eaf`).

Optionally, a piece of equipment may reduce the quantity of material between its input and its output, with a factor
`transformationRate`. If `1` unit comes into this equipment, `1` unit stays within the equipment for the duration
of the process, only `transformationRate` gets out. (Thus `transformationRate` is restricted to be within `(0, 1]`.)
"""
struct Equipment <: AbstractEquipment
  name::AbstractString
  kind::Symbol
  transformationRate::Float64

  minimumUpTime::TimePeriod # TODO: To factor out! (Continuous process that has a minimum up time.)
  minimumProduction::Float64 # TODO: To factor out! (Batch process that has a min/max production.)
  maximumProduction::Float64 # TODO: To factor out!
  processTime::TimePeriod # TODO: To factor out! (Batch processing time.)

  function Equipment(name::AbstractString, kind::Symbol, transformationRate::Float64=1.,
                     minimumUpTime::TimePeriod=Hour(1), minimumProduction::Float64=0.0, maximumProduction::Float64=1.e6,
                     processTime::TimePeriod=Hour(1))
    # Check the transformation rate makes sense.
    if transformationRate > 1.0
      error("The transformation rate for equipment " * name * " is too high (" * string(transformationRate) * " > 1).")
    elseif transformationRate <= 0.0
      error("The transformation rate for equipment " * name * " is too low (" * string(transformationRate) * " <= 0).")
    end

    # Production maximum must be above or equal to the minimum.
    if maximumProduction < minimumProduction
      error("The maximum production is below the minimum production. The maximum must be greater than or equal to the minimum.")
    end

    new(name, kind, transformationRate, minimumUpTime, minimumProduction, maximumProduction, processTime)
  end
end

name(e::Equipment) = e.name::AbstractString
kind(e::Equipment) = e.kind
transformationRate(e::Equipment) = e.transformationRate
minimumUpTime(e::Equipment) = e.minimumUpTime
minimumProduction(e::Equipment) = e.minimumProduction
maximumProduction(e::Equipment) = e.maximumProduction
processTime(e::Equipment) = e.processTime

==(e1::Equipment, e2::Equipment) = (name(e1) == name(e2) && kind(e1) == kind(e2))
hash(e::Equipment) = hash(name(e) * string(kind(e))) # More efficient hashing for equipment objects.



abstract type ImplicitEquipment<:AbstractEquipment end

struct InImplicitEquipment <: ImplicitEquipment end

name(e::InImplicitEquipment) = "in"
kind(e::InImplicitEquipment) = :in
transformationRate(e::InImplicitEquipment) = 1.0
minimumUpTime(e::InImplicitEquipment) = Hour(0)

struct OutImplicitEquipment <: ImplicitEquipment end

name(e::OutImplicitEquipment) = "out"
kind(e::OutImplicitEquipment) = :out
transformationRate(e::OutImplicitEquipment) = 1.0
minimumUpTime(e::OutImplicitEquipment) = Hour(0)

inEquipment = InImplicitEquipment()
outEquipment = OutImplicitEquipment()
