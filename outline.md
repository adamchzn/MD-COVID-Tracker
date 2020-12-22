| View                                                         | Chart type  | Geography              | Data required                                       |
| ------------------------------------------------------------ | ----------- | ---------------------- | --------------------------------------------------- |
| Change in cases (or maybe just cases over the last two weeks?) | Map         | County, zip            | Disaggregated daily new cases                       |
| Where cases are (low, high) and (increasing, steady, decreasing) | Lines       | County                 | Disaggregated daily new cases per 100k              |
| Hospitalizations                                             | Line        | Statewide              | Daily hospitalizations                              |
| Positivity rate                                              | Line        | Statewide              | Daily positivity rate                               |
| Testing                                                      | Line        | Statewide              | Daily testing volume                                |
| Change in cases/recent cases                                 | Map         | Zip in selected county | Disaggregated daily new cases                       |
| Communal living facility data                                | Table       | Selected county        | Facility cases/deaths                               |
| Race data                                                    | Bars        | Statewide              | Cases and deaths by race (population-adjusted)      |
| Age data                                                     | Bars        | Statewide              | Cases and deaths by age group (population-adjusted) |
| Cumulative data                                              | Maps, table | County, zip            | Cases, deaths, tests                                |



**Overall**, we need these data bases which we can filter:

* County: cases, new cases (7-day rolling average), new cases per 100k (7-day rolling average); deaths, new deaths; tests, new tests (7-day rolling average); hospital capacity percentage; positivity rate (7-day rolling average)
* Zip: cases, new cases (7-day rolling average), new cases per 100k, county
* Statewide: current hospitalizations (7-day rolling average); positivity rate (7-day rolling average); tests, new tests (7-day rolling average)
* Facilities: cases, deaths, county
* Race: cases, deaths, population
* Age: cases, deaths, population