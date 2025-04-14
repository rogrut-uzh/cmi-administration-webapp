from flask import render_template
from routes import main
from .auth import requires_auth

@main.route('/')
def cockpit():
    return render_template('cockpit.html', active_page='cockpit')

@main.route('/fulloverview')
def fulloverview():
    return render_template('fulloverview.html', active_page='fulloverview')

@main.route('/services')
@requires_auth
def services():
    return render_template('services.html', active_page='services')

@main.route('/services-single-prod')
@requires_auth
def services_single_prod():
    return render_template('services-single-prod.html', active_page='services-single-prod')

@main.route('/services-single-test')
@requires_auth
def services_single_test():
    return render_template('services-single-test.html', active_page='services-single-test')

@main.route('/metatool')
@requires_auth
def metatool():
    return render_template('metatool.html', active_page='metatool')

@main.route('/databases')
@requires_auth
def databases():
    return render_template('databases.html', active_page='databases')
