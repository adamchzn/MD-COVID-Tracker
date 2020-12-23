from flask import Flask, flash, redirect, render_template, request, session, abort, send_from_directory, send_file, jsonify
import pandas as pd
import json
import copy

app = Flask(__name__)

county_data = pd.read_csv("../data/md_counties.csv")
zip_data = pd.read_csv("../data/md_zips.csv")
county_name_crosswalk = pd.read_csv("../data/counties_proper_names.csv")


class DataStore:
    chosen_county_fips = None
    county_data = None
    zip_data = None


filter_data = DataStore()


@app.route("/main", methods=["GET", "POST"])
@app.route('/')
def homepage():
    chosen_county = request.form.get('county', 'Montgomery')
    filter_data.chosen_county = county_name_crosswalk[county_name_crosswalk.County == chosen_county].fips

    county = jsonify(county_data[county_data.fips == filter_data.chosen_county])
    zips = jsonify(zip_data[zip_data.fips == filter_data.chosen_county])

    filter_data.county_data = county
    filter_data.zip_data = zips

    return render_template("index.html", county=county, zips=zips)


@app.route("/county", methods=["GET", "POST"])
def return_county():
    return jsonify(county_data)


@app.route("/zip", methods=["GET", "POST"])
def return_zip():
    return jsonify(zip_data)


@app.route("/county-filtered", methods=["GET", "POST"])
def return_county():
    return filter_data.county_data


@app.route("/zip-filtered", methods=["GET", "POST"])
def return_zip():
    return filter_data.zip_data


@app.route("/statewide", methods=["GET", "POST"])
def return_statewide():
    data = pd.read_csv("../data/md_statewide.csv")
    return jsonify(data)


@app.route("/age", methods=["GET", "POST"])
def return_age():
    data = pd.read_csv("../data/md_age.csv")
    return jsonify(data)


@app.route("/race", methods=["GET", "POST"])
def return_race():
    data = pd.read_csv("../data/md_race.csv")
    return jsonify(data)


if __name__ == '__main__':
    app.run()
