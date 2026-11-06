# 🏖️ Chiringuito Must Be Paid — GDD & Plan de Implementación

> **Autor:** Suko-Dev20  
> **Motor:** Godot Engine 4.x (GDScript)  
> **Género:** Incremental activo por rondas (*Run-based Active Incremental*) inspirado en *Bills Must Be Paid*.

---

## 1. Concepto y Fantasía Principal
Estás de vacaciones en la playa con la familia y la cuenta del **Chiringuito** no para de subir. Tu única forma de sobrevivir financieramente es bajar a la orilla con tus juguetes de playa (**Pala, Cubo y Rastrillo**), atrapar bichos marinos que cargan con monedas perdidas por turistas de todo el mundo, cambiar esas divisas a **Euros (€)** en la Caseta de Cambio y pagar las comandas antes de que os echen de la playa.

---

## 2. Mecánicas Principales

### 2.1. Controles y Herramientas en la Orilla (Ronda Activa)
| Acción / Input | Herramienta | Mecánica Principal | Coste de Stamina |
| :--- | :--- | :--- | :--- |
| **Clic Izquierdo** | **Pala de Playa** | Golpe rápido y directo sobre un punto pequeño. Ideal para cangrejos individuales y críticos. | Bajo por golpe |
| **Clic Derecho** *(Cooldown)* | **Cubo de Playa** | Golpe pesado que aplasta/atrapa en un **área circular grande**. | Medio-Alto por uso |
| **Mover el Cursor** *(Pasivo)* | **Rastrillo** | Al pasar el ratón cerca de las monedas caídas en la arena, el rastrillo las barre y las recoge. | No gasta Stamina |
| **Tecla Espacio / Botón** *(Cooldown)* | **🚜 El Tractor Limpia-Playas** | Un tractor cruza toda la pantalla aplanando la arena y **recogiendo todas las monedas** del tablero. | Sin coste (Cooldown) |

### 2.2. Economía: Divisas de Turistas y Caseta de Cambio
* **💶 Euros (€):** Moneda principal para pagar el Chiringuito y mejoras básicas.
* **💵 Dólares ($), 💷 Libras (£), 💴 Yenes (¥), 🪙 Soles (S/):** Monedas soltadas por bichos según el nivel de turismo internacional. Se cambian a Euros en la Caseta de Cambio entre rondas.

### 2.3. Helados de Kiosco (Pasivos basados en Suerte)
* **🦶 "Pie Helado":** Probabilidad al atrapar un bicho de refrescarte y recuperar Stamina.
* **🚀 "Cohete Tricolor":** Probabilidad al dar un palazo de lanzar una onda expansiva o velocidad extra.
* **🧛 "Conde Colmillos":** Probabilidad en golpe crítico de curar Stamina y duplicar monedas.
* **🍫 "Bombón Magnético":** Probabilidad de recoger monedas automáticamente con valor doble.
* **🦈 "Tiburón Azul":** Probabilidad de reducir el *cooldown* del Tractor Limpia-Playas.

---

## 3. Plan de Implementación y Hoja de Ruta (Issues & Draft PRs)

> **Flujo de trabajo en GitHub:** Cada tarea de esta lista tendrá su propio **Issue** en GitHub y se desarrollará en una rama dedicada (`feat/issue-X-...`) abriendo un **Draft Pull Request** antes de fusionar a `main`.

### Fase 1: Prototipo Base de la Orilla (✅ Completado en `main`)
- [x] Configuración inicial de Godot 4 (`project.godot`, resolución 1280x720).
- [x] Autoload `GameState` con divisas (`EUR`, `USD`, `GBP`, `PEN`), días y facturas.
- [x] Ronda activa en `beach_round.gd` con Pala (Clic Izq), Cubo (Clic Der), Rastrillo (imán de monedas), Tractor Limpia-Playas (`Espacio`) y sistema de Críticos/Multigolpe.

### Fase 2: Pantalla Entre Rondas (Árbol de Habilidades, Caseta y Chiringuito) (✅ Completado)
- [x] **Issue #1:** Crear escena entre rondas (`between_days.tscn`) con la **Caseta de Cambio de Divisas** interactiva y el pago de facturas del **Chiringuito** cada 3 días.
- [x] **Issue #2:** Implementar el **Árbol de Habilidades interactivo** (4 ramas: Herramientas/Críticos, Playa/Tractor, Kiosco de Helados/Suerte, Turismo/Divisas) con compra de mejoras conectada a `GameState`.

### Fase 3: Variedad de Fauna Marina y Comportamientos (✅ Completado)
- [x] **Issue #3:** Nuevos tipos de bichos en la playa: **Almeja/Coquina** (se entierra rápido si no la golpeas), **Pulpo Turista** (tanque para usar el Cubo, suelta explosión de divisas) y **Langosta Dorada** (rápida, alto valor).
- [x] **Issue #4:** Sistema de olas dinámicas en la orilla (las olas traen nuevos bichos y arrastran las monedas que lleven mucho tiempo en la arena si no usas el rastrillo o el tractor).

### Fase 4: Kiosco de Helados y Sinergias de Suerte (✅ Completado)
- [x] **Issue #5:** Implementar la Nevera de Helados y los efectos pasivos por probabilidad (*Cohete Tricolor*, *Conde Colmillos*, *Bombón Magnético*, *Tiburón Azul*) + estadística global de Suerte.

### Fase 5: Ciclo de Bancarrota, Prestigio y Guardado (✅ Completado)
- [x] **Issue #6:** Sistema de **Fin de Veraneo (Prestigio / Bancarrota)** cuando no llegas a pagar el Chiringuito: obtención de *Conchas Doradas* y tienda de mejoras permanentes.
- [x] **Issue #7:** Sistema de Guardado y Carga automática en disco (`user://savegame.json`).

### Fase 6: Arte, "Juice" (Game Feel), Audio y Steam (✅ Completado)
- [x] **Issue #8:** *Game Feel* y Jugosidad: *Screen shake* en críticos y cubazos, partículas de arena/agua, sonidos con variación de *pitch* (`AudioStreamWAV`) y detalles 2D.

---

## 4. Milestone 2 — Expansión de Profundidad y Pulido para Steam (✅ Completado)

### Fase 7: Automatización Playera (Ayudantes y Gadgets) (✅ Completado)
- [x] **Issue #17:** Añadir ayudantes autónomos en la playa: **👦 Sobrino Entusiasta** (camina hacia los bichos y los golpea sin gastar Stamina), **🐦 Gaviota Amaestrada** (vuela hacia las monedas sueltas antes de que se las lleve la ola) y **🕸️ Nasa de Cangrejos** (ralentiza un 50% y daña por segundo en área).

### Fase 8: Mercado de Divisas Dinámico (Bolsa Turística) (✅ Completado)
- [x] **Issue #18:** Fluctuación diaria de tasas de cambio (`📈 ALZA` / `📉 BAJA`) y botones de conversión individual por divisa (`USD`, `GBP`, `PEN`) para especular con el mejor día de venta.

### Fase 9: Árbol de Habilidades Visual (Grafo de Nodos con Pan/Zoom) (✅ Completado)
- [x] **Issue #19:** Transformar la lista de mejoras en un mapa visual de nodos conectados por líneas arrastrable con el ratón (*Pan*) y tooltips interactivos.

### Fase 10: Menú Principal y Opciones de PC/Steam (✅ Completado)
- [x] **Issue #20:** Escena `main_menu.tscn`, ajustes de Volumen Master y selector de Pantalla Completa (`F11`).

---

## 5. Milestone 3 — Postales de Veraneo, Eventos Playeros y Álbum de Colección (✅ Completado)

### Fase 11: Sistema de Logros ("Postales de Veraneo") y Recompensas (✅ Completado)
- [x] **Issue #25:** Catálogo de 8 Postales de Veraneo desbloqueables con notificación *Toast* en tiempo real y recompensa directa de `+1 🐚 Concha Dorada`.

### Fase 12: Eventos Especiales de Playa en mitad de la ronda (✅ Completado)
- [x] **Issue #26:** Eventos sorpresa positivos en mitad de la jornada (*Fiebre Turística*, *Bajamar de Coquinas*, *Brisa Marina*).

### Fase 13: Álbum de Postales y Estadísticas Globales (✅ Completado)
- [x] **Issue #27:** Pestaña interactiva de Álbum de Postales y registro histórico de estadísticas en el Paseo Marítimo y Menú Principal.
