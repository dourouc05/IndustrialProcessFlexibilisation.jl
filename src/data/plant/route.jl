"""
An abstract route between two pieces of equipment. This is equivalent to a directed edge in a graph.

A route must define an `from` and a `to` (or redefine the methods `from` and `to`), both of which being `Equipment`s.
"""
abstract type Route end

from(r::Route) = r.from
to(r::Route) = r.to
origin(r::Route) = from(r)
destination(r::Route) = to(r)

isnormal(r::Route) = error("This function has not been defined for the given type.")
isabnormal(r::Route) = error("This function has not been defined for the given type.")

"""
A normal route between two pieces of equipment, i.e. the one that is always preferred, except in specific circumstances
such as maintenance or breakdown.
"""
struct NormalRoute <: Route
  from::Equipment
  to::Equipment
end

isnormal(r::NormalRoute) = true
isabnormal(r::NormalRoute) = false

"""
An abnormal route is followed only if absolutely necessary, for example because it requires extra manipulations
to be used.
"""
struct AbnormalRoute <: Route
  from::Equipment
  to::Equipment
  # TODO! Costs? Multiple implementations?
end

isnormal(r::AbnormalRoute) = false
isabnormal(r::AbnormalRoute) = true
