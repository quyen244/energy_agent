FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# --- System dependencies for MATLAB Runtime ---
RUN apt-get update && apt-get install -y \
    wget unzip xorg \
    libxext6 libx11-6 libglu1-mesa libxi6 libxtst6 libxrender1 \
    libxrandr2 libxinerama1 libxcursor1 libxcomposite1 libxdamage1 \
    libfontconfig1 libxss1 libasound2 \
    python3.10 python3.10-distutils python3-pip \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt /tmp/requirements.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

WORKDIR /opt/mcr

# --- Download & Install MATLAB Runtime silently ---
RUN wget -q https://ssd.mathworks.com/supportfiles/downloads/R2025a/Release/0/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2025a_glnxa64.zip \
    && unzip -q MATLAB_Runtime_R2025a_glnxa64.zip -d mcr_install \
    && rm MATLAB_Runtime_R2025a_glnxa64.zip \
    && mcr_install/install -mode silent -agreeToLicense yes -destinationFolder /opt/mcr -logfile /tmp/mcr_log.txt \
    && rm -rf mcr_install || (echo "MATLAB Runtime install failed. Log:" && cat /tmp/mcr_log.txt && exit 1)

# Set correct MATLAB Runtime paths for R2025a
ENV LD_LIBRARY_PATH=/opt/mcr/R2025a/runtime/glnxa64:/opt/mcr/R2025a/bin/glnxa64:/opt/mcr/R2025a/sys/os/glnxa64:/opt/mcr/R2025a/sys/opengl/lib/glnxa64


# Copy compiled MATLAB apps and shell scripts into container
WORKDIR /app
COPY ../runSimulationWithAnimation ../run_runSimulationWithAnimation.sh /app/
COPY ../main_run_scenarios ../run_main_run_scenarios.sh /app/
COPY scenarios/ /app/scenarios/
RUN chmod +x runSimulationWithAnimation run_runSimulationWithAnimation.sh main_run_scenarios run_main_run_scenarios.sh
# Disable Docker layer caching from this point forward
ARG CACHEBUST=1
# Create a startup script for interactive use
RUN echo '#!/bin/bash\n\
echo "MATLAB Energy Saving Simulation Container"\n\
echo "Available commands:"\n\
echo "  2. ./run_runSimulationWithAnimation.sh /opt/mcr/R2025a scenarios/indoor_hotspot.json"\n\
echo "  3. ./run_main_run_scenarios.sh /opt/mcr/R2025a"\n\
echo ""\n\
echo "For visualization, make sure to run with X11 forwarding:"\n\
echo "docker run -it --rm -e DISPLAY=\$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix <image>"\n\
echo ""\n\
/bin/bash\n\
' > /app/start.sh && chmod +x /app/start.sh

# Set environment variables for X11 display
ENV DISPLAY=:0.0

# Default command - launches interactive shell with instructions
CMD ["/app/start.sh"]

