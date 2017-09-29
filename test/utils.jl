@testset "Utilities" begin
  @testset "Price smoothing" begin
    timestamps = collect(DateTime(2017, 1, 1) : Hour(1) : DateTime(2017, 2, 1))
    ts_xs = 1:length(timestamps)
    ts_ys = sin.(ts_xs ./ pi)
    ts = TimeArray(timestamps, ts_ys)

    ts_new = smooth(ts, 3, 3, 8)
    ts_ref = [0.312962, 0.594481, 0.816273, 0.956056, 0.999785, 0.943067, 0.7916, 0.560603, 0.273282, -0.0414943, -0.352102, -0.627335, -0.83954, -0.967398, -0.998063, -0.928453, -0.765564, -0.525759, -0.233132, 0.0829171, 0.390636, 0.659108, 0.861361, 0.977074, 0.994621, 0.912241, 0.738209, 0.49001, 0.192581, -0.124197, -0.428497, -0.689746, -0.881698, -0.985066, -0.989467, -0.894457, -0.709582, -0.453417, -0.151697, 0.165263, 0.46562, 0.719196, 0.900516, 0.991362, 0.982608, 0.875132, 0.679733, 0.416042, 0.110552, -0.206045, -0.501941, -0.747407, -0.917783, -0.99595, -0.974056, -0.8543, -0.648713, -0.377951, -0.0692172, 0.246471, 0.537397, 0.774331, 0.933469, 0.998823, 0.963827, 0.831996, 0.616576, 0.339209, 0.0277629, -0.286473, -0.571927, -0.799921, -0.489049, -0.490151, -0.442009, -0.349458, -0.221798, -0.0718545, 0.0853084, 0.233901, 0.358993, 0.448018, 0.492031, 0.486611, 0.432301, 0.334559, 0.203204, 0.0514336, -0.105504, -0.251842, -0.372878, -0.456452, -0.494166, -0.482232, -0.421849, -0.319083, -0.18426, -0.0309242, 0.125519, 0.269351, 0.386121, 0.464099, 0.495449, 0.477023, 0.41067, 0.303058, 0.164998, 0.0103614, -0.145317, -0.286395, -0.398699, -0.470947, -0.495879, -0.470992, -0.398784, -0.286511, -0.145453, 0.0102192, 0.164864, 0.302946, 0.41059, 0.476984, 0.495455, 0.464149, 0.386211, 0.26947, 0.125656, -0.0307822, -0.184128, -0.318974, -0.421774, -0.482199, -0.494178, -0.456507, -0.372972, -0.251965, -0.105643, 0.0512922, 0.203074, 0.334454, 0.432232, 0.486583, 0.492049, 0.448079, 0.28462, 0.244368, 0.179564, 0.0967198, 0.00415816, -0.0888212, -0.172877, -0.239564, -0.282182, -0.29645, -0.280934, -0.237193, -0.169621, -0.0850083, 0.00814547, 0.100481, 0.182721, 0.246604, 0.28571, 0.296112, 0.276764, 0.229609, 0.159387, 0.0731504, -0.0204351, -0.111967, -0.192251, -0.253219, -0.288746, -0.295264, -0.272117, -0.22163, -0.148877, -0.0611665, 0.0326895, 0.123261, 0.201449, 0.259398, 0.291285, 0.293907, 0.267001, 0.21327, 0.138111, 0.0490772, -0.0448876, -0.134343, -0.2103, -0.26513, -0.293322, -0.292044, -0.261425, -0.204541, -0.127108, -0.0369034, 0.0570083, 0.145193, 0.21879, 0.270405, 0.294853, 0.289678, 0.255399, 0.195461, 0.115885, 0.0246661, -0.0690309, -0.155792, -0.226902, -0.275215, -0.295877, -0.286813, -0.248933, -0.186044, -0.104463, -0.0123862, 0.0809346, 0.166124, 0.234623, 0.27955, 0.296391, 0.283454, 0.242039, 0.176306, 0.0928604, 8.50442e-5, -0.0926988, -0.176169, -0.24194, -0.283404, -0.296395, -0.279607, -0.234727, -0.166265, -0.0810982, 0.0122163, 0.104303, 0.185911, 0.248841, 0.28677, 0.295888, 0.275278, 0.227011, 0.155937, 0.0691963, -0.0244966, -0.115728, -0.195333, -0.255313, -0.289642, -0.294871, -0.270475, -0.218904, -0.145341, -0.0571752, 0.0367347, 0.126954, 0.204418, 0.261345, 0.292015, 0.293346, 0.265206, 0.21042, 0.134494, 0.0450557, -0.0489095, -0.137961, -0.213151, -0.266927, -0.293885, -0.291316, -0.25948, -0.201574, -0.123416, -0.0328585, 0.0610001, 0.14873, 0.221517, 0.272049, 0.295248, 0.288785, 0.253307, 0.19238, 0.112125, 0.0206048, -0.0729856, -0.159243, -0.229502, -0.276703, -0.296104, -0.285756, -0.246698, -0.182855, -0.100641, -0.0083155, 0.0848453, 0.169482, 0.237091, 0.28088, 0.296449, 0.282234, 0.239664, 0.173015, 0.0889835, -0.00398808, -0.096559, -0.179429, -0.244271, -0.284573, -0.296283, -0.278227, -0.232217, -0.162877, -0.0771728, 0.0162848, 0.108106, 0.189066, 0.251031, 0.287776, 0.295607, 0.27374, 0.22437, 0.152458, 0.0652292, -0.0285535, -0.119467, -0.198379, -0.257359, -0.290483, -0.294422, -0.268782, -0.216137, -0.141777, -0.0531732]

    @test(length(ts_new) == (3 + 3 + 8) * 24)
    @test(timestamp(ts_new) == timestamp(ts)[1:(3 + 3 + 8) * 24])
    @test(colnames(ts_new) == colnames(ts))
    @test(values(ts_new)[1:3 * 24] == ts.values[1:3 * 24]) # Exactly equal, as these values should be copied.
    @test isapprox(values(ts_new), ts_ref, atol=1.e-4)
  end

  @testset "Volatility changing" begin
    timestamps = collect(DateTime(2017, 1, 1) : Hour(1) : DateTime(2017, 2, 1))
    ts_xs = 1:length(timestamps)
    ts_ys = sin.(ts_xs ./ pi)
    ts = TimeArray(timestamps, ts_ys)

    ts_new = changeVolatility(ts, 1.5)
    ts_ref = [0.408185, 0.830464, 1.16315, 1.37283, 1.43842, 1.35334, 1.12614, 0.779647, 0.348666, -0.123499, -0.589411, -1.00226, -1.32057, -1.51235, -1.55835, -1.45394, -1.2096, -0.849896, -0.410956, 0.0631181, 0.524696, 0.927405, 1.23078, 1.40435, 1.42495, 1.30138, 1.04033, 0.668029, 0.221885, -0.253281, -0.709731, -1.1016, -1.38953, -1.54458, -1.55119, -1.40867, -1.13136, -0.747111, -0.294531, 0.180909, 0.631444, 1.01181, 1.28379, 1.42006, 1.40693, 1.24571, 0.952614, 0.557078, 0.198563, -0.276332, -0.720176, -1.08838, -1.34394, -1.46119, -1.42835, -1.24871, -0.940335, -0.534192, -0.0710911, 0.402441, 0.83883, 1.19423, 1.43294, 1.53097, 1.47847, 1.28073, 0.957599, 0.541549, 0.0743791, -0.396975, -0.825156, -1.16715, -1.3404, -1.41904, -1.34698, -1.13146, -0.794141, -0.3689, 0.101533, 0.569896, 0.989133, 1.31712, 1.52091, 1.58003, 1.48854, 1.25562, 0.904683, 0.470985, -0.00190259, -0.466468, -0.876038, -1.18946, -1.37525, -1.41475, -1.30397, -1.05405, -0.76931, -0.327901, 0.146625, 0.606593, 1.00579, 1.30411, 1.47158, 1.49138, 1.36151, 1.09503, 0.718703, 0.270343, -0.205004, -0.659583, -1.04772, -1.33042, -1.47929, -1.47935, -1.33062, -1.04803, -0.659969, -0.205431, 0.26992, 0.718325, 1.01282, 1.27942, 1.40942, 1.38975, 1.22241, 0.924197, 0.525073, 0.0651397, -0.409395, -0.850855, -1.21489, -1.46492, -1.57583, -1.53647, -1.35081, -1.03748, -0.627984, -0.163447, 0.309454, 0.743209, 1.09424, 1.32727, 1.4189, 1.35992, 1.20057, 0.872683, 0.45351, -0.0148293, -0.485283, -0.910584, -1.248, -1.46364, -1.53583, -1.45733, -1.23601, -0.894112, -0.46599, 0.00534554, 0.472541, 0.888657, 1.21189, 1.40976, 1.46239, 1.36449, 1.1259, 0.770589, 0.334255, -0.139265, -0.501611, -0.907825, -1.21631, -1.39607, -1.42905, -1.31193, -1.05648, -0.688365, -0.24457, 0.230318, 0.68859, 1.0842, 1.37741, 1.53875, 1.55202, 1.41588, 1.14401, 0.763728, 0.313237, -0.162203, -0.614824, -0.999152, -1.27658, -1.41922, -1.41416, -1.25924, -0.97142, -0.579623, -0.123212, 0.351959, 0.798151, 1.17053, 1.4317, 1.5554, 1.52921, 1.35577, 1.0525, 0.649861, 0.188315, -0.285769, -0.724762, -1.08456, -1.32901, -1.43356, -1.38769, -1.19603, -0.877826, -0.465045, -0.100546, 0.371635, 0.802673, 1.14926, 1.37658, 1.46179, 1.39634, 1.18678, 0.854193, 0.431977, -0.037444, -0.506908, -0.929249, -1.26204, -1.47183, -1.53756, -1.45262, -1.22554, -0.879135, -0.448212, 0.0239372, 0.489876, 0.902793, 1.2212, 1.37135, 1.41748, 1.3132, 1.06898, 0.709367, 0.270479, -0.203585, -0.665196, -1.06798, -1.37146, -1.54516, -1.57161, -1.44818, -1.18724, -0.815028, -0.368931, 0.106231, 0.562719, 0.95467, 1.24271, 1.39789, 1.40462, 1.26224, 0.985038, 0.684473, 0.231935, -0.243506, -0.694085, -1.07453, -1.34662, -1.48302, -1.47003, -1.30894, -1.01595, -0.620491, -0.162292, 0.31261, 0.756503, 1.12479, 1.38047, 1.49785, 1.46515, 1.28564, 0.977361, 0.57129, 0.108219, -0.365325, -0.801768, -1.0799, -1.31872, -1.41689, -1.36453, -1.16691, -0.843877, -0.427893, 0.0392514, 0.510623, 0.938864, 1.28095, 1.50251, 1.58129, 1.50936, 1.29397, 0.95674, 0.531561, 0.0611471, -0.407239, -0.826541, -1.15463, -1.35854, -1.4178, -1.32643, -1.1443, -0.793454, -0.359811, 0.113062, 0.577657, 0.987296, 1.30082, 1.48674, 1.52637, 1.41572, 1.16592, 0.802067, 0.360709, -0.113809, -0.573812, -0.973083, -1.27151, -1.43911, -1.45904, -1.32931, -1.06294, -0.686694, -0.238379, 0.236966, 0.592651, 0.980867, 1.26368, 1.41267, 1.41288, 1.26427, 0.98179, 0.593809, 0.139311, -0.336042, -0.784493, -1.16099, -1.42769, -1.55782, -1.5383, -1.37108, -1.07298, -0.673926, -0.214027, 0.260516, 0.702027, 1.06615, 1.31629, 1.42734, 1.39665, 1.21111, 0.897891, 0.48846, 0.0239523, -0.448963, -0.882773, -1.23389, -1.46705, -1.55881, -1.49996, -1.29642, -0.968627, -0.549519, -0.0812034, 0.38927, 0.814632, 1.15215, 1.36791, 1.44024, 1.36186, 1.14066, 0.798863, 0.3708, 0.0020497, -0.465171, -0.881353, -1.20468, -1.40268, -1.45544, -1.35768, -1.11921, -0.763987, -0.327707, 0.145801, 0.608964, 1.01525, 1.32384, 1.50372, 1.53684, 1.41985, 1.16452, 0.796489, 0.352743, -0.12214, -0.580447, -0.976134, -1.26945, -1.39578, -1.40918, -1.27318, -1.00142, -0.621218, -0.170771, 0.304668, 0.75733, 1.14174, 1.41927, 1.56205, 1.55572, 1.40092, 1.11321, 0.721495, 0.265122, -0.210054, -0.656292, -1.02876, -1.29004, -1.41387, -1.38782, -1.21451, -0.911337, -0.596379, -0.134866, 0.339229, 0.778274, 1.13816, 1.38273, 1.48741, 1.44168, 1.25014, 0.93204, 0.519326, 0.0534687, -0.418728, -0.849824, -1.19651, -1.42395, -1.50929, -1.44397, -1.23454, -0.902046, -0.479893, -0.0104932, 0.458993, 0.881396, 1.14184, 1.35176, 1.41762, 1.33281, 1.10585, 0.759542, 0.328677, -0.143456, -0.609422, -1.02241, -1.34092, -1.53295, -1.57922, -1.47507, -1.23097, -0.871445, -0.432609, 0.0414438, 0.503087, 0.905941, 1.20953, 1.38335, 1.40995, 1.28664, 1.08258, 0.71045, 0.2644, -0.210757, -0.667283, -1.05931, -1.34746, -1.50277, -1.50964, -1.36738, -1.09029, -0.706207, -0.253711, 0.221731, 0.672353, 1.05288, 1.32508, 1.46162, 1.44876, 1.2878, 0.994916, 0.599531, 0.141369, -0.33354, -0.680871, -1.04924, -1.30504, -1.42255, -1.38998, -1.2106, -0.90243, -0.496429, -0.0333894, 0.440167, 0.876664, 1.23225, 1.47119, 1.56949, 1.51726, 1.31977, 0.996836, 0.580919, 0.1138, -0.35759, -0.78589, -1.12807, -1.34975, -1.42866, -1.3725, -1.15722, -0.820091, -0.394973, 0.0754212, 0.543831, 0.963197, 1.29138, 1.49542, 1.55481, 1.46358, 1.2309, 0.880151, 0.446564, -0.0262948, -0.490919, -0.900627, -1.21426, -1.4003, -1.44006, -1.32955, -1.07987, -0.716099, -0.274791, 0.0964561, 0.556493, 0.955839, 1.25437, 1.4221, 1.44217, 1.31256, 1.04631, 0.670147, 0.221878, -0.253464, -0.708123, -1.09642, -1.37934, -1.52846, -1.5288, -1.38033, -1.09795, -0.710054, -0.255595, 0.219761, 0.668257, 1.04483, 1.31165, 1.41357, 1.39418, 1.22709, 0.92909, 0.530115, 0.0702504, -0.404301, -0.845862, -1.21007, -1.46033, -1.57151, -1.53242, -1.34701, -1.03389, -0.624531, -0.160052, 0.312877, 0.746743, 1.09796, 1.33123, 1.42313, 1.36441, 1.16099, 0.8333, 0.505448, 0.037155, -0.433338, -0.858761, -1.19637, -1.41225, -1.48472, -1.40648, -1.1854, -0.843694, -0.415691, 0.0556091, 0.522855, 0.939103, 1.26253, 1.46065, 1.51355, 1.41592, 1.17757, 0.822439, 0.386213, -0.0872828, -0.550476, -0.956832, -1.19835, -1.37836, -1.41161, -1.29475, -1.03954, -0.671595, -0.227898, 0.246978, 0.705322, 1.10108, 1.39451, 1.5561, 1.56964, 1.43377, 1.16212, 0.782004, 0.3316, -0.143837, -0.596542, -0.981031, -1.25868, -1.40158, -1.39539, -1.24072, -1.01571, -0.624067, -0.167732, 0.307449, 0.753734, 1.12629, 1.38768, 1.51164, 1.48573, 1.31254, 1.00948, 0.606987, 0.145507, -0.328598, -0.767696, -1.12767, -1.37236, -1.47717, -1.43158, -1.24017, -0.922162, -0.509516, -0.0436865, 0.428526, 0.765853, 1.11263, 1.34019, 1.42567, 1.36048, 1.15117, 0.818777, 0.396686, -0.0726913, -0.542199, -0.964665, -1.29765, -1.50769, -1.57369, -1.48901, -1.26217, -0.915955, -0.485147, -0.0130306, 0.452963, 0.866014, 1.18463, 1.37679, 1.42319, 1.34181, 1.09783, 0.73839, 0.299607, -0.174436, -0.636112, -1.03904, -1.34273, -1.51668, -1.54341, -1.42024, -1.15953, -0.787487, -0.341484, 0.133668, 0.590232, 0.982337, 1.27059, 1.42603, 1.43304, 1.29092, 1.01394, 0.629929, 0.177475, -0.194503, -0.645168, -1.02578, -1.29809, -1.43475, -1.42203, -1.2612, -0.968427, -0.573119, -0.114993, 0.359922, 0.803912, 1.17237, 1.42828, 1.54593, 1.51349, 1.33424, 1.02617, 0.620241, 0.157232, -0.316337, -0.752888, -1.10856, -1.34762, -0.998781]

    @test(length(ts_new) == length(ts))
    @test(timestamp(ts_new) == timestamp(ts))
    @test(colnames(ts_new) == colnames(ts))
    @test isapprox(values(ts_new), ts_ref, atol=1.e-4)
  end

  @testset "Objective shortcut" begin
    date = DateTime(2017, January, 1, 6)
    t = Timing(timeBeginning=date, timeHorizon=Week(4), timeStepDuration=Hour(1))

    epDates = collect(date:Hour(1):date + Week(52))
    epRaw = 50 + 20 * sin.(1:length(epDates))
    ep = TimeArray(epDates, epRaw)

    eo = EnergyObjective(ep, t)

    @test(values(electricityPrice(smooth(eo, 3, 3, 8))) == values(smooth(ep, 3, 3, 8)))
    @test(values(electricityPrice(changeVolatility(eo, 1.15))) == values(changeVolatility(ep, 1.15)))
  end

  @testset "Shift agregation" begin
    @testset "No flexibility" begin
      date = DateTime(2017, 01, 01, 08)
      t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
      s = Shifts(t, date, Hour(8))
      solver = CbcSolver(logLevel=0)

      # No shift shall be output. 
      shifts = Bool[false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 0
      
      # Only one shift (tenth index). 
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 1
      @test agregated[1][1] == date + Hour(8 * (10 - 1))
      @test agregated[1][2] == Hour(8)
      @test agregated[1][3] == 1
      
      # Two consecutive shifts: both are longer than the maximum allowed shift length (which is fixed). 
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 2
      @test agregated[1][1] == date + Hour(8 * (10 - 1))
      @test agregated[1][2] == Hour(8)
      @test agregated[1][3] == 1
      @test agregated[2][1] == date + Hour(8 * (11 - 1))
      @test agregated[2][2] == Hour(8)
      @test agregated[2][3] == 1
      
      # Three shifts.  
      shifts = Bool[false, false, true, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 3
      @test agregated[1][1] == date + Hour(8 * (3 - 1))
      @test agregated[1][2] == Hour(8)
      @test agregated[1][3] == 1
      @test agregated[2][1] == date + Hour(8 * (10 - 1))
      @test agregated[2][2] == Hour(8)
      @test agregated[2][3] == 1
      @test agregated[3][1] == date + Hour(8 * (11 - 1))
      @test agregated[3][2] == Hour(8)
      @test agregated[3][3] == 1
    end

    @testset "HR flexibility" begin
      date = DateTime(2017, 01, 01, 08)
      t = Timing(timeBeginning=date, timeHorizon=Week(5), timeStepDuration=Hour(1))
      s = Shifts(t, date, Hour(2) : Hour(2) : Hour(8))
      solver = CbcSolver(logLevel=0)

      # No shift shall be output. 
      shifts = Bool[false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 0
      
      # One single shift (tenth index). Minimum shift length! 
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 1
      @test agregated[1][1] == date + Hour(2 * (10 - 1))
      @test agregated[1][2] == Hour(2)
      @test agregated[1][3] == 1
      
      # Two consecutive shifts (starting at tenth index). 
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 1
      @test agregated[1][1] == date + Hour(2 * (10 - 1))
      @test agregated[1][2] == Hour(4)
      @test agregated[1][3] == 1
      
      # Three consecutive shifts (starting at tenth index). 
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 1
      @test agregated[1][1] == date + Hour(2 * (10 - 1))
      @test agregated[1][2] == Hour(6)
      @test agregated[1][3] == 1
      
      # Four consecutive shifts (starting at tenth index). Maximum shift length!
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 1
      @test agregated[1][1] == date + Hour(2 * (10 - 1))
      @test agregated[1][2] == Hour(8)
      @test agregated[1][3] == 1
      
      # Five consecutive shifts (starting at tenth index). Over the maximum shift length.
      # Two acceptable scenarios: first 4h then 6h or the reverse (in order to minimise the differences between the shifts, base axiom of shiftsAgregation).
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 2
      if agregated[1][2] == Hour(4)
        @test agregated[1][1] == date + Hour(2 * (10 - 1))
        @test agregated[1][2] == Hour(4)
        @test agregated[1][3] == 1
        @test agregated[2][1] == date + Hour(2 * (10 - 1) + 4)
        @test agregated[2][2] == Hour(6)
        @test agregated[2][3] == 1
      else
        @test agregated[1][1] == date + Hour(2 * (10 - 1))
        @test agregated[1][2] == Hour(6)
        @test agregated[1][3] == 1
        @test agregated[2][1] == date + Hour(2 * (10 - 1) + 6)
        @test agregated[2][2] == Hour(4)
        @test agregated[2][3] == 1
      end
      
      # Six consecutive shifts (starting at tenth index). Over the maximum shift length.
      shifts = Bool[false, false, false, false, false, false, false, false, false, true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
      agregated = shiftsAgregation(shifts, t, s, solver)
      @test length(agregated) == 2
      @test agregated[1][1] == date + Hour(2 * (10 - 1))
      @test agregated[1][2] == Hour(6)
      @test agregated[1][3] == 1
      @test agregated[2][1] == date + Hour(2 * (10 - 1) + 6)
      @test agregated[2][2] == Hour(6)
      @test agregated[2][3] == 1
    end
  end
end
