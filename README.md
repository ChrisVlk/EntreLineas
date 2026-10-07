# Entre líneas

Aplicación educativa para aprender programación comparando código entre **PSeInt, Python, JavaScript y C**, con un traductor abierto y salas de ejercicios sin registro.

**Aplicación publicada:** https://entre-lineas-classroom.vercel.app/

## Funcionalidades

- Editor de origen y resultado lado a lado, con selección de lenguajes e inversión de la traducción.
- Consola educativa con Ejecutar, Detener, Limpiar y entrada interactiva de datos.
- Práctica libre sin cuentas ni necesidad de pertenecer a una sala.
- Cualquier visitante puede crear una sala y compartir su código único o enlace.
- Los participantes entran con su nombre; no se solicitan correos ni acceso con Google.
- El anfitrión crea ejercicios, publica enunciados y código inicial, fija fechas límite y revisa entregas.
- Los borradores son privados. Al entregar una solución, queda cerrada para edición y disponible para revisión.
- Calificaciones, comentarios, retirada de participantes y archivo de salas.

## Tecnologías

| Parte | Implementación actual |
| --- | --- |
| Interfaz | React, TypeScript y Vite |
| Editor | CodeMirror |
| Traducción | Analizador y generadores locales en JavaScript |
| Datos y permisos | Supabase PostgreSQL, funciones SQL y políticas RLS |
| Publicación | Vercel |
| Pruebas | Node Test Runner y PostgreSQL local con PGlite |

Esta versión no contiene un servidor Django ni requiere Render. Las operaciones de salas se realizan mediante la API de Supabase y las reglas de acceso de PostgreSQL.

## Ejecutar en local

Requisitos: Node.js 24 y npm.

```sh
npm ci
```

Copia `.env.example` a `.env.local` y completa los valores de tu proyecto:

```dotenv
VITE_SUPABASE_URL=https://TU_PROYECTO.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICABLE
```

Las variables `VITE_` se incluyen en el navegador. Usa exclusivamente la clave publicable; nunca una clave secreta o `service_role`. `.env.local` está excluido de Git.

```sh
npm run dev
```

Abre la dirección que indique Vite, normalmente `http://127.0.0.1:5173/`. El traductor funciona sin configurar Supabase; las salas requieren la base de datos y las variables anteriores.

## Preparar una base de datos nueva

En un proyecto nuevo de Supabase, ejecuta estos archivos SQL **una sola vez y en este orden**:

1. `supabase/schema.sql`: esquema inicial e historial de permisos.
2. `supabase/multilanguage.sql`: lenguajes de origen y destino para ejercicios y entregas.
3. `supabase/guest-rooms.sql`: acceso sin cuentas, códigos de sala y permisos del modelo actual.

Los dos primeros archivos conservan el diseño histórico; el tercero elimina las invitaciones institucionales y sustituye la identidad de cuentas por accesos de navegador. No ejecutes nuevamente estos scripts sobre la base publicada. La transición a invitados fue diseñada para la base inicial vacía; si adaptas una instalación con datos, prepara antes una migración de identidades específica.

No se necesita activar proveedores de inicio de sesión. Mantén el esquema `private` fuera de los esquemas expuestos por la API.

## Cómo se usa

### Práctica libre

Escribe código, selecciona origen y destino y compara el resultado. Descarga el código para conservarlo antes de cerrar la página: el laboratorio libre no guarda automáticamente su contenido.

### Salas

1. El anfitrión pulsa **Crear una sala**, escribe su nombre y los datos del grupo.
2. Comparte el código de 10 caracteres o el enlace generado.
3. El participante abre el enlace o introduce el código, escribe su nombre y entra.
4. El anfitrión publica ejercicios y el participante guarda borradores o entrega su solución.
5. El anfitrión revisa las entregas y añade calificaciones y comentarios.

Los nombres deben ser distintos dentro de una sala. El código compartido concede acceso como participante, nunca como anfitrión. Archivar una sala impide nuevas entradas y entregas, conservando la consulta de los trabajos.

## Identidad y privacidad

Cada navegador genera una clave aleatoria de 256 bits al usar las salas. La clave se conserva localmente y la base de datos almacena su hash. Los permisos se validan en PostgreSQL; el nombre visible no acredita propiedad ni recupera trabajos.

**Si borras los datos del sitio, cierras la navegación privada o cambias de navegador/dispositivo, pierdes el acceso anterior.** Usa un navegador personal para conservarlo. Actualmente no hay recuperación ni sincronización de identidad entre dispositivos.

Las salas no aparecen en un listado público. Cada acceso consulta sus propias salas y trabajos; los anfitriones solo pueden leer soluciones entregadas. Hay límites por acceso para intentos de entrada y creación de salas. Estos límites y la retirada de participantes no impiden que una persona genere un nuevo acceso desde otro navegador; no son una verificación de identidad personal.

## Alcance de la traducción

El traductor está orientado a ejercicios introductorios: variables, expresiones, entrada/salida, decisiones y bucles compatibles. La consola interpreta el código de origen normalizado al subconjunto educativo en un Web Worker; no es un compilador nativo ni un entorno completo de Python, JavaScript o C. No utiliza eval ni ofrece acceso a la red, archivos o APIs del navegador desde el programa. Las construcciones no admitidas, como funciones o estructuras avanzadas, deben producir un diagnóstico en lugar de un resultado aparentemente equivalente. Consulta la guía del editor para ejemplos y limitaciones.

## Consola de ejecución

Pulsa **Ejecutar** debajo del editor para ver la salida. Cuando el programa solicite un dato, escribe su valor y pulsa **Enviar dato**. Los datos numéricos y lógicos se validan antes de continuar. **Detener** cancela la ejecución y **Limpiar** vacía la consola.

Cada ejecución usa una copia del código de origen al pulsar el botón. Si lo editas después, se indica que la salida corresponde a la versión anterior. La consola también está disponible en ejercicios y al consultar entregas, sin modificar ni enviar soluciones.

La ejecución tiene límites de 100 000 pasos, 100 000 caracteres de salida y 5 segundos de cálculo por tramo entre entradas. Esperar una respuesta del usuario no consume ese tiempo. El intérprete usa números de JavaScript y comprueba enteros fuera del rango seguro; no reproduce todos los detalles numéricos o de formato de los compiladores nativos.

## Pruebas y compilación

```sh
npm test
npm run build
npm run preview
```

Las pruebas verifican combinaciones de traducción, diagnósticos y permisos de salas: acceso por código, propiedad, borradores privados, entregas, calificaciones y retirada. PGlite ejecuta las pruebas SQL localmente sin modificar Supabase remoto.

## Publicar en Vercel

Importa este repositorio usando el preset **Vite**, el comando `npm run build` y el directorio de salida `dist`. Configura las dos variables de `.env.example` para el entorno de despliegue. `vercel.json` contiene la configuración de compilación y encabezados HTTP.

La aplicación enlazada arriba ya está publicada. Subir este repositorio a GitHub no enlaza automáticamente el proyecto de Vercel existente ni cambia su configuración de despliegue.

## Estructura

```text
src/
  App.tsx             Traductor abierto y entrada a salas
  Room.tsx            Ejercicios, participantes, entregas y revisión
  Editor.tsx          Editor y visualización de traducciones
  lib.ts              Cliente de datos y acceso privado de navegador
  translator.js       Analizador y generación desde PSeInt
  multilang.js        Adaptación de los otros lenguajes
supabase/             Esquema SQL y evolución de permisos
tests/                Pruebas de traducción y autorización
public/               Recursos estáticos
```

El repositorio incluye código fuente, archivos SQL, pruebas, configuración y dependencias fijadas en `package-lock.json`. Excluye dependencias instaladas, compilaciones generadas, claves locales y archivos temporales.
