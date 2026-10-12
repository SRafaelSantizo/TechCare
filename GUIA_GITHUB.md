# Trabajar los tres con GitHub Desktop

El repositorio guardará scripts SQL, diagramas, documentación y después el código
de la aplicación. Cada integrante ejecutará los scripts en su propia instancia
de SQL Server. Una modificación realizada en SSMS debe quedar también escrita
en un archivo SQL y guardada en el repositorio para que los otros la apliquen.

## Publicación inicial: la realiza una sola persona

1. Los tres crean su cuenta de GitHub e instalan [GitHub Desktop](https://desktop.github.com/).
2. Quien publicará inicia sesión en Desktop y elige File > New repository.
3. Nombre: `TechCare`. Seleccionar la ubicación local y crear el repositorio.
4. Abrir la carpeta creada. Copiar dentro el contenido descomprimido de
   `TechCare_BD`: los SQL, README, guías, diagramas, PDF, JSON, `.gitignore` y
   `.gitattributes`. Los archivos del proyecto quedan en la raíz de TechCare.
5. En Desktop revisar los cambios, escribir `Base inicial de TechCare` y hacer
   Commit. Luego Publish repository, mantener seleccionado Keep this code
   private y confirmar Publish repository.

El paquete ya incluye `.gitignore` para configuraciones locales, archivos de base
de datos y resultados de compilación. El README del paquete explica su ejecución.

## Invitar a los otros dos

En GitHub abrir el repositorio > Settings > Collaborators > Add people.
Buscar los nombres de usuario exactos de los compañeros y enviar la invitación.
Cada uno la acepta con su propia cuenta.

## Descargar el proyecto: cada integrante

En Desktop elegir File > Clone repository. Seleccionar TechCare, elegir su
carpeta local y confirmar Clone. Si todavía no aparece, usar la pestaña URL con
la dirección del repositorio. Ejecutar los SQL según el README en su SQL Server.

## Trabajo diario con ramas

`main` contiene la versión integrada. Cada tarea usa una rama con un nombre
concreto, por ejemplo `rafa/validacion-pagos` o `frontend/ordenes`.

1. Cambiar a main, hacer Fetch origin y Pull origin cuando haya cambios remotos.
2. Desde Current branch crear una nueva rama para la tarea.
3. Editar los archivos, guardar y comprobar el cambio.
4. En Desktop revisar el diff, escribir un resumen y hacer Commit to esa rama.
5. Hacer Publish branch o Push origin, según muestre Desktop.
6. Abrir Preview Pull Request y Create Pull Request con main como destino.
7. Otro integrante revisa los cambios y las pruebas; integrar mediante Merge.
8. Volver a main y descargar la versión integrada antes de iniciar la tarea siguiente.

## Qué significa cada paso

| Término | Significado |
|---|---|
| Repositorio | Carpeta del proyecto con historial de versiones. |
| Clone | Descargar el repositorio y su historial para trabajar localmente. |
| Rama | Línea de trabajo para una tarea. |
| Commit | Guardar una versión local con un mensaje. |
| Push | Subir los commits al repositorio remoto. |
| Fetch / Pull | Consultar y descargar cambios remotos. |
| Pull request | Proponer que una rama se integre con otra. |
| Merge | Integrar los cambios revisados. |

## Acuerdos del equipo

- Una persona coordina modificaciones del maestro SQL y del modelo; los otros
  proponen cambios mediante ramas y pull requests.
- Cada cambio de estructura debe actualizar SQL, modelo y documentación.
- Para bases existentes, registrar el cambio en un script de migración, como
  `05_Actualizar_Triggers.sql`; también actualizar el maestro para instalaciones nuevas.
- Indicar en el pull request qué se cambió y qué se probó en SQL Server.
- Resolver conflictos leyendo ambas modificaciones y comprobando el resultado.
- Mantener en main una versión que los tres puedan instalar y demostrar.
- Guardar las credenciales reales de conexión en la configuración local prevista.

## Fuentes oficiales

- [Crear y publicar un repositorio con Desktop](https://docs.github.com/en/desktop/overview/creating-your-first-repository-using-github-desktop).
- [Invitar colaboradores](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/repository-access-and-collaboration/inviting-collaborators-to-a-personal-repository).
- [Agregar y clonar repositorios](https://docs.github.com/en/desktop/adding-and-cloning-repositories).
- [Crear un pull request desde Desktop](https://docs.github.com/en/desktop/working-with-your-remote-repository-on-github-or-github-enterprise/creating-an-issue-or-pull-request-from-github-desktop).
