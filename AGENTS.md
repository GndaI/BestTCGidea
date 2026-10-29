# Native-first export verification

- Treat the Godot project as the source of truth. Windows Desktop is the primary release target; Web remains a secondary build from the same source.
- Export the Windows release to `build/windows/TWELVE.exe`, launch the exported executable, and confirm the main menu appears before publishing it.
- Keep generated contents under `build/` out of Git. Publish Windows builds through a GitHub Release rather than committing binaries to the repository.

- Export this project with the Godot 4.7.2 console executable using normal host permissions. A sandboxed export can exit with code 0 while producing a damaged `build/web/index.pck` because its temporary `project.binary` could not be written.
- Treat messages such as `Safe save failed`, `Can't open ... tmpproject.binary`, or `Corrupted header in binary project.binary` as export failure even when the process exit code is 0.
- After every Web export, serve `build/web`, open the actual browser URL, confirm that the TWELVE main menu appears, and check that the browser console has no `.pck` or project-data loading error.
- The local and public server already sends `Cache-Control: no-store`; source changes still require a new Web export, followed by a browser reload or `Ctrl+F5`.
