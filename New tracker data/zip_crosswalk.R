easypackages::libraries("tidyverse", "readxl")

md_fips <- read_csv("md_fips.csv") %>%
	mutate(fips = as.character(fips))

zip_crosswalk <- read_excel("ZIP_COUNTY_092020.xlsx", col_types = rep("text", 6)) %>%
	inner_join(md_fips, by = c("COUNTY" = "fips")) %>%
	group_by(ZIP) %>%
	arrange(desc(TOT_RATIO)) %>%
	summarize(fips = first(COUNTY), county = first(county)) %>%
	ungroup() %>%
	rename(zip = ZIP) %>%
	mutate(zip = as.character(zip))

write_csv(zip_crosswalk, "zip_crosswalk.csv")