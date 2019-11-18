# Docker Service for macOS

This repository contains the source code for an installer package that
installs Docker, Docker Compose, and Docker Machine. Unlike Docker Desktop,
this package also configures the Docker service to start at boot time, so that
any services contained in Docker containers will also be available at boot time.
(Docker Desktop requires an interactive user login before it will start its
copy of the Docker service).

This repository is licensed under MIT. The code installed may be covered under
other licenses; this README will be updated once I have specifics.
