title: Farpoint HORIZON · presentación
footer: Farpoint HORIZON · SK-Horizons · NASA Space Apps Challenge 2026 · Sangolquí
<!-- Mazo en español: el del pitch en vivo (la sede lo pide en español) y la versión ES de los entregables. Debe ir
     diapositiva por diapositiva igual que en.md. Las notas son el guion hablado: 5 minutos en total.
     Formato y reglas: spaceapps/local-pitch/source/README.md. Generar: (script no longer in the repository) -->

---
layout: cover
label: NASA Space Apps Challenge 2026 · Space Mission Design Game

# Farpoint HORIZON
> Construye tu nave, lánzala desde la línea ecuatorial, llévala a la Luna y mantenla hablando con la Tierra.
**Equipo SK-Horizons** · Quito, Ecuador · Sede Sangolquí (ESPE)
Alexander Kholodov · Sebastian Amaguaya

Notas:
(15 s) Somos SK-Horizons, de Quito. Elegimos el reto "Space Mission Design Game". Farpoint HORIZON es un juego donde
tú construyes tu propia nave, la lanzas desde el Ecuador y la llevas hasta la Luna.

---
layout: split
label: El problema
image: assets/photos/volcano_watch/sangay_landsat8_2022-11-05_truecolor.jpg | El Sangay visto por Landsat 8 (2022). Cada imagen así es el final de una cadena de decisiones difíciles. NASA Earth Observatory / USGS [S-eo]

## El diseño de misiones se enseña como lista, no se vive como historia
- Una misión real equilibra **masa, energía, datos, delta-v, presupuesto y tiempo**; en una pizarra esos compromisos no se ven.
- Se aprenden las órbitas como fórmulas, nunca como una nave propia que se lanzó y se mantuvo viva.
- Ecuador puso su primer satélite en órbita en 2013 (NEE-01 Pegaso, un CubeSat 1U [S-pegaso]); la siguiente generación necesita una puerta de entrada.
> Ningún diseño es perfecto. El reto pide que el jugador lo sienta.

Notas:
(35 s) Esta imagen del Sangay la tomó un satélite. Para que exista, alguien decidió la órbita, la energía, cuántos
datos bajar y cuánto costaba. Eso se enseña como teoría. Ecuador ya tuvo su Pegaso en 2013: queremos que más gente
viva esas decisiones.

---
layout: wide
label: La solución · cómo se juega
image: shot: el diseño de la nave, una opción elegida y los indicadores moviéndose (scripts/screens/design.gd) | 1 · Diseña: diez preguntas, partes reales
image: shot: el constructor de cohetes con una pila y su delta-v por etapa (scripts/screens/builder.gd) | 2 · Construye el cohete
image: shot: el despegue junto al Cotopaxi, con la velocidad del tiempo a la vista | 3 · Lanza desde el Ecuador
image: shot: órbita lunar o alunizaje, la celebración | 4 · Llega, opera, celebra

## Una misión completa, de la idea a la primera señal
flow: Elige una misión -> Diseña la nave (CML 1-4) -> Construye el cohete -> Lanza -> Vuela al destino -> Opera con control de tierra -> Celebra
Cada decisión mueve los indicadores compartidos y se ve en la nave. No alcanzar una meta nunca es pantalla de fracaso: toda misión que vuela logra algo, y hacer más da bonos. Cuatro estaciones para hasta cuatro jugadores (ingeniería, ciencia, piloto, control de tierra), con bots en las libres.

Notas:
(60 s) Demo en vivo si la sala lo permite; si no, estas cuatro imágenes. Contar una misión de punta a punta.
Demo: el video de 29 segundos del repositorio o estas imágenes.

---
layout: split
label: Datos de la NASA en el centro
image: assets/photos/moon_south_pole/south_pole_wide_lroc_wac.jpg | Polo sur de la Luna, mosaico de la cámara gran angular de LRO, reproyectado por nuestro script [S-lroc-wac]

## Datos reales de la NASA mueven la física
- **JPL Horizons**: dónde está la Luna el día del lanzamiento; el viaje se sincroniza para encontrarla [S-horizons].
- **NSSDC Fact Sheets**: masa, radio y gravedad de cada cuerpo [S-nssdc-planets].
- **GIBS, Landsat, ASTER, LRO, SRTM**: la Tierra, los volcanes del Ecuador y la Luna [S-gibs] [S-eo].
flow: APIs de la NASA -> `tools/content/data/` -> `data/nasa/*.json` -> física y texturas
### Comprobado, no ajustado
Nuestro cohete tipo Electron sube **313 kg** a órbita baja (real: 300 kg); la cima del Cotopaxi sale a **5.876 m** (publicada: 5.897 m).

Notas:
(55 s) Nombrar cada dataset y decir dónde actúa: Horizons decide cuándo salir hacia la Luna; las fichas del NSSDC dan
la gravedad; las imágenes son las que el jugador ve y fotografía. Un script descarga, otro convierte, el juego lee.
Y lo comprobamos contra la realidad sin hacer trampa. (RCD 1.1-1.3)

---
layout: split
label: Tecnología · el juego funcionando
image: shot: el menú o las tarjetas de misión en la versión web, con el navegador a la vista | Se juega en el navegador: farpoint-horizon.web.app

## Hecho para correr donde haya un navegador
- **Godot 4.7**, renderizador GL Compatibility: corre en GPUs integradas y en el navegador; versión de escritorio como respaldo.
- **Datos aparte del código**: misiones, partes, cohetes y textos viven en `data/*.json`, cada valor con su fuente.
- **Comportamiento real**: gravedad de cada cuerpo, constantes reales; el tiempo corre real y el jugador lo acelera a la vista (×1, ×10, ×100).
- **Revisado en cada cambio**: importación, una corrida sin pantalla, una prueba de estrés y la exportación web.
### Juégalo
Juego: farpoint-horizon.web.app (versión publicada) · historia v0.3.0: https://farpoint-horizon--pr93-v0-3-0-a59yjofm.web.app · repositorio: github.com/alexanderkholodov1/farpoint-horizon/tree/v0.3.0 (MIT)

Notas:
(45 s) La arquitectura en una frase, después el enlace. (IET 2.1-2.5)

---
layout: split
label: Impacto · siguientes pasos
image: assets/photos/volcano_watch/cotopaxi_landsat8_2015-09-15_truecolor.jpg | El Cotopaxi desde Landsat 8 (2015): la misión "Ecuador Volcano Watch" lo sobrevuela [S-eo]

## De los volcanes del Ecuador a la Luna, en español e inglés
- **Para** estudiantes, docentes y curiosos: sin instalar nada, cada concepto explicado en palabras simples.
- **Local**: lanzar desde el Ecuador (el giro de la Tierra regala velocidad), vigilar el Cotopaxi y el Sangay, seguir El Niño.
- **Misiones**: las seis misiones de la NASA (Apolo 13, STS-61, Mars Pathfinder, LCROSS, DART, Artemis I) y los escenarios libres: Ecuador Volcano Watch, Ocean Guardians y El Niño, Lunar Cartographer, Eye on the Universe, Ice at the Moon's South Pole y modo libre.
### Después del hackathon
- Una campaña con historia; jugar con hasta tres amigos en línea.
- Pilotos en aulas del Ecuador planeados; sin aliado confirmado todavía.

Notas:
(45 s) A quién sirve, por qué encaja en el Ecuador y un camino realista para seguir. (IR 3.1-3.5)

---
layout: split
label: Transparencia · créditos · equipo
image: shot: la película de créditos sobre la Tierra, o la lista de fuentes en el juego (scripts/screens/credits.gd) | Cada fuente está en los créditos del juego

## Nuestro trabajo, nuestras fuentes, nuestra ayuda
- **Hecho por nosotros**: el juego, sus modelos 3D (de nuestros scripts), música y sonidos. **Ninguna imagen hecha con IA.**
- **Citado**: todas las fuentes de `docs/sources.md`, en el repositorio y en los créditos del juego. Sin logos de la NASA.
- **IA declarada**: Claude Code (código, investigación), Antigravity y Cursor (código y una prueba web); Meshy y TRELLIS (referencias 3D; ver "Uso de IA" en el README). La idea y el diseño son nuestros.
### Equipo SK-Horizons
- **Alexander Kholodov**: la misión y el vuelo a la Luna.
- **Sebastian Amaguaya**: el constructor de cohetes, modelos 3D, imagen y sonido.

Notas:
(25 s) Cierre: qué es nuestro, qué no, y gracias. Invitar al jurado a jugar. (RCD 1.5)
