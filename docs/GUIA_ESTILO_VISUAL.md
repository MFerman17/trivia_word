# Guía de estilo visual — Words & Monsters

Esta guía sirve para que **todas** las imágenes del juego parezcan hechas por el mismo
artista. Se usa así:

1. Copia el **bloque de estilo** del tipo de imagen que vas a pedir (personaje,
   monstruo, mapa o icono).
2. Debajo, añade la **descripción concreta** (qué criatura, qué mundo, qué pose).
3. Pide a ChatGPT las imágenes de un mismo grupo **en la misma conversación**
   (por ejemplo, las 5 poses de un monstruo), para que mantenga el personaje.

> Por qué funciona: la IA "rellena" lo que no le dices con lo que se le ocurre en
> ese momento. Si cada petición empieza con el mismo bloque de estilo, deja de
> improvisar el estilo y solo cambia lo que tú describes.

---

## 1. Lo que ya tenemos (revisión de las imágenes actuales)

| Grupo | Estado | Comentario |
|---|---|---|
| Monstruos de mundo (4) y sus poses | ✅ Coherente | Brillantes, saturados, ojos grandes, acabado "glossy". Es el estilo de referencia. |
| Criaturas voladoras (8) | ✅ Coherente | Mismo estilo que los monstruos. |
| Luchadores (explorador, maga, guardiana) | ✅ Coherente entre sí | Adornos dorados y turquesa, buen nivel. |
| Avatares (3) | ✅ Coherente | Mismos personajes que los luchadores. |
| `adventurer.png` (portada) | ⚠️ Desentona | Estilo más simple y apagado (chaqueta marrón, sin dorados). No parece el mismo explorador que el luchador. **Rehacer.** |
| `dragon.png` (portada y ahorcado) | ⚠️ Desentona | Más realista y oscuro que el resto de criaturas. **Rehacer** en el estilo de los monstruos. |
| Mapas `Bosque_1`, `Bosque_3`, `Cavernas_1`, `Islas_1`, `Volcan_1` | ⚠️ Desentonan | Son una "maqueta" sobre un fondo de color liso. Los demás mapas ocupan toda la imagen. En el juego se nota el fondo liso en las esquinas. **Rehacer** a imagen completa. |
| Mapas `_2` y `_3` (resto) | ✅ Coherentes | Isométricos, pintados, a sangre (sin bordes). Son la referencia de mapas. |
| Iconos de monedas, gemas, pociones… | ⚠️ Son emojis | Cada marca de teléfono dibuja los emojis distinto (Samsung, Xiaomi…), y dan aspecto de app y no de juego. **Crear iconos propios** (sección 6). |
| Ropa de la maga y la guardiana | 💡 Recomendación | Medias de rejilla y escotes. Para un juego de palabras para 13+, una versión más cubierta amplía el público y evita problemas con la clasificación de edad de Google Play. Opcional. |

---

## 2. Bloque de estilo — PERSONAJES Y MONSTRUOS

Copia esto al principio de cada petición de personaje, monstruo, jefe o criatura:

```
Estilo: ilustración de videojuego móvil de fantasía, semirrealista estilizada,
colores vivos y saturados, acabado brillante tipo "glossy", luz suave de borde
(rim light), detalles dorados y turquesa, ojos grandes y expresivos, silueta
limpia y fácil de leer en pequeño. Mismo estilo que los monstruos de
Words & Monsters (salamandra de lava, murciélago de cristal, familiar del cielo,
guardián del bosque).
Formato: PNG con fondo TRANSPARENTE, 1024 x 1024 px, cuerpo completo, centrado,
sin texto, sin marco, sin sombra en el suelo.
Orientación: de perfil 3/4, MIRANDO A LA IZQUIERDA.
```

**Poses de un monstruo** (pedir en este orden, en la misma conversación):

| Archivo | Pose |
|---|---|
| `NOMBRE_idle.png` | Quieto, en guardia |
| `NOMBRE_attack.png` | Atacando, con su efecto (fuego, rayo, hojas…) |
| `NOMBRE_hit.png` | Recibiendo un golpe, echado hacia atrás |
| `NOMBRE_win.png` | Celebrando la victoria |
| `NOMBRE_lose.png` | Derrotado, en el suelo |
| `NOMBRE_idle_hurt1.png` | Igual que idle, con algún rasguño |
| `NOMBRE_idle_hurt2.png` | Igual que idle, muy golpeado (moretones, vendas) |

Frase útil para las poses: *"Mismo personaje, misma escala, misma posición en
la imagen y mirando a la IZQUIERDA; solo cambia la postura."* Si alguna sale
mirando a la derecha, no pasa nada: se puede voltear, pero todas las poses de un
mismo monstruo deben mirar al mismo lado.

---

## 3. Bloque de estilo — MAPAS DE MUNDO

```
Estilo: mapa de videojuego móvil de fantasía, vista isométrica desde arriba,
pintado a mano, muy detallado, iluminación ambiental con acentos que brillan.
La imagen debe llenar TODO el encuadre hasta los bordes: sin fondo liso, sin
"maqueta" flotando, sin marco.
Formato: 1248 x 832 px (apaisado).
Composición: un sendero serpenteante que sube desde la parte de abajo hasta la
parte de arriba, con 5 plataformas redondas de piedra bien visibles y
separadas entre sí, donde irán los niveles. El sendero y las plataformas
deben quedar en la franja central (no pegados a los lados).
```

Para cada capítulo cambia solo la descripción del lugar. Los 3 mapas de un mundo
deben compartir colores y ambiente, con más peligro en el capítulo 3.

---

## 4. Paleta de colores por mundo

| Mundo | Colores principales | Acento que brilla |
|---|---|---|
| 1 · Bosque | Verdes musgo y oliva, madera marrón | Turquesa (luces mágicas) |
| 2 · Cavernas | Gris piedra, violeta oscuro | Cristales azul y violeta |
| 3 · Islas Flotantes | Lila, azul cielo, blanco nube | Cascadas y rayos azules |
| 4 · Volcán | Negro roca, rojo, naranja | Lava naranja/amarilla |
| **5 · Desierto de las Runas** | Arena dorada, ocre, terracota | **Runas que brillan en turquesa** |
| **6 · Glaciar Eterno** | Blanco nieve, azul hielo, gris plata | **Auroras verde y violeta** |

---

## 5. Descripción de cada mundo

Cada mundo tiene una tabla igual: qué imagen es y qué escribir debajo del
bloque de estilo. Las descripciones siguen la historia del juego (lo que el
jugador lee al terminar cada capítulo), así el mapa enseña lo mismo que cuenta
el texto.

- **✏️ Rehacer**: la imagen actual desentona; pídela de nuevo con esta descripción.
- **🆕 Nuevo**: imagen que aún no existe (mundos 5 y 6).
- **✅ Mantener**: la imagen actual está bien. La descripción queda escrita por
  si algún día quieres rehacerla, y para que ChatGPT vea cómo son las otras
  dos del mismo mundo (cópiala en la conversación como referencia).

**Todos los mapas se rehacen con ChatGPT.** Los mapas actuales se hicieron con
Bing y por eso no combinan con los personajes. Para que los 12 mapas de los
mundos 1-4 y los 6 nuevos parezcan del mismo artista:

1. Haz primero **un solo mapa** (`Bosque_1`) y revisa que cumple el bloque de
   estilo: imagen completa hasta los bordes, 5 plataformas redondas en la franja
   central. Pásamelo y lo pruebo en el juego antes de seguir.
2. Si está bien, usa ese mapa como **imagen de referencia** de todos los demás:
   *"Mismo estilo, misma luz y mismo tipo de sendero y plataformas que esta
   imagen; solo cambian el lugar y los colores del mundo."*
3. Pide los 3 mapas de cada mundo seguidos, en la misma conversación.

Los monstruos, luchadores y avatares se mantienen: ya son de ChatGPT y son la
referencia de estilo.

### Mundo 1 · Bosque

Historia: un bosque antiguo donde algo está despertando; el Dragón del Bosque
guarda el primer fragmento.

| Imagen | Estado | Descripción para añadir al bloque de estilo |
|---|---|---|
| `Bosque_1.png` (mapa) | ✏️ Rehacer | Entrada de un bosque antiguo y brumoso: árboles enormes de troncos retorcidos y musgo, arroyos estrechos que brillan en turquesa, setas luminosas y faroles de madera con luz cálida a los lados del sendero. Al fondo, arriba, la luz se hace más intensa entre los árboles. |
| `Bosque_2.png` (mapa) | ✏️ Rehacer | El corazón del bosque: raíces gigantes que cruzan el sendero, un río turquesa que serpentea con puentes de madera, niebla baja entre los troncos, setas luminosas y una luz azul que late bajo los árboles. Mismo bosque que el capítulo 1, más oscuro y profundo. |
| `Bosque_3.png` (mapa) | ✏️ Rehacer | Lo más profundo del bosque: árboles todavía más grandes y oscuros, piedras antiguas con runas turquesa alineadas en círculo, y arriba del todo un gran portal de piedra cubierto de raíces, encendido por dentro. Más peligro: zarzas y ojos que brillan entre las sombras. |
| `mini_forest_guardian.png` + poses | ✅ Mantener | Guardián del bosque: criatura de madera y musgo con ojos turquesa. |

### Mundo 2 · Cavernas

Historia: unas cavernas llenas de cristales que cantan; el Coloso de las
Cavernas espera tras un puente sobre el abismo.

| Imagen | Estado | Descripción para añadir al bloque de estilo |
|---|---|---|
| `Cavernas_1.png` (mapa) | ✏️ Rehacer | Entrada a una caverna enorme vista desde arriba: paredes de roca gris y violeta que rodean toda la imagen, antorchas en el sendero, los primeros cristales azules y violetas asomando entre las rocas, charcos que reflejan su luz. Arriba, la boca oscura de un túnel. |
| `Cavernas_2.png` (mapa) | ✏️ Rehacer | El eco de los cristales: un túnel ancho con cristales gigantes azules y violetas en las paredes, cascadas subterráneas que caen a pozas brillantes, puentes de madera entre plataformas de roca y niebla al fondo. |
| `Cavernas_3.png` (mapa) | ✏️ Rehacer | El puente subterráneo: un gran puente de piedra sobre un abismo con agua turquesa brillante al fondo, cristales enormes, restos de esqueletos antiguos en las paredes y, arriba, un portal de cristal violeta donde espera el coloso. El capítulo más peligroso de las cavernas. |
| `mini_cave_bat.png` + poses | ✅ Mantener | Murciélago de cristal con alas translúcidas violetas. |

### Mundo 3 · Islas Flotantes

Historia: islas que flotan entre las nubes, unidas por corrientes de viento;
el Señor de las Islas guarda el fragmento en una tormenta de cristal.

| Imagen | Estado | Descripción para añadir al bloque de estilo |
|---|---|---|
| `Islas_1.png` (mapa) | ✏️ Rehacer | Varias islas de roca y hierba flotando en un mar de nubes lilas que llena toda la imagen hasta los bordes, unidas por puentes colgantes de cuerda; cascadas que caen de las islas al vacío, cielo de amanecer en azul y rosa. Arriba, una isla más alta con unas ruinas pequeñas. |
| `Islas_2.png` (mapa) | ✏️ Rehacer | Las corrientes del cielo: islas flotantes más altas con ruinas de piedra antiguas, cascadas azules que caen al vacío, puentes de madera y cuerda, remolinos de viento visibles y nubes violetas que llenan toda la imagen. |
| `Islas_3.png` (mapa) | ✏️ Rehacer | La tormenta de cristal: las mismas islas de noche bajo una tormenta azul, rayos, nubes oscuras que llenan el cielo, cristales flotando y un río de luz que sube entre las islas hacia la más alta. |
| `mini_sky_familiar.png` + poses | ✅ Mantener | Familiar del cielo: criatura alada azul y blanca. |

### Mundo 4 · Volcán

Historia: el volcán está despertando y amenaza con cubrirlo todo de ceniza; el
Titán del Volcán protege su corazón. Al apagarlo aparece el Devorador de
Palabras.

| Imagen | Estado | Descripción para añadir al bloque de estilo |
|---|---|---|
| `Volcan_1.png` (mapa) | ✏️ Rehacer | Ladera de un volcán que despierta: suelo de roca negra y ceniza que llena toda la imagen, grietas finas de lava naranja, columnas de humo, árboles quemados, y runas antiguas grabadas en el sendero que brillan en turquesa. Arriba, a lo lejos, la cima del volcán echando humo. |
| `Volcan_2.png` (mapa) | ✏️ Rehacer | El río de magma: rocas negras cortadas por ríos de lava naranja brillante, puentes de piedra con runas turquesa, columnas de humo y ceniza en el aire, todo hasta los bordes de la imagen. |
| `Volcan_3.png` (mapa) | ✏️ Rehacer | El corazón del volcán: dentro del cráter en erupción, lava por todas partes, cielo rojo, chispas y el esqueleto de una criatura gigante junto al sendero. El capítulo más peligroso del volcán. |
| `mini_lava_salamander.png` + poses | ✅ Mantener | Salamandra de lava con escamas negras y grietas naranjas. |

### Mundo 5 · Desierto de las Runas (nuevo)

**Historia:** al apagarse el volcán aparece el **Devorador de Palabras**, un ser
que roba el conocimiento de los mundos y deja las runas en blanco. El jugador lo
persigue por el desierto hasta su fortaleza en el glaciar, donde es el jefe final.

| Imagen | Estado | Descripción para añadir al bloque de estilo |
|---|---|---|
| `Desierto_1.png` (mapa) | 🆕 Nuevo | Dunas doradas con columnas caídas cubiertas de runas que brillan en turquesa; un oasis pequeño abajo. |
| `Desierto_2.png` (mapa) | 🆕 Nuevo | Ruinas de una ciudad antigua medio enterrada en la arena, arcos y escaleras con letras grabadas. |
| `Desierto_3.png` (mapa) | 🆕 Nuevo | Templo gigante en la arena bajo una tormenta de arena, con runas apagándose (el Devorador ya pasó). |
| `mini_sand_scarab.png` + poses | 🆕 Nuevo | **Escarabajo de arena**: escarabajo grande con caparazón dorado lleno de runas turquesa, patas de bronce, ojos grandes y amistosos-pícaros. Ataca lanzando arena. **Mirando a la IZQUIERDA** (en todas las poses). |
| `flyer_w5_1/2.png` | 🆕 Nuevo | **Halcón de arena**: halcón dorado con plumas que se deshacen en arena, alas arriba / alas abajo. **Mirando a la IZQUIERDA** (en todas las poses). |

### Mundo 6 · Glaciar Eterno (nuevo)

| Imagen | Estado | Descripción para añadir al bloque de estilo |
|---|---|---|
| `Glaciar_1.png` (mapa) | 🆕 Nuevo | Llanura helada con lagos congelados, pinos nevados y auroras verdes y violetas en el cielo. |
| `Glaciar_2.png` (mapa) | 🆕 Nuevo | Cuevas de hielo azul con puentes de hielo y letras congeladas dentro de los bloques. |
| `Glaciar_3.png` (mapa) | 🆕 Nuevo | Fortaleza de hielo oscuro del Devorador de Palabras, con libros congelados y runas apagadas. |
| `mini_frost_yeti.png` + poses | 🆕 Nuevo | **Yeti de escarcha**: yeti pequeño y robusto, pelaje blanco-azulado, cristales de hielo en hombros, bufanda turquesa. Ataca con bolas de nieve. **Mirando a la IZQUIERDA** (en todas las poses). |
| `flyer_w6_1/2.png` | 🆕 Nuevo | **Búho de hielo**: búho blanco con plumas de cristal de hielo, alas arriba / alas abajo. **Mirando a la IZQUIERDA** (en todas las poses). |
| `word_devourer.png` + poses | 🆕 Nuevo | **El Devorador de Palabras** (jefe final): criatura de sombra con capa hecha de páginas arrancadas, letras que flotan hacia su boca, ojos violetas. Imponente pero no terrorífico (13+). **Mirando a la IZQUIERDA** (en todas las poses). |

---

## 6. Iconos propios (sustituyen a los emojis)

```
Estilo: icono de videojuego móvil, objeto único, vista frontal ligeramente
inclinada, colores vivos, acabado brillante, contorno oscuro fino, brillo
dorado/turquesa. PNG con fondo TRANSPARENTE, 512 x 512 px, centrado, sin texto.
```

| Archivo | Objeto |
|---|---|
| `icon_coin.png` | Moneda de oro con una runa grabada |
| `icon_gem.png` | Gema turquesa tallada |
| `icon_potion.png` | Poción roja en frasco de cristal |
| `icon_hint.png` | Bombilla mágica con brillo turquesa |
| `icon_heart.png` | Corazón rojo brillante (vidas) |
| `icon_star.png` | Estrella dorada |
| `icon_trophy.png` | Copa dorada |
| `icon_key.png` | Llave dorada antigua |
| `icon_chest.png` | Cofre de madera con herrajes dorados |
| `icon_xp.png` | Libro abierto con brillo (experiencia) |

Carpeta: `assets/images/icons/`.

---

## 7. Lista de imágenes a rehacer (prioridad)

1. Mapas a imagen completa: `Bosque_1`, `Bosque_3`, `Cavernas_1`, `Islas_1`, `Volcan_1` (bloque de la sección 3 + su descripción de la sección 5).
2. Iconos propios (sección 6).
3. `adventurer.png`: el explorador de los luchadores, de cuerpo entero, mirando a la **derecha** (está a la izquierda de la portada), sujetando un libro mágico que brilla.
4. `dragon.png`: dragón violeta en el estilo de los monstruos, mirando a la **izquierda**, alas abiertas.
5. Mundos 5 y 6 completos (sección 5).
6. Opcional: versiones más cubiertas de la maga y la guardiana (luchadores y avatares).

### ¿En qué carpeta va cada imagen nueva?

| Imágenes | Carpeta |
|---|---|
| Mapas `Desierto_1/2/3.png`, `Glaciar_1/2/3.png` | `assets/images/maps/` |
| `mini_sand_scarab.png`, `mini_frost_yeti.png`, `word_devourer.png` **y todas sus poses** | `assets/images/monsters/` |
| `flyer_w5_1/2.png`, `flyer_w6_1/2.png` | `assets/images/flyers/` |
| Iconos `icon_*.png` | `assets/images/icons/` |
| Mapas rehechos de los mundos 1-4, `adventurer.png`, `dragon.png` | `assets/images/` (sustituyen a los actuales, mismo nombre) |

Mientras una imagen nueva no esté, el juego usa otra de reserva (por ejemplo,
el mapa del volcán para el desierto), así que se pueden ir subiendo de a poco.

**Formato en el juego:** los mapas y el fondo `bg_landscape` se guardan en
**JPG** (pesan 4 veces menos; no tienen transparencia). Si un mapa nuevo llega
en PNG, se convierte a JPG con el mismo nombre antes de usarlo.

**Al terminar, súbelas a GitHub (o pásamelas) y yo las reviso.** Ajusto tamaños,
recortes y nombres por código para que encajen sin "saltos".
