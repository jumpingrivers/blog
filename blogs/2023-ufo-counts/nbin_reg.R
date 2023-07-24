# Packages & data ----
library(tidyverse)
library(rstan)
library(tidybayes)
library(splines)
options(mc.cores = 4)
ufo_sightings = readr::read_csv('https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2023/2023-06-20/ufo_sightings.csv')
# Helper fns ----

# Wrangling ----
## Grab sightings per year

sights_per_year = ufo_sightings %>%
  dplyr::filter(country_code == "GB") %>% 
  dplyr::mutate(year_of_sighting = lubridate::year(reported_date_time)) %>%
  dplyr::summarise(sightings_per_year = length(year_of_sighting), .by = "year_of_sighting") %>%
  arrange(year_of_sighting)

year_range = range(sights_per_year$year_of_sighting)

all_years = tibble::tibble(year = min(year_range):max(year_range))

sights_per_year = sights_per_year %>%
  dplyr::right_join(all_years, by = c("year_of_sighting" = "year")) %>%
  dplyr::mutate(sightings_per_year = dplyr::if_else(is.na(sightings_per_year),
                                                    0,
                                                    sightings_per_year))

sights_per_year %>%
  ggplot() +
  geom_point(aes(x = year_of_sighting, 
                 y = sightings_per_year)) + 
  xlab("Year of reported sighting") +
  ylab("Number of recorded sightings per year") +
  ggtitle("Yearly UFO sighting reports for Great Britain") +
  theme_minimal()
# construct B-splines

B = bs(sights_per_year$year_of_sighting,
       knots = seq(from = year_range[1],
                 to = year_range[2],
                 length = 10),
       degree = 3,
       intercept = TRUE)
K = ncol(B)
stan_data = list(
  N = nrow(sights_per_year),
  K = K,
  y = sights_per_year$sightings_per_year,
  X = B,
  # priors
  m_alpha = 0,
  s_alpha = 1,
  m_beta = rep(0, K),
  s_beta = rep(1, K),
  m_phi = 0,
  s_phi = 1
  )

fit = stan(
  "nbin_reg.stan",
  data = stan_data,
  chains = 4,
  iter = total_iter,
  warmup = warmup,
  thin = thin
)
## View numerical summary
fit

tidy_fit = fit %>%
  spread_draws(y_pred[condition])
tidy_fit %>%
  head()

sights_per_year = sights_per_year %>%
  dplyr::mutate(condition = 1:nrow(sights_per_year))

tidy_fit = tidy_fit %>%
  dplyr::left_join(sights_per_year, by = "condition") 
## Which years have the largest posterior mean estimate
tidy_fit %>%
  reframe(mean = mean(y_pred),
          year = year_of_sighting) %>%
  dplyr::distinct() %>%
  arrange(-mean) %>%
  head(5)
## Which spline coeffs are the most important?
fit %>%
  spread_draws(beta[condition]) %>%
  summarise(mean_beta = mean(beta)) %>%
  arrange(-abs(mean_beta)) %>%
  head(3)

## Plot posterior curves
tidy_fit %>%
  ggplot(aes(x = year_of_sighting, y = sightings_per_year)) +
  ## add posterior quantiles
  stat_lineribbon(aes(y = y_pred), .width = c(.97, .89, .73, .5), colour = "grey10") +
  scale_fill_brewer() +
  geom_point(aes(x = year_of_sighting, y = sightings_per_year), data = sights_per_year) +
  xlab("Year of reported sighting") +
  ylab("Number of recorded sightings per year") +
  ggtitle("UFO sighting reports for Great Britain, with posterior\nsummaries superimposed") +
  guides(fill = guide_legend(title = "Posterior\ncoverage")) +
  theme_minimal()

## pearson resids
## just a quick check to see if mean + uq is appropriate

resids = tidy_fit %>%
  ungroup() %>% 
  reframe(mean = mean(y_pred), 
          sd = sd(y_pred),
          sightings_per_year = sightings_per_year,
          year_of_sighting = year_of_sighting,
          .by = "condition") %>%
  dplyr::distinct() %>%
  dplyr::mutate(residual = (sightings_per_year - mean) / sd)

resids %>%
  ggplot(aes(x = year_of_sighting, y = residual)) +
  geom_point()

## perhaps some small issues prior to 1950, this could be fixed by tinkering with the spline terms
## of thinking more carefully about the likelihood
