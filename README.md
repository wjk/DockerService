# Docker Service for macOS

This repository contains the source code for an installer package that
installs Docker and Docker Machine. (Docker Compose is not included due to a
Python 3 dependency, and must be installed separately.)

Unlike Docker Desktop, this package also configures the Docker service to start
at boot time, so that any services contained in Docker containers will also be
available at boot time. (Docker Desktop requires an interactive user login before
it will start its copy of the Docker service).

This repository is licensed under the Mozilla Public License, version 2.0.
The code installed is covered under other licenses; they can be found in
the `bundle/licenses` folder.
