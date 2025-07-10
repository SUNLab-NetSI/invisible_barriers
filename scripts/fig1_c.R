library(ggplot2)
library(dplyr)
library(broom)
library(patchwork)
library(readr)

data <- read_csv("../data/fig1/model_norm_flux.csv")
aspect_ratio <- 1.4

## regression and annotation text ---------------------------------------------
fit1   <- lm(log10(normalized_flow) ~ COSINE_DISTANCE, data = data)
rsq1   <- summary(fit1)$r.squared
label1 <- paste0("R^2 == ", format(rsq1, digits = 2))

fit2  <- lm(log10(normalized_flow) ~ log10(GEODESIC_DISTANCE), data = data)
rsq2  <- summary(fit2)$r.squared
label2 <- paste0("R^2 == ", format(rsq2, digits = 2))

## -------------------------------------------------
## 1. Build TWO separate fill scales with same range
## -------------------------------------------------
# Find a reasonable upper limit once; here we take the larger
# of the two max 2-D bin counts, but you can also hard-code a value.
tmp1 <- ggplot_build(
  ggplot(data, aes(COSINE_DISTANCE, normalized_flow)) +
    geom_bin2d(bins = 60)
)$data[[1]]$count
tmp2 <- ggplot_build(
  ggplot(data, aes(GEODESIC_DISTANCE, normalized_flow)) +
    geom_bin2d(bins = 60)
)$data[[1]]$count
max_cnt <- max(tmp1, tmp2, na.rm = TRUE)

# Scale for panel 1 - Blue color scheme
fill_scale_1 <- scale_fill_gradient(
  low    = "#E4D1B9",
  high   = "#A97155",
  name   = "Count",
  trans  = "sqrt",
  # limits = c(0, max_cnt),      # identical limits → identical mapping
  breaks = c(40, 160)          # choose whatever ticks you like
)

# Scale for panel 2 - Gray color scheme (original)
fill_scale_2 <- scale_fill_gradient(
  low    = "gray80",
  high   = "gray20",
  name   = "Count",
  trans  = "sqrt",
  # limits = c(0, max_cnt),      # identical limits → identical mapping
  breaks = c(40, 120)          # choose whatever ticks you like
)

## -------------------------------------------------
## 2. Build the two plots with different color scales
## -------------------------------------------------
# ---------- panel 1  --------------------------------
p1 <- ggplot(data, aes(COSINE_DISTANCE, normalized_flow)) +
  geom_bin2d(bins = 60, aes(fill = after_stat(count))) +
  fill_scale_1 +                              # ← blue color scheme
  scale_y_log10(
    breaks  = scales::trans_breaks("log10",  function(x) 10^x),
    labels  = scales::trans_format("log10", scales::math_format(10^.x))
  ) +
  geom_smooth(method = "lm", colour = "red",
              linetype = "dashed", linewidth = 0.8, se = FALSE) +
  annotate("text",
           x = min(data[['COSINE_DISTANCE']], na.rm = TRUE), 
           y = min(data[['normalized_flow']], na.rm = TRUE), 
           hjust = 0, vjust = 0,
           label = label1, parse = TRUE,    # parse = TRUE draws superscript
           size = 3) +
  labs(x = "Cosine Distance",
       y = expression(T[ij] / (m[i] * m[j]))) +
  theme_minimal() +
  theme(
    axis.text = element_text(size = 7),
    panel.grid.minor = element_blank(),
    legend.position = "top",
    aspect.ratio = aspect_ratio
  )

# ---------- panel 2  --------------------------------
p2 <- ggplot(data, aes(GEODESIC_DISTANCE, normalized_flow)) +
  geom_bin2d(bins = 60, aes(fill = after_stat(count))) +
  fill_scale_2 +                              # ← gray color scheme
  scale_x_log10(
    breaks  = scales::trans_breaks("log10",  function(x) 10^x),
    labels  = scales::trans_format("log10", scales::math_format(10^.x))
  ) +
  scale_y_log10(
    breaks  = scales::trans_breaks("log10",  function(x) 10^x),
    labels  = scales::trans_format("log10", scales::math_format(10^.x))
  ) +
  annotate("text",
           x = min(data[['GEODESIC_DISTANCE']], na.rm = TRUE), 
           y = min(data[['normalized_flow']], na.rm = TRUE), 
           hjust = 0, vjust = 0,
           label = label2, parse = TRUE,    # parse = TRUE draws superscript
           size = 3) +
  geom_smooth(method = "lm", colour = "red",
              linetype = "dashed", linewidth = 0.8, se = FALSE) +
  # labs(x = "Geographical Distance (km)", y="") +
  labs(x = "Geographical Distance (km)", y=expression(T[ij] / (m[i] * m[j]))) +
  theme_minimal() +
  theme(
    axis.text = element_text(size = 7),
    panel.grid.minor = element_blank(),
    legend.position = "top",
    aspect.ratio = aspect_ratio
  )

## -------------------------------------------------
## 3. Combine plots with separate legends
## -------------------------------------------------
combined <- (p1 | p2)                         # side-by-side

# print(combined)   # display

ggsave("../outputs/fig1_c.pdf", combined, dpi=300)
