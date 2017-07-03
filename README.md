# IndustrialProcessFlexibilisation

[![Build Status](https://travis-ci.org/dourouc05/IndustrialProcessFlexibilisation.jl.svg?branch=master)](https://travis-ci.org/dourouc05/IndustrialProcessFlexibilisation.jl) [![Coverage Status](https://coveralls.io/repos/dourouc05/IndustrialProcessFlexibilisation.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/dourouc05/IndustrialProcessFlexibilisation.jl?branch=master) [![codecov.io](http://codecov.io/github/dourouc05/IndustrialProcessFlexibilisation.jl/coverage.svg?branch=master)](http://codecov.io/github/dourouc05/IndustrialProcessFlexibilisation.jl?branch=master)

This [Julia](http://julialang.org/) package deals with the problem of flexibilisation in the industry: how can a plant reduce its electricity costs in a world where price variations have a high amplitude? An answer is flexibilisation: use the machines when the electricity is cheap, with a mix of optimisation and price prediction. The major problem of this approach is that the workers' schedule become unpredictable and might not respect their well-being as well as current implementations of shift work. This package provides a methodology to tackle both issues: first, providing production plannings that exploit flexibility; second, making optimised shift schedules. 
