easypackages::libraries("tidyverse", "jsonify", "janitor", "zoo", "scales", "htmltools", "DT", "here", "sparkline", "rmarkdown", "RcppRoll", "stringi")

pop_county <- read_csv("population/county.csv")
pop_zip <- read_csv("population/zip.csv")
md_fips <- read_csv("md_fips.csv")
zip_crosswalk <- read_csv("zip_crosswalk.csv") %>%
	mutate(zip = as.character(zip))

md_counties_hospit <- read_csv("../data/md_hospit_county.csv") %>%
	select(county, fips, collection_week, inpatient_percent_occupied, icu_percent_occupied) %>%
	group_by(county, fips) %>%
	slice(rep(1:n(), each = 7)) %>%  # assume the same occupancy for each day of the week
	group_by(county, fips, collection_week) %>%
	mutate(date = collection_week + 1:n() - 1L) %>%
	ungroup() %>%
	select(-collection_week) %>%
	arrange(county, date)

counties_proper_names <- data.frame(County = c("Allegany", "Anne Arundel", "Baltimore County", "Baltimore City", "Calvert", "Caroline", "Carroll", "Cecil", "Charles", "Dorchester", "Frederick", "Garrett", "Harford", "Howard", "Kent", "Montgomery", "Prince George's", "Queen Anne's", "Somerset", "St. Mary's", "Talbot", "Washington", "Wicomico", "Worcester")) %>%
	bind_cols(drop_na(md_fips))

md_api <- function(api_url) {
	suppressWarnings(from_json(api_url)[["features"]]$attributes) %>%
		clean_names() %>%
		select(-objectid)
}

md_api_pivot <- function(df, first_day, geography = "name", na_to_zero = T) {
	df <- df %>%
		pivot_longer(cols = -1) %>%
		group_by_at(geography) %>%
		mutate(date = seq.Date(first_day, first_day + dplyr::n() - 1, by = "day")) %>%
		ungroup()

	if (na_to_zero)
		df <- mutate(df, value = replace_na(value, 0))

	df
}

md_indicator_combine <- function(cases, deaths, prob_deaths, join_key, uk_text = "unknown") {
	inner_join(cases, deaths, by = c("date", join_key)) %>%
		inner_join(prob_deaths, by = c("date", join_key)) %>%
		filter(date == max(date), str_detect(!!rlang::sym(join_key), uk_text, negate = T)) %>%
		select(-date) %>%
		pivot_longer(cols = -!!rlang::sym(join_key), names_to = "variable") %>%
		mutate(variable = recode(variable, "cases" = "Confirmed cases", "deaths" = "Confirmed deaths", "prob_deaths" = "Probable deaths"))
}

# COUNTY

md_counties_cases <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_CasesByCounty/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("3/15/2020", "%m/%d/%y")) %>%
	select(date, county = name, cases = value) %>%
	inner_join(md_fips, by = "county") %>%
	inner_join(pop_county, by = c("county", "fips")) %>%
	group_by(county) %>%
	mutate(new_cases = pmax(cases - lag(cases), 0),
				 new_cases_avg = rollmeanr(new_cases, 7, fill = NA),
				 new_cases_100k = new_cases/population*100000,
				 new_cases_100k_avg = rollmeanr(new_cases_100k, 7, fill = NA)) %>%
	ungroup() %>%
	select(date, county, fips, population, cases, new_cases, new_cases_avg, new_cases_100k, new_cases_100k_avg)

md_counties_prob_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_ProbableDeathsByCounty/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("4/13/2020", "%m/%d/%y")) %>%
	select(date, county = name, prob_deaths = value) %>%
	inner_join(md_fips, by = "county")

md_counties_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_ConfirmedDeathsByCounty/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("4/3/2020", "%m/%d/%y")) %>%
	select(date, county = name, deaths = value) %>%
	inner_join(md_fips, by = "county") %>%
	inner_join(md_counties_prob_deaths, by = c("date", "county", "fips")) %>%
	mutate(deaths = deaths + prob_deaths) %>%
	select(-prob_deaths) %>%
	group_by(county) %>%
	mutate(new_deaths = pmax(deaths - lag(deaths), 0),
				 new_deaths_avg = rollmeanr(new_deaths, 7, fill = NA)) %>%
	ungroup()

md_counties_volume <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_DailyTestingVolumeByCounty/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("2020-06-15"), "county") %>%
	mutate(date = as.Date(ifelse(str_sub(name, end = 2) == "d_", str_sub(gsub("[^0-9_]", "", name), start = 2), gsub("[^0-9_]", "", name)), "%m_%d_%y"),
				 county = gsub(" ", "_", gsub("[.']", "", tolower(county)))) %>%  # woah... I actually know how to use gsub??
	select(date, county, new_tests = value) %>%
	group_by(county) %>%
	mutate(new_tests_avg = rollmeanr(new_tests, 7, fill = NA)) %>%
	ungroup() %>%
	inner_join(md_fips, by = "county")

md_counties_pos <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_PosPercentByJursidiction/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	mutate(report_date = seq.Date(as.Date("2020-03-30"), as.Date("2020-03-30") + dplyr::n() - 1, by = "day")) %>%
	mutate_at(vars(2:ncol(.)), ~ as.numeric(.)) %>%
	rename_at(vars(2:ncol(.)), ~ stri_replace_last_fixed(stri_replace_last_fixed(., "_", ""), "_", " ")) %>%
	pivot_longer(cols = -report_date, names_to = c("county", "type"), names_sep = " ", values_to = "percent") %>%
	mutate(percent = percent/100) %>%
	pivot_wider(names_from = type, values_from = percent) %>%
	inner_join(md_fips, by = "county") %>%
	select(date = report_date, county, fips, pos = percentpositive, pos_avg = rollingavg)

md_counties <- left_join(md_counties_cases, md_counties_deaths, by = c("county", "date", "fips")) %>%
	left_join(md_counties_volume, by = c("county", "date", "fips")) %>%
	left_join(md_counties_pos, by = c("county", "date", "fips")) %>%
	left_join(md_counties_hospit, by = c("county", "date", "fips"))

# ZIP

md_zips <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_MASTER_ZIP_CODE_CASES/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("2020-04-11"), "zip_code") %>%
	select(date, zip = zip_code, cases = value) %>%
	group_by(zip) %>%
	mutate(new_cases = pmax(cases - lag(cases), 0)) %>%
	ungroup() %>%
	inner_join(pop_zip, by = "zip") %>%
	mutate(cases_per_100k = cases/population*100000) %>%
	left_join(zip_crosswalk, by = "zip")

# AGE

md_age_cases <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_CasesByAgeDistribution/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("3/29/2020", "%m/%d/%y")) %>%
	select(date, age_range = name, cases = value)

md_age_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_ConfirmedDeathsByAgeDistribution/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("4/8/2020", "%m/%d/%y")) %>%
	select(date, age_range = name, deaths = value)

md_age_prob_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_ProbableDeathsByAgeDistribution/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("4/13/2020", "%m/%d/%y")) %>%
	select(date, age_range = name, prob_deaths = value)

age_data <- md_indicator_combine(md_age_cases, md_age_deaths, md_age_prob_deaths, "age_range") %>%
	mutate(age = str_replace_all(str_sub(age_range, 5), c("_to_" = "-", "plus" = "+"))) %>%
	select(age, variable, value) %>%
	pivot_wider(names_from = variable, values_from = value) %>%
	mutate(Deaths = `Confirmed deaths` + `Probable deaths`) %>%
	select(age, `Confirmed cases`, Deaths)

# RACE

md_race_cases <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_CasesByRaceAndEthnicityDistribution/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("4/6/2020", "%m/%d/%y"), na_to_zero = F) %>%
	select(date, race = name, cases = value)

md_race_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_ConfirmedDeathsByRaceAndEthnicityDistribution/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("4/6/2020", "%m/%d/%y"), na_to_zero = F) %>%
	select(date, race = name, deaths = value)

md_race_prob_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_ProbableDeathsByRaceAndEthnicityDistribution/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	md_api_pivot(as.Date("4/13/2020", "%m/%d/%y"), na_to_zero = F) %>%
	select(date, race = name, prob_deaths = value)

race_data <- md_indicator_combine(md_race_cases, md_race_deaths, md_race_prob_deaths, "race", uk_text = "not_available") %>%
	mutate(race = recode(race, "african_american" = "Black", "asian" = "Asian", "white" = "White", "hispanic" = "Hispanic", "other" = "Other")) %>%
	pivot_wider(names_from = variable, values_from = value) %>%
	mutate(Deaths = `Confirmed deaths` + `Probable deaths`) %>%
	select(race, `Confirmed cases`, Deaths)

# STATEWIDE

md_hospit <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_TotalCurrentlyHospitalizedAcuteAndICU/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	setNames(c("date", "acute", "icu", "total_hospit")) %>%
	mutate(date = seq.Date(as.Date("2020-03-26"), as.Date("2020-03-26") + n() - 1, by = "day")) %>%
	filter(!is.na(acute)) %>%
	mutate(total_hospit_avg = rollmeanr(total_hospit, 7, fill = NA))

md_volume <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_TestingVolume/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	mutate(date = seq.Date(as.Date("2020-03-24"), as.Date("2020-03-24") + n() - 1, by = "day"),
				 pos = percent_positive / 100,
				 pos_avg = rolling_avg / 100,
				 new_tests_avg = rollmeanr(number_of_tests, 7, fill = NA),
				 total_tests = cumsum(number_of_tests)) %>%
	select(date, new_tests = number_of_tests, new_tests_avg, total_tests, positives = number_of_positives, pos, pos_avg)

md_statewide_cases <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_TotalCasesStatewide/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	select(date, cases = count) %>%
	mutate(date = seq.Date(as.Date("2020-03-04"), as.Date("2020-03-04") + n() - 1, by = "day"),
				 new_cases = cases - lag(cases),
				 avg_new_cases = rollmeanr(new_cases, 7, NA))

md_statewide_conf_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_TotalConfirmedDeathsStatewide/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	select(date, conf_deaths = count) %>%
	mutate(date = seq.Date(as.Date("2020-03-18"), as.Date("2020-03-18") + n() - 1, by = "day"))

md_statewide_prob_deaths <- md_api("https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MDCOVID19_TotalProbableDeathsByDateOfDeath/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json") %>%
	select(date, prob_deaths = count) %>%
	mutate(date = seq.Date(as.Date("2020-03-29"), as.Date("2020-03-29") + n() - 1, by = "day"))

md_statewide_deaths <- left_join(md_statewide_conf_deaths, md_statewide_prob_deaths, by = "date") %>%
	mutate(prob_deaths = replace_na(prob_deaths, 0),
				 deaths = conf_deaths + prob_deaths,
				 new_deaths = deaths - lag(deaths),
				 avg_new_deaths = rollmeanr(new_deaths, 7, NA)) %>%
	select(date, deaths, new_deaths, avg_new_deaths)

md_statewide <- full_join(md_hospit, md_volume, by = "date") %>%
	full_join(md_statewide_cases, by = "date") %>%
	full_join(md_statewide_deaths, by = "date") %>%
	arrange(date)

save_dfs <- function(df)
	write_csv(get(df), paste0("../data/", df, ".csv"))

dfs <- c("md_counties", "md_zips", "age_data", "race_data", "md_statewide", "counties_proper_names")

lapply(dfs, save_dfs)