lang_eng_btn = document.getElementById("lang-eng");
lang_nor_btn = document.getElementById("lang-nor");


async function get_eng_cv() {
    await get_and_set_content("cv-eng.html");
    await get_and_execute_script("cv.js");
}

async function get_nor_cv() {
    await get_and_set_content("cv-nor.html");
    await get_and_execute_script("cv.js");
}

lang_eng_btn.addEventListener('click',get_eng_cv);
lang_nor_btn.addEventListener('click',get_nor_cv);