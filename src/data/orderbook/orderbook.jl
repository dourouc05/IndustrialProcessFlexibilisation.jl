"""
An order book contains the due dates for a series of products, with the required quantities.
"""
struct OrderBook
  book::Array{Pair{DateTime, Tuple{Product, Float64}}, 1}
  productIds::Dict{Product, Int}

  function OrderBook(book::Array{Pair{DateTime, Tuple{Product, Float64}}, 1})
    products = unique(Product[o[2][1] for o in book])
    productIds = Dict(zip(products, collect(1:length(products))))
    return new(book, productIds)
  end
end

OrderBook(book::Dict{DateTime, Tuple{Product, Float64}}) = OrderBook(collect(book))

orderBook(ob::OrderBook) = ob.book
dates(ob::OrderBook) = sort(unique([o[1] for o in orderBook(ob)])) # All dates at which quantities are due, in chronological order.
productIds(ob::OrderBook) = ob.productIds

orders(ob::OrderBook, dt::DateTime) = map((p) -> p[2], filter((o) -> o[1] == dt, orderBook(ob)))
nOrders(ob::OrderBook) = length(orderBook(ob))

products(ob::OrderBook) = collect(keys(productIds(ob)))
nProducts(ob::OrderBook) = length(productIds(ob))
productId(ob::OrderBook, p::Product) = productIds(ob)[p]
productFromId(ob::OrderBook, i::Int) = collect(keys(productIds(ob)))[find((e) -> e == i, collect(values(productIds(ob))))[1]]

earliest(ob::OrderBook) = minimum(dates(ob))
latest(ob::OrderBook)   = maximum(dates(ob))

"""
All the orders that are due on or before `dt` for the given order book `ob`.

This function implements different behaviours about multiple orders for the same product.

  * By default, multiple orders for the same product are merged (`cumulative=true`). The returned data structure
    is a dictionary that maps products to quantities.
  * To disable this behaviour, use `cumulative=false`. In this case, each individual order is a tuple containing
    a product a quantity. All the orders are returned as an array of tuples. The orders are ordered in time,
    albeit this information is not available in the output.
"""
function dueBy(ob::OrderBook, dt::DateTime; cumulative::Bool=true)
  if ! cumulative
    # By construction, dates(ob) returns the dates in chronological order.
    # Returns a vector of ordered quantities.
    lo = Tuple{Product, Float64}[]
    for date in filter((d) -> d <= dt, dates(ob))
      push!(lo, orders(ob, date)...)
    end
    return lo
  else
    noncumulative = dueBy(ob, dt, cumulative=false)
    ret = Dict{Product, Float64}()
    for order in noncumulative
      if in(order[1], keys(ret))
        ret[order[1]] += order[2]
      else
        ret[order[1]] = order[2]
      end
    end
    return ret
  end
end

fromto(ob::OrderBook, from::DateTime, to::DateTime) = OrderBook(filter(p -> p[1] >= from && p[1] <= to, orderBook(ob)))

function rand(::Type{OrderBook}, dates::Array{DateTime, 1}, dateAverage::Float64, product::Product)
  # Goal: on average, each date has dateAverage to produce. However, this quantity might be (much) higher.
  # But there must be some limit on the beginning of the produced order book: the first few productions cannot be
  # too high, or the problem will be infeasible (if the limit per week is 10k and the plan asks for 20k, infeasible;
  # however, for the following weeks, if the plan is higher than the limit, then the surplus might have been produced
  # before).

  # Raw generation.
  values = rand(length(dates))
  values *= length(dates) * dateAverage / sum(values)

  # Smooth the values.
  maxProd = dateAverage
  budgetToDispatch = 0
  for i in eachindex(dates)
    if sum(values[1:i]) >= maxProd
      budgetToDispatch += sum(values[1:i]) - maxProd
      values[i] = dateAverage
    else
      toAdd = min(budgetToDispatch, maxProd - sum(values[1:i-1]))
      values[i] += toAdd
      budgetToDispatch -= toAdd
    end
    maxProd += dateAverage
  end

  # Return an OrderBook.
  productedValues = map((v) -> (product, v), values)
  return OrderBook(Dict(zip(dates, productedValues)))
end
