function webGPUTextureFromImageBitmapOrCanvas(gpuDevice, source) {
    const textureDescriptor = {
    // Unlike in WebGL, the size of our texture must be set at texture creation time.
    // This means we have to wait until the image is loaded to create the texture, since we won't
    // know the size until then.
      size: { width: source.width, height: source.height },
      format: 'rgba8unorm',
      usage: GPUTextureUsage.TEXTURE_BINDING |
      GPUTextureUsage.COPY_DST |
      GPUTextureUsage.RENDER_ATTACHMENT,
    };
    const texture = gpuDevice.createTexture(textureDescriptor);
  
    gpuDevice.queue.copyExternalImageToTexture({ source }, { texture }, textureDescriptor.size);
  
    return texture;
  }
  // Assumes the
  async function webGPUTextureFromImageUrl(gpuDevice, url) { // Note that this is an async function
    const response = await fetch(url)
    console.log(response)
    const blob = await response.blob();
    const imgBitmap = await createImageBitmap(blob);
  
    return webGPUTextureFromImageBitmapOrCanvas(gpuDevice, imgBitmap);
  }
  async function webGPUTextureFromImageElement(gpuDevice, imgElement) {
    if (imgElement.complete) {
      const imgBitmap = await createImageBitmap(imgElement);
      return await webGPUTextureFromImageBitmapOrCanvas(gpuDevice, imgBitmap);
    } else {
    // If the image isn't loaded yet we'll wrap the load/error events in a promise to keep the
    // function interface consistent.
      return new Promise((resolve, reject) => {
        imgElement.addEventListener('load', async () => {
          const imgBitmap = await createImageBitmap(imgElement);
          console.log(imgBitmap)
          return await webGPUTextureFromImageBitmapOrCanvas(gpuDevice, imgBitmap);
        });
        imgElement.addEventListener('error', reject);
      });
    };
  }