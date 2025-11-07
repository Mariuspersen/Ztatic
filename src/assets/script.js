const content = document.getElementById("content");
const home_btn = document.getElementById("home");
const about_btn = document.getElementById("about");
const project_btn = document.getElementById("projects");
const cv_btn = document.getElementById("cv");
const darkmode_btn = document.getElementById("darkmode");
const css = document.documentElement.style;

let play_warships;
let lang_eng_btn;
let lang_nor_btn;

async function get_and_set_content(content_sel) {
    const res = await fetch(content_sel);
    const text = await res.text();
    content.innerHTML = text;
}

async function get_and_execute_script(script_sel) {
    const res = await fetch(script_sel);
    const text = await res.text();
    const scriptElement = document.createElement("script");
    scriptElement.textContent = text;
    content.appendChild(scriptElement);
}

function get_home() {
    switch_lang = true;
    get_and_set_content("home.html")
}

function get_about() {
    switch_lang = true;
    get_and_set_content("about.html")
}

async function get_project() {
    switch_lang = true;
    await get_and_set_content("projects.html")
    await get_and_execute_script("projects.js");
}

async function get_cv() {
    await get_and_set_content("cv-eng.html");
    await get_and_execute_script("cv.js");
}

async function load_spinningwheel() {
    await get_and_execute_script("projects.js");
    add_spinningwheel_iframe_to_content();
}

async function load_boatgame() {
    await get_and_execute_script("projects.js");
    add_game_iframe_to_content();
}

function darkmode() {
    let computed = getComputedStyle(document.documentElement);
    let old_text = computed.getPropertyValue("--text-color")?.trim();
    let old_back = computed.getPropertyValue("--main-background-color")?.trim();
    let old_sec_back = computed.getPropertyValue("--secondary-background-color")?.trim();
    let old_tert_back = computed.getPropertyValue("--tertiary-background-color")?.trim();
    let old_invert = computed.getPropertyValue("--invert")?.trim();
    let old_blog_background = computed.getPropertyValue("--blog-background-color")?.trim();
    let old_blog_secondary_background = computed.getPropertyValue("--blog-background-secondary")?.trim();

    let new_invert = old_invert == "0" ? "1" : "0";

    css.setProperty("--text-color",old_back);
    css.setProperty("--main-background-color",old_text);
    css.setProperty("--secondary-background-color",old_tert_back);
    css.setProperty("--tertiary-background-color",old_sec_back);
    css.setProperty("--invert",new_invert);
    css.setProperty("--blog-background-color",old_blog_secondary_background);
    css.setProperty("--blog-background-secondary",old_blog_background);
}

home_btn.addEventListener('click', get_home);
about_btn.addEventListener('click', get_about);
project_btn.addEventListener('click', get_project);
cv_btn.addEventListener('click', get_cv);
darkmode_btn.addEventListener('click',darkmode);

const destination = document.location.href.split('/').pop();

switch(destination) {
    case "#spinningwheel":
    case "#spinnehjul": {
        load_spinningwheel();
        break;
    }
    case "#boats":
    case "#boatgame":
    case "#game": {
        load_boatgame();
        break;
    }
    case "#projects": {
        get_project();
        break;
    }
    case "#cv": {
        get_cv();
        break;
    }
    default: {
        get_home();
        break;
    }
}
