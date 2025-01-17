rm(list=ls())
setwd("~/GitHub/gev")
source("./lib/pack.R")
source("./lib/sgevlibrary.R")

# data generation
set.seed(1)
xyrange = c(-10,10)
nobs = 100
ns= 50
nBS = 3

# x1 = seq(xyrange[1],xyrange[2],length=100)
# x2 = seq(xyrange[1],xyrange[2],length=100)
# fx = outer(x1, x2, function(x1,x2) {
#   zval = 100+(-2*x1-3*x2)/4
# })
# plot_ly(x = x1, y = x2, z = fx) %>% add_surface()
# range(fx)

x1 = runif(ns,xyrange[1],xyrange[2])
x2 = runif(ns,xyrange[1],xyrange[2])
zval = 100+(-2*x1-3*x2) # 평면
range(zval)

df_mu = data.frame(x1=x1,x2=x2,z=zval)
set.seed(2)
par_scale = rtruncnorm(ns, a=35, b=45, mean=40, sd=2)
par_shape = runif(ns,0.1,0.25)

xlist = list()
for (i in 1:ns){
  xlist[[i]] = rgev(nobs,loc=df_mu$z[i],scale=par_scale[i],shape=par_shape[i])
}
sum(unlist(lapply(1:length(xlist),function(x) sum(is.na(xlist[[x]])))))

# zlist - 2-D basis matrix by each location
# (fda package)
x_bsobj = create.bspline.basis(xyrange,norder=4, 
                               breaks=quantile(x1,prob = seq(0, 1, length = nBS)))
y_bsobj = create.bspline.basis(xyrange,norder=4, 
                               breaks=quantile(x2,prob = seq(0, 1, length = nBS)))

zlist = list()
for (i in 1:ns){
  xbs = eval.basis(df_mu$x1[i],x_bsobj)
  ybs = eval.basis(df_mu$x2[i],y_bsobj)
  tensorbs = do.call('cbind', lapply(1:ncol(xbs), function(i) xbs[, i] * ybs)) 
  zlist[[i]] = tensorbs 
}
xbss <- eval.basis(x1,x_bsobj)
ybss <- eval.basis(x2,y_bsobj)
tensorbss <- do.call('cbind', lapply(1:ncol(xbss), function(i) xbss[, i] * ybss)) 
#sum(zlist[[3]])
# dim(zlist[[1]]) # (frist)stnlds 2D-splines tensor, nbasis = df x df

# Omega matrix
Fmat = kronecker(bsplinepen(x_bsobj,Lfdobj=2),bsplinepen(y_bsobj,Lfdobj=0))
Gmat = kronecker(bsplinepen(x_bsobj,Lfdobj=0),bsplinepen(y_bsobj,Lfdobj=2))
Hmat = kronecker(bsplinepen(x_bsobj,Lfdobj=1),bsplinepen(y_bsobj,Lfdobj=1))
Om = Fmat+Gmat+2*Hmat

# optim control
optim_controlList = list()
optim_controlList$maxit = 1e+3

# design matrix for v3 (mu_0 stationary)
matfunc = function(ns){
  matt = matrix(0,nrow=ns*(ns-1),ncol=ns)
  k = 1
  for (i in (1: (ns-1))){
    for (j in ((i+1) :ns)){
      matt[k,i] = 1
      matt[k,j] = -1
      k = k+1
    }  
  }
  mat = t(matt) %*% matt
  return(mat)
}
mat = matfunc(ns)

# to save setting values
#save(list=ls(),file="./numerical_setting.RDa")

# to etimate model
#lambdaset = c(seq(0,2,length=21),5,10,100)
lambda = 0

fit = gevreg_m(xlist,zlist,
               lambda = lambda, Om= Om, 
               method="B-spline")
result = fit$par
a = matrix(result[2:(1+ns*2)], ns, 2, byrow = T)


# scale and shape;
plot(a[,1], par_scale)
plot(a[,2], par_shape)

p = length(drop(zlist[[1]]))
b = c()
for (i in 1:length(zlist))  b[i] = sum( drop(zlist[[i]])*tail(result,p) )
bb = b + result[1]
plot(bb, df_mu$z)

# BIC and AIC
like = 0
for (i in 1:ns)
{
  x = xlist[[i]]
  m = bb[i]
  s = a[i,1]
  k = a[i,2]
  like = like -sum(dgev(x, m, s, k, log = T))
}
like
Z = tensorbss
Hmat_lambda = Z%*%solve(t(Z)%*%Z +lambda*Om)%*%t(Z)
DF = sum(diag(Hmat_lambda))+2*ns
2*like + log(ns*nobs)*DF

# save.file for each lambda
eval(parse(text = paste0('result', lambda_idx, ' = result')))

eval(parse(text = paste0('save(result', lambda_idx,
                         paste0(",file =","'", paste0('./result_train',lambda_idx, '.RDa',"')")))))
