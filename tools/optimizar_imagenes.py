"""Convierte a WebP las imágenes nuevas del juego (PNG o JPG) y borra el original.

El juego usa WebP porque pesa unas 3-4 veces menos que PNG con la misma
calidad visible, y así la app se descarga más rápido.

Uso (desde la carpeta del proyecto):
    pip install pillow
    python tools/optimizar_imagenes.py

Solo toca las carpetas que van dentro de la app. Las imágenes de moretones
(*_idle_hurt1/2) funcionan también en PNG, pero conviene convertirlas igual.
"""
import glob
import os

from PIL import Image

CARPETAS = ['fighters', 'monsters', 'flyers', 'maps', 'icons']

total_antes = total_despues = 0
for carpeta in CARPETAS:
    for ruta in glob.glob(f'assets/images/{carpeta}/*'):
        if not ruta.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
        destino = os.path.splitext(ruta)[0] + '.webp'
        Image.open(ruta).save(destino, 'WEBP', quality=85, method=6)
        total_antes += os.path.getsize(ruta)
        total_despues += os.path.getsize(destino)
        os.remove(ruta)
        print(f'{ruta} -> {destino}')

if total_antes:
    print(f'Listo: {total_antes / 1e6:.1f} MB -> {total_despues / 1e6:.1f} MB')
else:
    print('No hay imágenes PNG/JPG nuevas que convertir.')
