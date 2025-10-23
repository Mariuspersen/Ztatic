const home_btn = document.getElementById("home_btn");
const about_btn = document.getElementById("about_btn");
const contact_btn = document.getElementById("contact_btn");
const home_div = document.getElementById("home");
const about_div = document.getElementById("about");
const contact_div = document.getElementById("contact");
const css = document.documentElement.style;

function show_home() {
    home_div.hidden = false;
    about_div.hidden = true;
    contact_div.hidden = true;
}

function show_about() {
    home_div.hidden = true;
    about_div.hidden = false;
    contact_div.hidden = true;
}

function show_contact() {
    home_div.hidden = true;
    about_div.hidden = true;
    contact_div.hidden = false;
}

home_btn.addEventListener('click', show_home);
about_btn.addEventListener('click', show_about);
contact_btn.addEventListener('click', show_contact);