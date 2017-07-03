## TODO: Group "utils"

## TODO: Subgroup "price"
# Test the smoothing.
timestamps = collect(DateTime(2017, 1, 1) : Hour(1) : DateTime(2017, 2, 1))
ts_xs = 1:length(timestamps)
ts_ys = sin(2 * pi .* ts_xs)
ts = TimeArray(timestamps, ts_ys)

ts_new = smooth(ts, 3, 3, 8)
@test(length(ts_new) == (3 + 3 + 8) * 24)
@test(timestamp(ts_new) == timestamp(ts)[1:(3 + 3 + 8) * 24])
@test(colnames(ts_new) == colnames(ts))
@test(ts_new.values[1:3 * 24] == ts.values[1:3 * 24]) # Exactly equal, as these values should be copied.
@test ts_new.values ≈ [-2.4492935982947064e-16,-4.898587196589413e-16,-7.347880794884119e-16,-9.797174393178826e-16,-1.2246467991473533e-15,-1.4695761589768238e-15,-1.7145055188062944e-15,-1.959434878635765e-15,-2.204364238465236e-15,-2.4492935982947065e-15,-9.799650315725178e-15,-2.9391523179536475e-15,3.921345679817883e-15,1.0781843677589415e-14,-1.0779367755043061e-14,-3.91886975727153e-15,2.941628240500001e-15,9.802126238271532e-15,-1.1759085194360944e-14,-4.898587196589413e-15,1.9619108011821185e-15,8.82240879895365e-15,-1.2738802633678827e-14,-5.878304635907295e-15,9.82193361864236e-16,7.842691359635767e-15,1.4703189357407298e-14,-6.858022075225178e-15,2.475922546353431e-18,6.8629739203178846e-15,-1.469823751231459e-14,-7.83773951454306e-15,-9.772415167715292e-16,5.883256481000002e-15,1.2743754478771533e-14,-8.817456953860943e-15,-1.9569589560894117e-15,4.90353904168212e-15,-1.6657672390950356e-14,-9.797174393178826e-15,-3.13583858258113e-14,-5.2919597258443776e-14,-1.763738983026824e-14,-3.919860126290071e-14,-6.075981269553319e-14,-2.5477605267357653e-14,-4.703881669999013e-14,-1.175660927181459e-14,-3.331782070444707e-14,-5.4879032137079545e-14,-1.9596824708904003e-14,-4.115803614153648e-14,-5.875828713360942e-15,-2.743704014599342e-14,-4.8998251578625895e-14,-1.3716044150450356e-14,-3.527725558308283e-14,-5.683846701571531e-14,-2.1556259587539768e-14,-4.3117471020172244e-14,-6.467868245280473e-14,-2.939647502462918e-14,-5.095768645726166e-14,-1.567547902908612e-14,-3.7236690461718594e-14,-5.879790189435108e-14,-2.3515694466175534e-14,-4.507690589880801e-14,-9.794698470632472e-15,-3.135590990326495e-14,-5.2917121335897426e-14,-1.7634913907721887e-14,-4.05028279132026e-14,-3.8379281487165065e-14,-4.099268663286154e-14,-4.360609177855801e-14,-4.621949692425448e-14,-4.409595049821695e-14,-4.197240407217942e-14,-3.98488576461419e-14,-4.246226279183837e-14,-4.507566793753484e-14,-4.768907308323131e-14,-4.556552665719378e-14,-4.344198023115625e-14,-4.605538537685271e-14,-4.866879052254918e-14,-5.128219566824566e-14,-4.442169767047413e-14,-4.70351028161706e-14,-4.9648507961867075e-14,-5.2261913107563544e-14,-5.487531825326001e-14,-4.801482025548848e-14,-4.115432225771695e-14,-4.3767727403413425e-14,-4.6381132549109893e-14,-4.899453769480636e-14,-4.2134039697034843e-14,-3.527354169926331e-14,-3.788694684495978e-14,-4.050035199065625e-14,-4.3113757136352724e-14,-4.5727162282049193e-14,-3.8866664284277655e-14,-4.1480069429974124e-14,-4.4093474575670606e-14,-4.670687972136707e-14,-4.9320284867063543e-14,-4.245978686929201e-14,-4.507319201498849e-14,-4.768659716068495e-14,-5.030000230638142e-14,-5.29134074520779e-14,-5.552681259777437e-14,-4.866631460000284e-14,-5.1279719745699306e-14,-5.389312489139577e-14,-5.6506530037092243e-14,-5.911993518278871e-14,-5.225943718501719e-14,-5.487284233071365e-14,-5.748624747641012e-14,-6.009965262210659e-14,-6.271305776780307e-14,-5.585255977003153e-14,-4.899206177226001e-14,-5.1605466917956474e-14,-5.421887206365295e-14,-5.6832277209349424e-14,-4.997177921157789e-14,-4.311128121380636e-14,-4.572468635950283e-14,-4.83380915051993e-14,-5.0951496650895774e-14,-5.356490179659226e-14,-4.670440379882072e-14,-4.93178089445172e-14,-5.193121409021367e-14,-5.454461923591014e-14,-5.71580243816066e-14,-5.029752638383508e-14,-5.291093152953155e-14,-5.5524336675228024e-14,-5.6064794993752055e-14,-5.683868856145503e-14,-5.761738096366962e-14,-5.843669625386531e-14,-5.932314244125035e-14,-6.028647006592486e-14,-6.131847153994187e-14,-6.239825580327599e-14,-6.350195436683246e-14,-6.461304518283098e-14,-6.572886133151497e-14,-6.685973715658395e-14,-6.801956524705756e-14,-6.920975679849142e-14,-7.040178157554944e-14,-7.15254707560879e-14,-7.247006146840628e-14,-7.310202273920726e-14,-7.32984003045368e-14,-7.298817835897102e-14,-7.218919896782586e-14,-7.10267850023754e-14,-6.972373170926533e-14,-6.855937538245103e-14,-6.780570436714655e-14,-6.765738265556115e-14,-6.817660840545738e-14,-6.927092399381848e-14,-7.071284196459625e-14,-7.219727462948708e-14,-7.342054374296744e-14,-7.415744236578592e-14,-7.431309842548246e-14,-7.393437381278722e-14,-7.317869072144163e-14,-7.225212383979026e-14,-7.133856887818016e-14,-7.054430651751444e-14,-6.987638174808533e-14,-6.92609175485168e-14,-6.859308810671815e-14,-6.779909542501955e-14,-6.688618996552941e-14,-6.59610948995976e-14,-6.520858904333049e-14,-6.483640528493755e-14,-6.500489395321543e-14,-6.576575867166428e-14,-6.703157142797486e-14,-6.858764851998165e-14,-7.014372561223358e-14,-7.140953836980789e-14,-7.217040309313399e-14,-7.233889177945737e-14,-7.19667080851466e-14,-7.121420244681508e-14,-7.028910809131881e-14,-6.937620485148578e-14,-6.858221881585771e-14,-6.791440844222666e-14,-6.72989966575273e-14,-6.663120990491598e-14,-6.583729560817778e-14,-6.49245811520072e-14,-6.399995723964814e-14,-6.324857254037026e-14,-6.287894515425434e-14,-6.305301298550088e-14,-6.382552820429715e-14,-6.511461214404446e-14,-6.671513621261177e-14,-6.835235444178177e-14,-6.975968357181026e-14,-7.07562094610021e-14,-7.129913580484746e-14,-7.14941110727444e-14,-7.15596824550909e-14,-7.175674347431649e-14,-7.23050597638962e-14,-7.331316305045398e-14,-7.474373550147058e-14,-7.642538803444832e-14,-7.810704056742604e-14,-7.953761301840786e-14,-8.054571630496562e-14,-8.109403259454532e-14,-8.129109361377094e-14,-8.135666499611741e-14,-8.155164026401438e-14,-8.209456660785973e-14,-8.30910924970516e-14,-8.449842162711487e-14,-8.613563985628486e-14,-8.773616392481736e-14,-8.902524786456466e-14,-8.979776308336092e-14,-8.997183091460748e-14,-8.960220352849158e-14,-8.88508188292137e-14,-8.792619491685464e-14,-8.701348046068406e-14,-8.621956616398064e-14,-8.555177941136933e-14,-8.493636762666997e-14,-8.426855725300414e-14,-8.347457121737606e-14,-8.256166797754304e-14,-8.163657362204675e-14,-8.088406798371523e-14,-8.051188428940448e-14,-8.068037297572784e-14,-8.144123769905394e-14,-8.270705045666304e-14,-8.426312754899139e-14,-8.58192046413197e-14,-8.708501739889402e-14,-8.784588212222012e-14,-8.801437080854348e-14,-8.764218711423274e-14,-8.688968147590121e-14,-8.596458712040492e-14,-8.505168388057189e-14,-8.425769784494381e-14,-8.358988747131277e-14,-8.297447568661342e-14,-8.230668893400208e-14,-8.151277463726389e-14,-8.060006018109333e-14,-7.967543626873426e-14,-7.89240515694564e-14,-7.855442418334047e-14,-7.872849201458703e-14,-7.950100723338325e-14,-8.079009117313058e-14,-8.239061524169788e-14,-8.402783347086788e-14,-8.543516260089638e-14,-8.643168849008821e-14,-8.697461483393357e-14,-8.716959010183053e-14,-8.7235161484177e-14,-8.743222250340262e-14,-8.798053879298233e-14,-8.89886420795401e-14,-9.041921453055672e-14,-9.210086706353444e-14,-9.378251959651218e-14,-9.521309204749396e-14,-9.622119533401696e-14,-9.67695116234787e-14,-9.696657264217916e-14,-9.703214402245368e-14,-9.722711928236265e-14,-9.777004559674919e-14,-9.876657138188856e-14,-1.0017390015937013e-13,-1.0181111724289918e-13,-1.0341163774132171e-13,-1.0470071101115236e-13,-1.0547319564513274e-13,-1.0564717938817021e-13,-1.0527733024597998e-13,-1.0452538455098665e-13,-1.0359939910720324e-13,-1.0268351413756376e-13,-1.018825150650693e-13,-1.0119953365387936e-13,-1.0055283854327824e-13,-9.982318409817607e-14,-9.891177003854532e-14,-9.778463676709953e-14,-9.648388465103661e-14,-9.509794956963943e-14,-9.369820301911676e-14,-9.22621593894561e-14,-9.061005906804857e-14,-8.837929837759353e-14,-8.5050814119326e-14,-8.002647526831017e-14,-7.274160958426209e-14,-6.278661748009712e-14,-5.000909009938861e-14,-3.4573237557789803e-14,-1.6964492470341572e-14,2.0599306362687907e-15,2.1562838515632322e-14,4.054317952680901e-14,5.80570727222689e-14,7.332664953038309e-14,8.582352777624967e-14,9.531766387193047e-14,1.0188588114487443e-13]

# Test the volatility.
timestamps = collect(DateTime(2017, 1, 1) : Hour(1) : DateTime(2017, 2, 1))
ts_xs = 1:length(timestamps)
ts_ys = sin(2 * pi .* ts_xs)
ts = TimeArray(timestamps, ts_ys)

ts_new = changeVolatility(ts, 1.5)
@test(length(ts_new) == length(ts))
@test(timestamp(ts_new) == timestamp(ts))
@test(colnames(ts_new) == colnames(ts))
@test ts_new.values ≈ [4.2326577610654746e-16,5.587173636234182e-17,-3.115223033818642e-16,-6.789163431260703e-16,-1.0463103828702763e-15,-1.413704422614482e-15,-1.781098462358688e-15,-2.148492502102894e-15,-2.5158865418471002e-15,-2.8832805815913065e-15,-1.3908815657737015e-14,-3.618068661079717e-15,6.6726783355775784e-15,1.6963425332234876e-14,-1.5378391816713838e-14,-5.087644820056542e-15,5.203102176600755e-15,1.549384917325805e-14,-1.6847967975690663e-14,-6.557220979033366e-15,3.733526017623932e-15,1.4024273014281227e-14,-1.8317544134667488e-14,-8.026797138010189e-15,7.719607699084445e-15,1.8010354695741735e-14,2.8301101692399032e-14,-4.040715456549677e-15,6.25003154010762e-15,1.6540778536764913e-14,-1.5801038612183798e-14,-5.510291615526502e-15,4.7804553811307954e-15,1.507120237778809e-14,2.536194937444539e-14,-6.979867774503326e-15,3.3108792221539705e-15,1.3601626218811271e-14,-1.8740190930137444e-14,-8.44944393348015e-15,-4.079126108242886e-14,-7.313307823137757e-14,-2.0209767089114272e-14,-5.255158423806298e-14,-8.48934013870117e-14,-3.197009024474839e-14,-6.431190739369711e-14,-1.1388596251433797e-14,-3.250159583189436e-14,-6.484341298084308e-14,-1.1920101838579762e-14,-4.426191898752848e-14,8.661392154734826e-15,-2.3680424994213887e-14,-5.60222421431626e-14,-3.0989310008992926e-15,-3.5440748149848006e-14,-6.778256529879672e-14,-1.4859254156533412e-14,-4.7201071305482126e-14,-7.954288845443085e-14,-2.661957731216753e-14,-5.896139446111624e-14,-6.0380833188529425e-15,-3.837990046780165e-14,-7.072171761675038e-14,-1.7798406474487062e-14,-5.014022362343578e-14,2.783087518827533e-15,-2.955872963012119e-14,-6.19005467790699e-14,-8.977235636806589e-15,-3.601142468193466e-14,-6.835324183088337e-14,-1.5429930688620063e-14,-4.777174783756878e-14,-8.011356498651749e-14,-2.7190253844254182e-14,-5.95320709932029e-14,-6.608759850939594e-15,-3.89505769998883e-14,-7.129239414883702e-14,-1.0363421129778573e-13,3.45542281356896e-14,2.212410986740888e-15,-3.012940616220784e-14,-6.247122331115655e-14,-9.481304046010525e-14,-1.2715485760905395e-13,1.1033581824421351e-14,-2.130823532452736e-14,-5.3650052473476077e-14,-8.599186962242478e-14,-1.183336867713735e-13,1.9854752662101827e-14,-1.2487064486846887e-14,-4.425820510370895e-14,-7.660002225265766e-14,-1.0894183940160638e-13,2.9246600031868953e-14,-3.0952171170797667e-15,-3.5437034266028474e-14,-6.777885141497719e-14,-1.001206685639259e-13,3.806777086954943e-14,5.725953720600709e-15,-2.6615863428348005e-14,-5.895768057729671e-14,-9.129949772624543e-14,-1.2364131487519414e-13,1.454712455828119e-14,-1.779469259066753e-14,-5.013650973961624e-14,-8.247832688856495e-14,-1.1482014403751366e-13,2.3368295395961666e-14,-8.97352175298706e-15,-4.131533890193577e-14,-7.365715605088448e-14,-1.0599897319983319e-13,-1.3540163803082826e-13,2.7868014026470654e-15,-2.9555015746301655e-14,-6.189683289525036e-14,-9.423865004419907e-14,-1.2658046719314778e-13,1.1607972240327535e-14,-2.073384490862118e-14,-5.307566205756989e-14,-8.54174792065186e-14,-1.1775929635546733e-13,2.042914307800801e-14,-1.1912674070940704e-14,-4.425449121988942e-14,-7.659630836883814e-14,-1.0893812551778686e-13,2.9250313915688486e-14,-3.0915032332602407e-15,-3.543332038220894e-14,-6.777513753115767e-14,-1.0011695468010638e-13,-1.324587718290551e-13,5.729667604420235e-15,-2.661214954452848e-14,-5.1277862803789546e-14,-8.361967995273825e-14,-1.1596149710168697e-13,2.222694233178835e-14,-1.0114874817160363e-14,-4.245669196610907e-14,-7.479850911505778e-14,-1.0714032626400649e-13,-1.394821434129552e-13,-1.2937039794798872e-15,-3.3635521128428595e-14,-6.59773382773773e-14,-9.831915542632602e-14,-1.3066097257527476e-13,7.527466858200588e-15,-2.4814350290748125e-14,-5.715616743969683e-14,-8.949798458864554e-14,-1.2183980173759425e-13,-1.54181618886543e-13,-1.8652343603549168e-13,-2.1886525318444042e-13,8.985344283145894e-14,5.751162568251025e-14,2.3372009279781173e-14,-8.969807869167528e-15,-4.131162501811624e-14,-7.365344216706497e-14,-1.0599525931601368e-13,-1.3833707646496238e-13,-1.7067889361391107e-13,-2.030207107628598e-13,-2.3536252791180855e-13,7.335616810409084e-14,4.1014350955142125e-14,8.67253380619341e-15,-2.3669283342755303e-14,-5.601110049170402e-14,-8.835291764065273e-14,-1.2069473478960143e-13,-1.5303655193855012e-13,-1.8537836908749886e-13,-2.177201862364476e-13,9.099850977945179e-14,5.865669263050308e-14,2.6314875481554362e-14,-6.026941667394352e-15,-3.8368758816343066e-14,-6.777142364733812e-14,-1.0011324079628684e-13,-1.3245505794523555e-13,-1.647968750941843e-13,-1.97138692243133e-13,-2.2948050939208174e-13,7.923818662381766e-14,4.689636947486897e-14,1.4554552325920243e-14,-1.778726482302847e-14,-5.0129081971977185e-14,-8.247089912092589e-14,-1.1481271626987463e-13,-1.4715453341882334e-13,-1.7949635056777205e-13,-2.1183816771672077e-13,9.688052829917861e-14,6.45387111502299e-14,3.219689400128118e-14,-1.4492314766753258e-16,-3.2486740296616234e-14,-6.482855744556496e-14,-9.717037459451367e-14,-1.295121917434624e-13,-1.5417790500272347e-13,-1.8651972215167216e-13,-2.188615393006209e-13,8.985715671527851e-14,5.751533956632977e-14,2.517352241738106e-14,-7.168294731567655e-15,-3.951011188051636e-14,-7.185192902946507e-14,-1.0419374617841378e-13,-1.365355633273625e-13,-1.688773804763112e-13,-2.0121919762525995e-13,-2.3356101477420864e-13,7.515768124169072e-14,4.281586409274201e-14,1.0474046943793296e-14,-2.1867770205155417e-14,-5.4209587354104125e-14,-8.655140450305283e-14,-1.1889322165200155e-13,-1.5123503880095026e-13,-1.83576855949899e-13,-2.159186730988477e-13,-2.5005828950157677e-13,5.86604065143226e-14,2.631858936537388e-14,-6.02322778357482e-15,-3.8365044932523534e-14,-7.070686208147226e-14,-1.0304867923042097e-13,-1.3539049637936967e-13,-1.677323135283184e-13,-2.0007413067726708e-13,-2.324159478262158e-13,7.630274818968355e-14,4.396093104073483e-14,1.1619113891786119e-14,-2.0722703257162595e-14,-5.306452040611131e-14,-8.540633755506002e-14,-1.1774815470400875e-13,-1.5008997185295744e-13,-1.8243178900190613e-13,-2.1477360615085492e-13,-2.471154232998036e-13,6.160327271609578e-14,2.926145556714707e-14,-4.878160835581985e-15,-3.72199779845307e-14,-6.956179513347941e-14,-1.0190361228242813e-13,-1.3424542943137685e-13,-1.6658724658032557e-13,-1.989290637292743e-13,-2.31270880878223e-13,7.74478151376764e-14,4.510599798872768e-14,1.2764180839778966e-14,-1.957763630916976e-14,-5.191945345811846e-14,-8.426127060706718e-14,-1.1660308775601588e-13,-1.4894490490496462e-13,-1.8128672205391335e-13,-2.1362853920286204e-13,-2.459703563518108e-13,6.27483396640886e-14,3.040652251513989e-14,-1.9352946338088215e-15,-3.427711178275752e-14,-6.661892893170624e-14,-8.654769061923334e-14,-1.1888950776818205e-13,-1.5123132491713077e-13,-1.8357314206607948e-13,-2.1591495921502817e-13,-2.482567763639769e-13,6.046191965192248e-14,2.8120102502973767e-14,-4.2217146459749466e-15,-3.656353179492366e-14,-6.890534894387239e-14,-1.012471660928211e-13,-1.3358898324176981e-13,-1.6593080039071853e-13,-1.9827261753966722e-13,-2.3061443468861596e-13,-2.6295625183756464e-13,4.576244417833472e-14,1.3420627029386005e-14,-1.8921190119562722e-14,-5.126300726851143e-14,-8.360482441746015e-14,-1.1594664156640886e-13,-1.4828845871535758e-13,-2.2032368769195863e-13,-2.5266550484090737e-13,-2.8500732198985606e-13,2.371137402604331e-14,-8.630443122905409e-15,-4.0972260271854126e-14,-7.331407742080283e-14,-1.0565589456975157e-13,-1.3799771171870028e-13,-1.7033952886764897e-13,-2.0268134601659768e-13,-2.350231631655464e-13,-2.673649803144951e-13,-2.9970679746344385e-13,9.011898552455536e-15,3.1773059456835495e-13,-5.567173574544189e-14,2.5304696027045747e-13,-1.2035537004333933e-13,1.8836332597256007e-13,4.970820219884594e-13,1.2367969167466262e-13,4.32398387690562e-13,5.899605737676519e-14,3.0433658370634225e-13,-6.906574660745461e-14,2.3965294940844477e-13,-1.3374938090535205e-13,1.7496931511054735e-13,-1.9843301520324948e-13,1.1028568081264992e-13,4.190043768285493e-13,4.560204651475249e-14,3.543207425306519e-13,-1.9081587783144924e-14,2.8963710823275446e-13,-8.376522208104235e-14,2.2495347393485699e-13,-1.484488563789398e-13,1.6026983963695956e-13,-2.1313249067683722e-13,9.558620533906213e-14,4.0430490135496153e-13,3.0902571041164716e-14,3.3962126705706415e-13,-3.378106325673271e-14,2.7493763275916663e-13,-9.846469755463014e-14,2.0371924763575487e-13,-1.6968308267804193e-13,1.3903561333785745e-13,4.477543093537569e-13,7.435197903996002e-14,3.830706750558594e-13,9.66834474206259e-15,3.1838704075796204e-13,-5.501528955583484e-14,2.5370340646006456e-13,-1.1969892385373224e-13,1.890197721621671e-13,-1.8438255815162972e-13,1.2433613786426968e-13,4.33054833880169e-13,5.965250356637225e-14,3.6837119958227163e-13,-5.031130731525173e-15,3.0368756528437415e-13,-6.97147650294226e-14,2.390039309864768e-13,-1.3439839932732003e-13,1.7432029668857935e-13,-1.9908203362521746e-13,1.1257581470863556e-13,4.212945107245349e-13,4.789218041073815e-14,3.566108764266375e-13,-1.6791453887159304e-14,2.9192724212874006e-13,-8.147508818505673e-14,2.2724360783084268e-13,-1.461587224829542e-13,1.6255997353294523e-13,-2.1084235678085157e-13,9.787633923504779e-14,4.0659503525094713e-13,3.319270493715036e-14,3.4191140095304975e-13,-3.149092936074707e-14,2.772277666551523e-13,-9.61745636586445e-14,2.125441323572549e-13,-1.6085819795654193e-13,1.4786049805935747e-13,-2.2554183225443936e-13,8.317686376146003e-14,3.918955597773594e-13,1.1958478638048235e-14,3.206771746539476e-13,-5.272515565984922e-14,2.559935403560502e-13,-1.174087899577466e-13,1.9130990605815273e-13,-1.8209242425564402e-13,1.266262717602553e-13,4.3534496777615465e-13,6.19426374623579e-14,3.706613334782573e-13,-2.740996835539528e-15,3.059776991803598e-13,-6.742463113343696e-14,2.412940648824624e-13,-1.3210826543133438e-13,1.76610430584565e-13,-1.967918997292318e-13,1.1192679628666755e-13,4.2064549230256697e-13,4.7243161988770124e-14,3.559618580046695e-13,-1.7440472309127316e-14,2.912782237067721e-13,-6.971105114560308e-14,2.390076448702963e-13,-1.3439468544350048e-13,1.7432401057239887e-13,-1.9907831974139796e-13,1.0964037627450144e-13,4.1835907229040084e-13,4.495674197660401e-14,3.5367543799250336e-13,-1.9726892321293416e-14,2.8899180369460593e-13,-8.441052661919084e-14,2.2430816939670853e-13,-1.4909416091708827e-13,1.596245350988111e-13,-2.137777952149857e-13,9.494090080091368e-14,4.0365959681681305e-13,3.025726650301625e-14,3.389759625189156e-13,-3.442636779488118e-14,2.742923282210182e-13,-9.91100020927786e-14,2.0960869392312077e-13,-1.5138058092925437e-13,1.57338115086645e-13,-2.160642152271518e-13,9.265448078874756e-14,4.0137317680464693e-13,2.7970846490850124e-14,3.3668954250674955e-13,-3.671278780704729e-14,2.7200590820885207e-13,-1.0139642210494473e-13,2.0732227391095467e-13,-1.660800564028422e-13,1.4263863961305722e-13,-2.3076369070073956e-13,7.795500531515979e-14,3.8667370133105914e-13,1.3271371017262362e-14,3.2199006703316176e-13,-5.1412263280635066e-14,2.573064327352643e-13,-1.1609589757853252e-13,1.9262279843736688e-13,-1.8077953187642995e-13,1.2793916413946945e-13,-2.519979169998417e-13,5.672077901605766e-14,3.654394750319571e-13,-7.962855281839777e-15,3.0075584073405965e-13,-7.26464895797372e-14,2.3607220643616217e-13,-1.373301238776346e-13,1.7138857213826474e-13,-2.0201375817553203e-13,1.0670493784036732e-13,4.154236338562667e-13,4.2021303542469894e-14,3.507399995583693e-13,-2.266233075542754e-14,2.860563652604718e-13,-8.734596505332497e-14,2.2137273096257438e-13,-1.5202959935122234e-13,1.5668909666467696e-13,-2.1671323364911982e-13,9.200546236677955e-14,4.00724158382679e-13,2.7321828068882125e-14,3.389796764027352e-13,-3.4422653911061646e-14,2.742960421048377e-13,-9.910628820895905e-14,2.096124078069403e-13,-1.6378992250685654e-13,1.4492877350904286e-13,-2.2847355680475397e-13,8.024513921114543e-14,3.889638352270449e-13,1.556150491324802e-14,3.242802009291474e-13,-4.912212938464941e-14,2.5959656663124993e-13,-1.1380576368254685e-13,1.9491293233335255e-13,-1.7848939798044433e-13,1.302292980354551e-13,-2.431730322783417e-13,6.554566373755767e-14,3.74264359753457e-13,8.620294396602562e-16,3.095807254555596e-13,-6.382160485823717e-14,2.4783624347561583e-13,-1.25566086838181e-13,1.831526091777184e-13,-1.9024972113607842e-13,1.1846897487982098e-13,-2.5493335543397585e-13,5.378534058192356e-14,3.625040365978229e-13,-1.0898293715973888e-14,2.9782040229992547e-13,-7.558192801387132e-14,2.331367680020281e-13,-1.4026556231176873e-13,1.6845313370413067e-13,-2.0494919660966616e-13,1.037694994062332e-13,4.1248819542213254e-13,3.908586510833579e-14,3.4780456112423516e-13,-2.559776918956165e-14,2.8312092682633774e-13,-9.028140348745908e-14,2.184372925284403e-13,-1.5496503778535652e-13,1.5669281054849653e-13,-2.1670951976530025e-13,9.20091762505991e-14,4.0072787226649845e-13,2.7325541952701664e-14,3.36044237968601e-13,-3.735809234519576e-14,2.713606036707036e-13,-1.0204172664309321e-13,2.0667696937280617e-13,-1.667253609409906e-13,1.4199333507490874e-13,-2.314089952388881e-13,7.730970077701134e-14,3.860283967929107e-13,1.2626066479113895e-14,3.2134476249501323e-13,-5.205756781878352e-14,2.5666112819711586e-13,-1.1674120211668097e-13,1.919774938992184e-13,-1.814248364145784e-13,1.27293859601321e-13,-2.4610847071247583e-13,6.554937762137719e-14,3.7426807363727657e-13,8.657433234797758e-16,3.0958443933937914e-13,-6.381789097441766e-14,2.449008050414817e-13,-1.285015252723151e-13,1.8021717074358428e-13,-1.9318515957021254e-13,1.1553353644568686e-13,-2.578687938681099e-13,5.084990214778943e-14,3.595685981636888e-13,-1.3833732150108e-14,2.948849638657914e-13,-7.851736644800543e-14,2.302013295678939e-13,-1.4320100074590285e-13,1.6551769526999652e-13,-2.0788463504380028e-13,1.0083406097209909e-13,-2.725682693416977e-13,3.6150426674201665e-14,3.4486912269010104e-13,-2.5594055305742106e-14,2.8312464071015726e-13,-9.027768960363953e-14,2.1844100641225983e-13,-1.54961323901537e-13,1.537573721143624e-13,-2.1964495819943438e-13,8.907373781646497e-14,-2.8432859249733185e-13,2.4390103518567546e-14,3.3310879953446695e-13,-4.0293530779329894e-14,2.6842516523656947e-13,-1.0497716507722732e-13,2.037415309386721e-13,-1.6966079937512474e-13,1.3905789664077461e-13,-2.3434443367302216e-13,7.43742623428772e-14,3.830929583587766e-13,9.690628044979771e-15,3.1840932406087916e-13,-5.4993006252917657e-14,2.5372568976298173e-13,-1.1673748823286143e-13,1.9198120778303797e-13,-1.8142112253075886e-13,1.2729757348514052e-13,-2.461047568286563e-13,6.261393918724309e-14,3.713326352031425e-13,-2.0696951106543418e-15,3.06649000905245e-13,-6.675332940855176e-14,2.419653666073476e-13,-1.3143696370644922e-13,1.7728173230945016e-13,-1.9612059800434664e-13,1.1259809801155276e-13,-2.608042323022441e-13,4.7914463713655323e-14,3.566331597295547e-13,-1.6769170584242098e-14,2.9194952543165723e-13,-8.145280488213955e-14,2.2726589113375982e-13,-1.4613643918003698e-13,1.625822568358624e-13,1.0018851139783227e-14,3.1873754715568263e-13,-5.466478315811415e-14,-4.2806711347191093e-13,-8.014694437857078e-13,1.8937027855988787e-13,-1.8403205175390898e-13,-5.574343820677058e-13,-9.308367123815026e-13,6.000300996409297e-14,-3.1339932034970386e-13,-6.868016506635006e-13,-1.0602039809772975e-12,-6.936425863170194e-14,-4.427665889454987e-13,-8.161689192592955e-13,1.7467080308630009e-13,-1.9873152722749674e-13,-5.721338575412937e-13,-9.455361878550903e-13,4.530353449050513e-14,-3.2809879582329165e-13,-7.015011261370884e-13,-1.0749034564508853e-12,-6.217677550040004e-14,-4.355791058141968e-13,-8.089814361279936e-13,1.8185828621760188e-13,-1.915440440961949e-13,-5.649463744099917e-13,-9.383487047237886e-13,5.2491017621807125e-14,-3.2091131269198975e-13,-6.943136430057864e-13,-1.0677159733195833e-12,-7.687625097398773e-14,-4.502785812877846e-13,-8.236809116015814e-13,1.671588107440141e-13,-2.0624351956978269e-13,-5.796458498835795e-13,-9.530481801973761e-13,3.7791542148219337e-14,-3.3561078816557754e-13,-7.090131184793743e-13,-1.082415448793171e-12,-9.157572644757557e-14,-4.649780567613724e-13,-8.449151379006836e-13,1.4592458444491203e-13,-2.274777458688848e-13,-6.008800761826815e-13,-9.742824064964784e-13,1.6557315849117173e-14,-3.5684501446467966e-13,-7.302473447784764e-13,-1.1036496750922731e-12,-1.1280995274667763e-13,-4.862122830604745e-13,-8.596146133742712e-13,1.3122510897132424e-13,-2.4217722134247254e-13,-6.155795516562694e-13,-9.889818819700661e-13,1.857840375529385e-15,-3.715444899382674e-13,-7.449468202520642e-13,2.458929020935313e-13,-1.2750942822026547e-13,-5.009117585340622e-13,-8.74314088847859e-13,1.1652563349773655e-13,-2.634114476415747e-13,-6.368137779553715e-13,-1.0102161082691684e-12,-1.9376385923572728e-14,-3.9277871623736956e-13,-7.661810465511662e-13,2.246586757944292e-13,-1.4874365451936758e-13,-5.221459848331644e-13,-8.955483151469612e-13,9.529140719863434e-14,-2.7811092311516244e-13,-6.515132534289593e-13,-1.024915583742756e-12,-3.4075861397160516e-14,-4.074781917109573e-13,-7.80880522024754e-13,2.099592003208414e-13,-1.6344312999295537e-13,-5.368454603067521e-13,-9.10247790620549e-13,8.059193172504665e-14,-2.928103985887502e-13,-6.662127289025469e-13,-8.290662626146468e-13]
