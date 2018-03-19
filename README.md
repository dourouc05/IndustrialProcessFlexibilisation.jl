# IndustrialProcessFlexibilisation

[![Project Status: Inactive – The project has reached a stable, usable state but is no longer being actively developed; support/maintenance will be provided as time allows.](http://www.repostatus.org/badges/latest/inactive.svg)](http://www.repostatus.org/#inactive) [![The MIT License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](http://opensource.org/licenses/MIT) [![Build Status](https://travis-ci.org/dourouc05/IndustrialProcessFlexibilisation.jl.svg?branch=master)](https://travis-ci.org/dourouc05/IndustrialProcessFlexibilisation.jl) [![Build status](https://ci.appveyor.com/api/projects/status/vxl5gyuj4gagsk42?svg=true)](https://ci.appveyor.com/project/dourouc05/industrialprocessflexibilisation-jl/) [![Coverage Status](https://coveralls.io/repos/dourouc05/IndustrialProcessFlexibilisation.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/dourouc05/IndustrialProcessFlexibilisation.jl?branch=master) [![codecov.io](http://codecov.io/github/dourouc05/IndustrialProcessFlexibilisation.jl/coverage.svg?branch=master)](http://codecov.io/github/dourouc05/IndustrialProcessFlexibilisation.jl?branch=master)

This [Julia](http://julialang.org/) package deals with the problem of flexibilisation in the industry: how can a plant reduce its electricity costs in a world where price variations have a high amplitude? An answer is flexibilisation: use the machines when the electricity is cheap, with a mix of optimisation and price prediction. The major problem of this approach is that the workers' schedule become unpredictable and might not respect their well-being as well as current implementations of shift work. This package provides a methodology to tackle both issues: first, providing production plannings that exploit flexibility; second, making optimised shift schedules. 

As such, this package provides an objective way of evaluating the impact of flexibilisation on a given industrial site: on the HR and electricity costs, and on the workers' schedules. **It does not, however, include any mechanism to compensate for the impact on the workers**, as these considerations go well beyond the scope of this work. This research work allows quantifying flexibility, and seeing how interesting it would be (for example, to restore some competitiveness), but should not be seen as a turnkey tool to implement it without further ado.

To install: 
    
    Pkg.clone("https://github.com/dourouc05/IndustrialProcessFlexibilisation.jl")
    
See the example in the `docs/examples` folder, albeit it is not 100% working at the time. 

Some results have been presented at the [COMEX workshop](http://orbi.ulg.ac.be/handle/2268/207330) and at the [IFORS 2017 conference](http://orbi.ulg.ac.be/handle/2268/207330). 

This package has been developed in the context of the [InduStore project](http://www.industore-project.be/). 
