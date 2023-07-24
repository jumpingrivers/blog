data {
  // dimensions & lengths
  int<lower=1> N;  // sample size
  int<lower=1> K;  // number B spline coeffs
  // observed data
  int<lower=0> y[N]; // observed counts
  matrix[N, K] X; // B spline basis functions
  // priors
  real m_alpha;
  real s_alpha;
  vector[K] m_beta;
  vector<lower=0>[K] s_beta;
  real<lower=0> m_phi;
  real<lower=0> s_phi;
}

parameters {
  real alpha;
  vector[K] beta;
  real log_phi;
}

transformed parameters {
  vector[N] log_lambda; // linear predictor
  log_lambda = alpha + X * beta;
}

model {
  // likelihood
  y ~ neg_binomial_2_log(log_lambda, exp(log_phi));
  // prior
  alpha ~ normal(m_alpha, s_alpha);
  beta ~ normal(m_beta, s_beta);
  log_phi ~ normal(m_phi, s_phi);
}
generated quantities {
  int y_pred[N];
  y_pred = neg_binomial_2_log_rng(log_lambda, exp(log_phi));
}
