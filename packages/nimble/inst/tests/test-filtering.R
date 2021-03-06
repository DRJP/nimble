source(system.file(file.path('tests', 'test_utils.R'), package = 'nimble'))
context("Testing of different Filtering Algorithms")

### particle filter testing follows similar steps to MCMC testing.
### for each example, we comapare filter output between R and C.  We also (where applicable) compare:
### 1) estimated values for latent states to true values for both weighted and equally weighted samples
### 2) estimated top level parameter values to known values (Liu-West filter, PMCMC)
### 3) estimated log-likelihood values to known values (for normal transition - observation
###    models where LL can be calculated analytically via KF)

RwarnLevel <- options('warn')$warn
options(warn = 1)
nimbleVerboseSetting <- nimbleOptions('verbose')
nimbleOptions(verbose = FALSE)

goldFileName <- 'filteringTestLog_Correct.Rout'
tempFileName <- 'filteringTestLog.Rout'
generatingGoldFile <- !is.null(nimbleOptions('generateGoldFileForFilteringTesting'))
outputFile <- if(generatingGoldFile) file.path(nimbleOptions('generateGoldFileForFilteringTesting'), goldFileName) else tempFileName

sink(outputFile)

nimbleProgressBarSetting <- nimbleOptions('MCMCprogressBar')
nimbleOptions(MCMCprogressBar = FALSE)

### basic scalar latent node example, no top-level params


code <- nimbleCode({
  x0 ~ dnorm(0,1)
  x[1] ~ dnorm(a + b*x0, 1)
  y[1] ~ dnorm(x[1], var = 2)
    for(i in 2:3) {
        x[i] ~ dnorm(a + b*x[i-1], 1)
        y[i] ~ dnorm(x[i], var = 2)
    }
})
testdata = list(y = c(0,1,2))
inits = list(x0 = 0, a = 0, b = 1)

### ll, means, vars calculated from FKF R packgae
ActualLL <- -5.08

test_filter(model = code, name = 'basic bootstrap, always resamp', data = testdata, filterType = "bootstrap", latentNodes = "x",
             filterControl = list(thresh = 1, saveAll = TRUE),
             inits = inits,
             results = list(mean = list(x = c(0,0.454,1.209)),
                            var = list(x = c(.667, .909, .977)),
                            ll = list(ActualLL)),
             resultsTolerance = list(mean = list(x = rep(.2,3)),
                                     var = list(x = rep(.2,3)),
                                     ll = list(2)))

test_filter(model = code, name = 'basic auxiliary', data = testdata, filterType = "auxiliary", latentNodes = "x",
             inits = inits,
             results = list(mean = list(x = c(0,0.454,1.209)),
                            var = list(x = c(.667, .909, .977)),
                            ll = list(ActualLL)),
             resultsTolerance = list(mean = list(x = rep(.2,3)),
                                     var = list(x = rep(.2,3)),
                                     ll = list(2)))

test_filter(model = code, name = 'basic auxiliary, saveAll = FALSE', data = testdata, filterType = "auxiliary", latentNodes = "x", filterControl = list(saveAll = FALSE), 
             inits = inits,
             results = list(mean = list(x = c(0,0.454,1.209)),
                            var = list(x = c(.667, .909, .977)),
                            ll = list(ActualLL)),
             resultsTolerance = list(mean = list(x = rep(.2,3)),
                                     var = list(x = rep(.2,3)),
                                     ll = list(2)))


test_filter(model = code, name = 'basic auxiliary w/ mean lookahead', data = testdata, filterType = "auxiliary",
             latentNodes = "x", filterControl = list(lookahead = "mean", saveAll = TRUE),
             inits = inits,
             results = list(mean = list(x = c(0,0.454,1.209)),
                            var = list(x = c(.667, .909, .977)),
                            ll = list(ActualLL)),
             resultsTolerance = list(mean = list(x = rep(.2,3)),
                                     var = list(x = rep(.2,3)),
                                     ll = list(2)))

test_filter(model = code, name = 'basic ensembleKF', data = testdata, filterType = "ensembleKF", latentNodes = "x",
             inits = inits,
             results = list(mean = list(x = c(0,0.454,1.209)),
                            var = list(x = c(.667, .909, .977))),
             resultsTolerance = list(mean = list(x = rep(.2,3)),
                                     var = list(x = rep(.2,3))))



### multivariate latent node and data node example, no top-level params

code <- nimbleCode({
  x[1,1:3] ~ dmnorm(x0[1:3], cov = xCov[1:3, 1:3])
  yMean[1,1:2] <- obsMat[1:2,1:3]%*%x[1,1:3]
  y[1,1:2] ~ dmnorm(yMean[1,1:2], cov = yCov[1:2,1:2])
  for(i in 2:3) {
    prevX[i,1:3] <- a[1:3] + b * x[i-1,1:3]
    x[i,1:3] ~ dmnorm(prevX[i,1:3] , cov = xCov[1:3, 1:3])
    yMean[i,1:2] <- obsMat[1:2,1:3]%*%x[i,1:3]
    y[i,1:2] ~  dmnorm(yMean[i,1:2], cov = yCov[1:2,1:2])
  }
})
testdata = list(y = matrix(c(0, 1,
                         1, 2,
                         2, 3), nrow = 3, byrow = TRUE),
            obsMat = matrix(c(1,0,0,
                           0,1,1), nrow = 2, byrow = TRUE),
              x0 = c(1,1,1),
              xCov = matrix(c(1,0,0,
                              0,2,1,
                              0,1,4), nrow = 3, byrow = TRUE),
              yCov = matrix(c(.5, .1,
                            .1, 1), nrow = 2, byrow = TRUE))

xFilter <- matrix(c(.323,1.02,1.03,
                       .819, .991, .985,
                       .946, 1.333, 1.556), nrow = 3, byrow = T)

xFilterTol <- matrix(1.2, nrow = 3, ncol = 3)

ActualLL <- -10.235


test_filter(model = code, name = 'multivariate bootstrap, always resamp', data = testdata, filterType = "bootstrap", latentNodes = "x", inits = list(a = rep(0,3), b = 1), 
             filterControl = list(thresh = 1, saveAll = TRUE, timeIndex = 1),
             results = list(mean = list(x = xFilter),
                            ll = list(ActualLL)),
             resultsTolerance = list(mean = list(x = xFilterTol),
                                      ll = list(2)))
test_filter(model = code, name = 'multivariate auxiliary', data = testdata, filterType = "auxiliary", latentNodes = "x", inits = list(a = rep(0,3), b = 1), 
             filterControl = list(saveAll = TRUE, timeIndex = 1),
             results = list(mean = list(x = xFilter),
                            ll = list(ActualLL)),
             resultsTolerance = list(mean = list(x = xFilterTol),
                                     ll = list(2)))

## On Windows the next test can create a DLL name conflict and look
## up the wrong C++ class, from a previous DLL.  Hence this will be the break
## into two windows test units
if(.Platform$OS.type == 'windows') {
    message("Stopping filtering test here on Windows to avoid multiple DLL problems. Run test-filtering2 to continue")
    stop()
}

test_filter(model = code, name = 'multivariate auxiliary mean lookahead', data = testdata, filterType = "auxiliary", latentNodes = "x", inits = list(a = rep(0,3), b = 1),
             filterControl = list(saveAll = TRUE, timeIndex = 1, lookahead = "mean"),
             results = list(mean = list(x = xFilter),
                            ll = list(ActualLL)),
             resultsTolerance = list(mean = list(x = xFilterTol),
                                     ll = list(2)))

test_filter(model = code, name = 'multivariate ensembleKF', data = testdata, filterType = "ensembleKF", latentNodes = "x", inits = list(a = rep(0,3), b = 1),
            filterControl = list(timeIndex = 1, saveAll = F),
            results = list(mean = list(x = xFilter[3,])),
            resultsTolerance = list(mean = list(x = xFilterTol[3,])))


### scalar latent node and data node example, two top-level params

code <- nimbleCode({
  x[1] ~ dnorm(mean = mu0, sd = sigma_x);
  y[1] ~ dnorm(x[1], sd=sigma_y);
  for(i in 2:N){
    x[i] ~ dnorm(mean = a + b*x[i-1], sd = sigma_x);
    y[i] ~ dnorm(mean = x[i], sd=sigma_y);
  }
  sigma_x ~ T(dnorm(1, sd = .5), 0,);
  sigma_y ~ T(dnorm(.1, sd = .5), 0,);
  mu0 <- 0
})

set.seed(0)

a <- 0
b <- 1
N <- 5
sigma_x <- 1
sigma_y <- .1
x <- rep(NA, N)
y <- x
x[1] <- rnorm(1,0,sigma_x)
y[1] <- rnorm(1,x[1], sigma_y)
for(i in 2:N){
  x[i] <- rnorm(1,a+b*x[i-1], sigma_x)
  y[i] <- rnorm(1,x[i], sigma_y)
}

consts <- list(N=N)

testdata <- list(y=y)

inits <- list(sigma_x=sigma_x, sigma_y=sigma_y, x = x, a = a, b = b)

##  this now fails with a+b*x offset because of issue #955
test_filter(model = code, name = 'scalar lwf', inits = inits, data = c(testdata, consts), filterType = "LiuWest", latentNodes = "x", results = list(
  mean = list(x = x,
              sigma_x = sigma_x,
              sigma_y = sigma_y)),
  resultsTolerance = list(mean = list(x = rep(1,N),
                                      sigma_x = .5,
                                      sigma_y = .5)))


test_mcmc(model = code, name = 'scalar pmcmc', inits = inits, data = c(testdata, consts),  samplers = list(
  list(type = 'RW_PF', target = 'sigma_x', control = list(latents = 'x', m = 1000)),
  list(type = 'RW_PF', target = 'sigma_y', control = list(latents = 'x', m = 1000))),
  removeAllDefaultSamplers = TRUE, numItsC = 1000, results = list(
  mean = list( sigma_x = sigma_x,
              sigma_y = sigma_y)),
  resultsTolerance = list(mean = list(sigma_x = .5,
                                      sigma_y = .5)))

test_mcmc(model = code, name = 'block pmcmc', inits = inits, data = c(testdata, consts),  samplers = list(
  list(type = 'RW_PF_block', target = c('sigma_x', 'sigma_y'), control = list(latents = 'x', m = 1000, resample = FALSE))),
  removeAllDefaultSamplers = TRUE, numItsC = 1000, results = list(
    mean = list(sigma_x = sigma_x,
                sigma_y = sigma_y)),
  resultsTolerance = list(mean = list(sigma_x = .5,
                                      sigma_y = .5)))
# , expectWarnings = list("C MCMC" = "NaNs produced"))

## Let's stop here to save testing time
## # test MCMC with longer runs and lower tolerance
## set.seed(0)
## N <- 50
## sigma_x <- 1
## sigma_y <- .1
## x <- rep(NA, N)
## y <- x
## x[1] <- rnorm(1,0,sigma_x)
## y[1] <- rnorm(1,x[1], sigma_y)
## for(i in 2:N){
##   x[i] <- rnorm(1,x[i-1], sigma_x)
##   y[i] <- rnorm(1,x[i], sigma_y)
## }

## consts <- list(N=N)

## testdata <- list(y=y)

## inits <- list(sigma_x=1, sigma_y=.1, x = x)

## test_mcmc(model = code, name = 'scalar pmcmc, more data', inits = inits, data = c(testdata, consts),  basic = FALSE, samplers = list(
##   list(type = 'RW_PF', target = 'sigma_x', control = list(latents = 'x', m = 1000, resample = FALSE)),
##   list(type = 'RW_PF', target = 'sigma_y', control = list(latents = 'x', m = 1000, resample = FALSE))),
##   removeAllDefaultSamplers = TRUE, numItsC = 1000, numItsC_results = 5000, results = list(
##   mean = list( sigma_x = sigma_x,
##               sigma_y = sigma_y)),
##   resultsTolerance = list(mean = list(sigma_x = .1,
##                                       sigma_y = .1)))

## test_mcmc(model = code, name = 'block pmcmc, more data', inits = inits, data = c(testdata, consts), basic = FALSE, samplers = list(
##   list(type = 'RW_PF_block', target = c('sigma_x', 'sigma_y'), control = list(latents = 'x', m = 1000, resample = FALSE))),
##   removeAllDefaultSamplers = TRUE, numItsC = 1000, numItsC_results = 5000, results = list(
##     mean = list(sigma_x = sigma_x,
##                 sigma_y = sigma_y)),
##   resultsTolerance = list(mean = list(sigma_x = .1,
##                                       sigma_y = .1)))

test_that("IF2", {
    Nile <- c(1120,1160,963,1210,1160,1160,813,1230,1370,1140,995,935,1110,994,1020,960,1180,799,958,1140,1100,1210,1150,1250,1260,1220,1030,1100,774,840,874,694,940,833,701,916,692,1020,1050,969,831,726,456,824,702,1120,1100,832,764,821,768,845,864,862,698,845,744,796,1040,759,781,865,845,944,984,897,822,1010,771,676,649,846,812,742,801,1040,860,874,848,890,744,749,838,1050,918,986,797,923,975,815,1020,906,901,1170,912,746,919,718,714,740)  # avoid FKF suggests dependency
    flowCode <- nimbleCode({
        for(t in 1:n)
            y[t] ~ dnorm(x[t], sd = sigmaMeasurements)
        x[1] ~ dnorm(x0, sd = sigmaInnovations)    
        for(t in 2:n)
            x[t] ~ dnorm((t-1==28)*meanShift1899 + x[t-1], sd = sigmaInnovations)
        logSigmaInnovations ~ dnorm(0, sd = 100)
        logSigmaMeasurements ~ dnorm(0, sd = 100)
        sigmaInnovations <- exp(logSigmaInnovations)
        sigmaMeasurements <- exp(logSigmaMeasurements)
        x0 ~ dnorm(1120, var = 100)
        meanShift1899 ~ dnorm(0, sd = 100)
    })
    
    flowModel <- nimbleModel(flowCode, data = list(y = Nile),
                             constants = list(n = length(Nile)),
                             inits = list(logSigmaInnovations = log(sd(Nile)),
                                          logSigmaMeasurements = log(sd(Nile)),
                                          meanShift1899 = -100))
    
    filter <- buildIteratedFilter2(model = flowModel,
                                   nodes = 'x',
                                   params = c('logSigmaInnovations',
                                              'logSigmaMeasurements',
                                              'meanShift1899'),
                                   baselineNode = 'x0',
                                   control = list(sigma = c(0.1, 0.1, 5),
                                                  initParamSigma = c(0.1, 0.1, 5)))
    cFlowModel <- compileNimble(flowModel)
    cFilter  <- compileNimble(filter, project = flowModel)
    
    set.seed(1)
    niter <- 100
    est <- cFilter$run(m = 1000, niter = niter, alpha = 0.2)

    ## Expect values similar to what obtained in version 0.9.0.
    expect_gt(cFilter$logLik[niter], -627.5, ) 
    expect_lt(exp(est[1]), 10)
    expect_equal(exp(est[2]), 126, tolerance = 10)
    expect_equal(est[3], -271, tolerance = 10)
})


test_that("Test findLatentNodes", {
    code <- nimbleCode({
        for(j in 1:p)
            x[j, 1] ~ dnorm(0,1)
        for(i in 2:n)
            for(j in 1:p)
                x[j,i] ~ dnorm(x[j,i-1], 1)
    })
    model <- nimbleModel(code,constants = list(n = 6, p = 4))
    expect_identical(findLatentNodes(model,'x'),
                     paste0('x[1:4, ', 1:6, ']'))
    expect_identical(findLatentNodes(model, 'x[2:3,3:5]'),
                     paste0('x[2:3, ', 3:5, ']'))
    expect_identical(findLatentNodes(model, 'x[,2:6]'),
                     paste0('x[1:4, ', 2:6, ']'))
    expect_identical(findLatentNodes(model, 'x[,2:4]'),
                     paste0('x[', 1:4, ', 2:4]'))

    expect_identical(findLatentNodes(model, c('x[1:3,1]', 'x[1:3,2]', 'x[1:3,3]', 'x[1:3,4]')),
                     paste0('x[1:3, ', 1:4, ']'))
    expect_identical(findLatentNodes(model, c('x[,1]', 'x[,2]', 'x[,3]', 'x[,4]', 'x[,5]')), 
                     paste0('x[1:4, ', 1:5, ']'))
    expect_identical(findLatentNodes(model, c('x[ ,1]', 'x[ ,2]', 'x[ ,3]', 'x[ ,4]', 'x[,5]')),
                     paste0('x[1:4, ', 1:5, ']'))
    expect_error(findLatentNodes(model, 'x[ ,1:4]'),
                 "unable to determine which dimension")

    code = nimbleCode({
        for(j in 1:p)
            x[j, 1, 3] ~ dnorm(0,1)
        for(i in 2:n)
            for(j in 1:p)
                x[j,i, 3] ~ dnorm(x[j,i-1, 3], 1)
    })
    model = nimbleModel(code,constants = list(n=10, p =5))
    expect_identical(findLatentNodes(model, 'x[2:4, 3:8, 3]'),
                     paste0('x[2:4, ', 3:8, ', 3]'))
    expect_identical(findLatentNodes(model, 'x'),
                     paste0('x[1:5, ', 1:10, ', 3]'))

    code = nimbleCode({
        x[1] ~ dnorm(0,1)
        for(i in 2:6)
            x[i] ~ dnorm(x[i-1], 1)
    })
    model = nimbleModel(code)
    nodes = 'x[2:6]'
    expect_identical(findLatentNodes(model, 'x[2:6]'),
                     paste0('x[', 2:6, ']'))
    expect_identical(findLatentNodes(model, 'x'),
                     paste0('x[', 1:6, ']'))    
})



sink(NULL)

if(!generatingGoldFile) {
    trialResults <- readLines(tempFileName)
    correctResults <- readLines(system.file(file.path('tests', goldFileName), package = 'nimble'))
    compareFilesByLine(trialResults, correctResults)
}

options(warn = RwarnLevel)
nimbleOptions(verbose = nimbleVerboseSetting)
nimbleOptions(MCMCprogressBar = nimbleProgressBarSetting)

