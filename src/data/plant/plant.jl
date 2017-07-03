"""
A complete plant, described by its equipment and the possible routes between these pieces of equipment.

Two constructors are provided:

  * `Plant(equipments, routes)` takes both a list of pieces of equipment and a list of routes: it performs extra
    security checks based on the list of pieces of equipments (it should contain **all** pieces of equipment that must
    be within the plant). This is mostly useful when trying to debug a model: for example, it will indicate when
     a piece of equipment ispresent in the list but has no associated routes.
  * `Plant(routes)` takes only a list of routes. It infers the list of pieces of equipment from the routes, which might
    miss one or several pieces of equipment.
"""
struct Plant
  equipments::Array{AbstractEquipment, 1}
  routes::Array{Route, 1}

  function Plant(equipments::Array{Equipment, 1}, routes::Array{Route, 1})
    # Check whether names are unique.
    equipmentNames = [name(e) for e in equipments]
    if length(equipmentNames) != length(unique(equipmentNames))
      error("Some equipment names are not unique within the plant.")
    end

    # Check whether each equipment is found in at least one route when there are multiple pieces of equipment.
    # Otherwise, there are no routes.
    if length(equipments) > 1
      for e in equipments
        foundInRoute = false
        for r in routes
          if e == from(r) || e == to(r)
            foundInRoute = true
            break
          end
        end

        if ! foundInRoute
          error("The equipment " * name(e) * " has not been found in any route.")
        end
      end
    else
      if length(routes) > 0
        error("There is only one piece of equipment, but there are routes: routes must link two pieces of equipment within the plant.")
      end
    end

    # Check whether the equipments in the route are known.
    for r in routes
      if ! in(from(r), equipments)
        error("The origin equipment of a route, " * name(from(r)) * ", was not found in the equipment list. ")
      end
      if ! in(to(r), equipments)
        error("The destination equipment of a route, " * name(to(r)) * ", was not found in the equipment list. ")
      end
    end

    # Sanity checks done. Add the implicit equipments.
    eqs = convert(Array{AbstractEquipment, 1}, copy(equipments))
    push!(eqs, inEquipment)
    push!(eqs, outEquipment)
    new(eqs, routes)
  end

  function Plant(routes::Array{Route, 1})
    # Determine the list of pieces of equipment.
    equipments = [from(r) for r in routes]
    push!(equipments, [to(r) for r in routes]...)
    equipments = unique(equipments)

    # Check whether names are unique.
    if length([name(e) for e in equipments]) != length(unique([name(e) for e in equipments]))
      error("Equipment names are not unique within the plant.")
    end

    # Sanity checks done.
    new(equipments, routes)
  end
end

equipments(p::Plant) = p.equipments
kinds(p::Plant) = unique([kind(e) for e in equipments(p)])

equipments(p::Plant, k::Symbol) = filter(e -> kind(e) == k, equipments(p))
hasEquipment(p::Plant, k::Symbol) = length(filter(e -> kind(e) == k, equipments(p))) > 0

hasEquipment(p::Plant, n::AbstractString) = length(filter(e -> name(e) == n, equipments(p))) > 0
function equipment(p::Plant, n::AbstractString)
  eqs = filter(e -> name(e) == n, equipments(p))
  if length(eqs) == 1
    return eqs[1]
  else # Manually throw an error, Julia's makes no sense here (wrong level of abstraction).
    error("Equipment " * n * " not found in plant. ")
  end
  # No need to test for > 1: names are unique (ensured by constructor).
end

"""
Finds a list of routes between two elements (`from` and `to`), that may be a normal route (`mode=:Normal`,
the default) or not (`mode=:Abnormal`), or any kind of route (normal or not: `mode=nothing`).
These elements must be adjacent (this function will not consider paths that go through a third piece of equipment
or more).

Any may be omitted; all routes with the given elements are considered. For example, if `from=nothing` but
`to` is a piece of equipment, then all routes going to `to` are returned. If `from=nothing` and `to=nothing`,
then all routes in the plant are returned.

Elements can be given either as `Equipment` instances or as symbols describing the required kind of equipment.
"""
function routes(p::Plant; from=nothing, to=nothing, mode=nothing)
  r = copy(p.routes) # Need a copy to use the in-place operators later on.
  # (Otherwise, just a reference to the initial array, and the filtering happens on p's array.)

  if from != nothing
    filter!((e) -> origin(e) == from || kind(origin(e)) == from, r)
  end
  if to != nothing
    filter!((e) -> destination(e) == to || kind(destination(e)) == to, r)
  end
  if mode == :Normal
    filter!(isnormal, r)
  elseif mode == :Abnormal
    filter!(isabnormal, r)
  end
  return r
end
