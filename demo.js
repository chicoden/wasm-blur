var module;

var img = document.querySelector("img");
var canvas = document.querySelector("canvas");
var ctx = canvas.getContext("2d");

img.addEventListener("load", function() {
    // Draw multiple different sized versions of the image
    ctx.drawImage(img, 50, 50, 350, 400);
    ctx.drawImage(img, 450, 100, 175, 200);
    ctx.drawImage(img, 475, 350, 80, 100);

    // Draw a slightly transparent blue circle
    ctx.beginPath();
    ctx.fillStyle = "#0000FF88";
    ctx.arc(300, 200, 50, 0, 2 * Math.PI);
    ctx.fill();

    // Draw a tilted red rectangle
    ctx.save();
    ctx.translate(500, 300);
    ctx.rotate(-0.5);
    ctx.beginPath();
    ctx.fillStyle = "#FF0000FF";
    ctx.rect(0, 0, 200, 100);
    ctx.fill();
    ctx.restore();

    // Open a GET request for the WebAssembly binary
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "blur.wasm");

    xhr.responseType = "arraybuffer";
    xhr.onloadend = function() {
        // Create an instance of the WebAssembly module
        WebAssembly.instantiate(xhr.response, {}).then(function(result) {
            // Store a reference to the module for inspection in the console
            module = result.instance.exports;

            // Apply a gaussian filter to the canvas
            var snapshot = ctx.getImageData(0, 0, canvas.width, canvas.height);
            var buffer = new Uint8ClampedArray(module.memory.buffer, 0, snapshot.data.length);
            buffer.set(snapshot.data);
            var t0 = performance.now();
            module.blur(0, snapshot.data.length, snapshot.width, snapshot.height, 20, 10);
            var t1 = performance.now();
            ctx.putImageData(new ImageData(buffer, snapshot.width), 0, 0);

            console.log("Filter took " + (t1 - t0) + "ms");
        });
    };

    xhr.send();
});
