# Earth textures (issue #56)

The region under the climb (`assets/textures/earth_region_*`, 24 x 24 degrees around the launch site, from NASA GIBS) is now
4096 px across for the day map (about 650 m a pixel, near the Blue Marble's own 500 m) and 2048 for its relief and
clouds, built by `assets/source/planet_textures.py`. The Earth textures are imported lossy (WebP) instead of lossless:
the web build's pack went from 55.5 MB to 47.2 MB while the region got sharper. The globe stays at 4096 x 2048: 8192
was tried and left out (about 170 MB of video memory, too much for the browsers and phones the game targets).
Mipmaps stay off on the region textures (with them the clouds under the climb blurred at grazing angles).
