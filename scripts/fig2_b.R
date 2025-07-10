library(ggplot2)
library(dplyr)
library(broom)
library(patchwork)
library(readr)

data <- read_csv("../data/fig2/cbg_distance.csv")

## regression and annotation text ---------------------------------------------
fit1   <- lm(COSINE_DISTANCE ~ log10(GEODESIC_DISTANCE), data = data)
rsq1   <- summary(fit1)$r.squared
label1 <- paste0("R^2 == ", format(rsq1, digits = 2))

# Create the plot
p1 <- ggplot(data, aes(x = GEODESIC_DISTANCE, y = COSINE_DISTANCE)) +
  geom_bin2d(bins = 50, aes(fill = after_stat(count))) +
  scale_fill_gradient(low = "gray90", high = "gray20", # "#F5F5F5"
                      name = "count", trans = "sqrt",
                      breaks = c(1000, 4000),     # choose whatever ticks you like
  ) +
  scale_x_log10(
    breaks  = scales::trans_breaks("log10",  function(x) 10^x),
    labels  = scales::trans_format("log10", scales::math_format(10^.x))
  ) +
  scale_y_continuous(limits = c(0, 1)) +  
  # Add fitted line - simplified approach
  geom_smooth(method = "lm", 
              formula = y ~ x,
              color = "red", linetype = "dashed", linewidth = 0.8, se = FALSE) +
  
  # Labels and styling
  labs(y = "Cosine Distance", 
       x = "Geographical Distance (km)") +
  
  # Add R-squared annotation
  annotate("text", 
           x = max(data[['GEODESIC_DISTANCE']], na.rm = TRUE), 
           y = 0, 
           label = label1, parse = TRUE,
           hjust = 1, vjust = -1, size = 6) +
  
  # Theme customizations
  theme_minimal() +
  theme(
    axis.text = element_text(size = 11),
    panel.grid.minor = element_blank(),
    aspect.ratio    = 1
  )

print(p1)

ggsave("../outputs/fig2_b.pdf", dpi=300)