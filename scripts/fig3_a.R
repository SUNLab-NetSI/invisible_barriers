library(tidyverse)
library(sf)
library(tigris)
library(tidycensus)
library(leaflet)
library(osmdata)

sf::sf_use_s2(FALSE)

#get the counties in the Boston MSA
msas <- core_based_statistical_areas(cb = TRUE,year=2021) |>
  st_transform(4326)

#get the CBGs
MA1 <- get_acs(
  geography = "block group",
  variables = "B25077_001", 
  state = "MA",
  geometry = TRUE, 
  year = 2019,
  cb = FALSE
) 

MA2 <- get_acs(
  geography = "block_group",
  variables = "B25077_001", 
  state = "NH",
  geometry = TRUE, 
  year = 2019,
  cb = FALSE
) 

ma_blocks <- rbind(MA1,MA2)

#keep only the census blocks in the counties belonging to the Boston MSA
boston_msa <- msas %>%
  filter(GEOID == "14460") 

ma_blocks_centroids <- ma_blocks |>
  mutate(centroid=st_centroid(geometry)) |>
  st_set_geometry("centroid") |>
  st_transform(4326)
ma_blocks_centroids <- ma_blocks_centroids[boston_msa,]
ma_blocks <- ma_blocks |> filter(GEOID %in% ma_blocks_centroids$GEOID)

#include the quantile of house price
ma_blocks <- ma_blocks |> mutate(quant = paste0("Q",ntile(estimate,4)))

#erase the water
ma_blocks_erased <- erase_water(ma_blocks,area_threshold = 0.85) 

ma_blocks_erased <- ma_blocks_erased |>
  st_make_valid() |>
  st_collection_extract("POLYGON") 

bbox <- c(-71.189615,42.294475,-70.990549,42.428925)
ma_vis <- st_crop(ma_blocks_erased,
                  xmin=bbox[1],xmax=bbox[3],
                  ymin=bbox[2],ymax=bbox[4])

ma_vis_clean <- ma_vis |> 
  st_make_valid() |>
  mutate(geometry = st_cast(geometry, "MULTIPOLYGON")) |> 
  st_cast("POLYGON") |>
  mutate(area=st_area(geometry)) |>
  filter(as.numeric(area) > 10000)

#get also the main roads in that bounding box
#this might take a while

main_roads <- c("motorway", "trunk", "primary")
roads <- opq(bbox = bbox) %>%
  add_osm_feature(key = "highway", value = main_roads) |>
  osmdata_sf()
roads <- roads$osm_lines

#plot Figure 3

#read the file and get GBG1 <-> CBG2
a <- read_csv("../data/fig3/14460_19_barriers.csv")
b <- a |> mutate(CBG1 = a$CBG2,CBG2=a$CBG1)
barriers <- rbind(a,b)

#add the number of barriers ending or starting in a CBG
num_barriers <- barriers |> group_by(CBG1) |> summarize(nbarriers=n()) |>
  mutate(GEOID = as.character(CBG1))

ma_vis_barrier <- left_join(ma_vis_clean,num_barriers,by="GEOID") |>
  mutate(nbarriers=ifelse(is.na(nbarriers),0,nbarriers))


#To simplify the plot, we only plot the barriers in phy_quantile = 1,2, arranged by difference between cosine and geodesic distance and only the top 3 by origin CBG
barriers_sampled <- barriers |> arrange(COSINE_DISTANCE/GEODESIC_DISTANCE) |>
  filter(phy_quantile %in% 1:2) |>
  group_by(CBG1) |> slice_head(n=3) |>
  ungroup()

#plot
color_roads <- "#173D82"
color_water <- "#8CCDEB"

bbox <- c(-71.189615,42.294475,-70.990549,42.428925)
ma_vis_barrier$high <- ifelse(ma_vis_barrier$nbarriers > 100, ">100","<=100")

ggplot() + geom_sf(data=ma_vis_barrier,aes(col=high,fill=high)) +
  geom_sf(data=roads |>
            filter(highway %in% c("trunk","motorway")),
          inherit.aes = FALSE,
          color=color_roads,
          linewidth = .5,
          alpha = .65
  ) +  
  geom_segment(data=barriers_sampled,
               aes(x=lng1,y=lat1,xend=lng2,yend=lat2),alpha=.5,
               linewidth = .6,
               col="#b3292a")+
  theme_void() + 
  theme(
    panel.background = element_rect(
      fill = alpha(color_water, 0.60),  # 40 % opacity
      colour = NA                       # no border
    ),
    plot.background  = element_rect(fill = "white", colour = NA)  # will show through
  ) +
  coord_sf(
    xlim = c(bbox[1], bbox[3]),
    ylim = c(bbox[2], bbox[4]),
    expand = FALSE
  )+
  scale_fill_manual(values=c("gray95", "gray80","black")) + 
  scale_color_manual(values=c("gray95", "gray80","black"))

ggsave("../outputs/fig3_a.pdf",width=10,height=10)
