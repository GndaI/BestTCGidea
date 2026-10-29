# Web export verification

- Export this project with the Godot 4.7.2 console executable using normal host permissions. A sandboxed export can exit with code 0 while producing a damaged `build/web/index.pck` because its temporary `project.binary` could not be written.
- Treat messages such as `Safe save failed`, `Can't open ... tmpproject.binary`, or `Corrupted header in binary project.binary` as export failure even when the process exit code is 0.
- After every Web export, serve `build/web`, open the actual browser URL, confirm that the TWELVE main menu appears, and check that the browser console has no `.pck` or project-data loading error.
- The local and public server already sends `Cache-Control: no-store`; source changes still require a new Web export, followed by a browser reload or `Ctrl+F5`.
