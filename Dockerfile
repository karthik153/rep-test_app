# 1. Base Image
FROM ace:13.0.6.0

# 2. Build Arguments
ARG BAR_NAME=default.bar
ARG SERVER_NAME=IntegrationRuntime

# 3. Environment Config
ENV LICENSE=accept
ENV ACE_SERVER_NAME=${SERVER_NAME}

# 4. Switch to root to handle file setup
USER root

# ==============================================================================
# STEP 5: COPY ASSETS (BAR, JARS, CONFIG)
# ==============================================================================

# A. Copy the BAR file (Built by Jenkins)
COPY ${BAR_NAME} /tmp/deploy.bar
RUN chown aceuser:aceuser /tmp/deploy.bar

# B. Copy External JAR Files (if they exist)
# We copy everything from config/jars/ to the server's shared-classes folder
# Docker "Hack": Copying a wildcard works even if no files exist, 
# AS LONG AS the destination directory is created first.
COPY config/jars/* /home/aceuser/ace-server/shared-classes/
# Fix permissions so the server can read them
RUN chown -R aceuser:aceuser /home/aceuser/ace-server/shared-classes/

# C. Copy the server.conf.yaml Configuration
COPY config/server.conf.yaml /home/aceuser/ace-server/server.conf.yaml
RUN chown aceuser:aceuser /home/aceuser/ace-server/server.conf.yaml

# Switch back to standard user
USER aceuser

# ==============================================================================
# STEP 7: DEPLOYMENT & OPTIMIZATION
# ==============================================================================
RUN bash -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && \
    ibmint deploy \
    --input-bar-file /tmp/deploy.bar \
    --output-work-directory /home/aceuser/ace-server"

# Run Optimization
RUN bash -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && \
    ibmint optimize server \
    --work-directory /home/aceuser/ace-server \
    --disable NodeJS"

# JVM WORKAROUND (Because we disable NodeJS, optimizer kills JVM)
USER root
RUN sed -i 's/JVM: false/JVM: true/g' /home/aceuser/ace-server/server.components.yaml
RUN rm /tmp/deploy.bar
USER aceuser

# 10. Expose Ports
EXPOSE 7800

# 11. Start the Server
CMD ["bash", "-c", "source /opt/ibm/ace-13/server/bin/mqsiprofile && IntegrationServer -w /home/aceuser/ace-server"]