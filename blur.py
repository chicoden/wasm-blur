from wasmtime import Store, Module, Instance
from PIL import Image
import numpy as np
import time

store = Store()
module = Module.from_file(store.engine, "blur.wasm")

instance = Instance(store, module, [])
exports = instance.exports(store)

memory = np.frombuffer(exports["memory"].get_buffer_ptr(store), dtype="uint8")
blur = exports["blur"]

image = Image.open("robot.png").convert("RGBA").resize((450, 600), Image.BICUBIC)
array = np.asarray(image)

memory[:array.nbytes] = array.reshape((array.nbytes,))
t0 = time.monotonic()
blur(store, 0, array.nbytes, *image.size, 20, 10.0)
t1 = time.monotonic()
blurred = memory[:array.nbytes].reshape(array.shape)

print("Blur took", t1 - t0, "seconds.")
Image.fromarray(blurred).show()
