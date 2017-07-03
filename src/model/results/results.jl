struct Batch
  product::Product
  quantity::Float64

  start::DateTime
  duration::TimePeriod
end

struct Results
  shifts::BitArray{1} # To be understood with the Timing object.
  productionBatches::Array{Batch, 1}
end
