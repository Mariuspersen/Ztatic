play_warships = document.getElementById("play-warships");
spin_wheel = document.getElementById("spin-wheel");

async function add_game_iframe_to_content() {
    content.innerHTML = "";
    const iframe = document.createElement("iframe");
    iframe.src = "/ShipGirlGame/index.html";
    iframe.title = "ShipGirlGame";
    iframe.scrolling = "no";
    iframe.height = "1000px";
    content.appendChild(iframe);
}

async function add_spinningwheel_iframe_to_content() {
    content.innerHTML = "";
    const iframe = document.createElement("iframe");
    iframe.src = "/Spinnehjul/index.html";
    iframe.title = "ShipGirlGame";
    iframe.scrolling = "no";
    iframe.height = "800px";
    content.appendChild(iframe);
}

spin_wheel.addEventListener('click',add_spinningwheel_iframe_to_content);
play_warships.addEventListener('click',add_game_iframe_to_content);
