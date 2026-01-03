# 1. Base Image
FROM ace:13.0.6.0

# 2. Build Arguments
ARG BAR_NAME=default.bar
ARG SERVER_NAME=IntegrationRuntime

# 3. Environment Config
ENV LICENSE=accept
ENV ACE_SERVER_NAME=${SERVER_NAME}

# 4. Switch to root for setup
USER root

# 5. Copy the BAR file to temp location
COPY ${BAR_NAME} /tmp/deploy.bar
RUN chown aceuser:aceuser /tmp/deploy.bar

# 6. Switch to aceuser
USER aceuser

# ==============================================================================
# STEP 7: DEPLOYMENT
# ==============================================================================
RUN bash -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && \
    ibmint deploy \
    --input-bar-file /tmp/deploy.bar \
    --output-work-directory /home/aceuser/ace-server"

# ==============================================================================
# STEP 8: OPTIMIZATION
# ==============================================================================
# This disables the Node.js engine to save RAM.
# Since we are NOT enabling the Admin UI, the server will also turn off the JVM
# if your BAR file doesn't need Java. (Result: <200MB RAM usage).
RUN bash -c "source /opt/ibm/ace-13/server/bin/mqsiprofile && \
    ibmint optimize server \
    --work-directory /home/aceuser/ace-server \
    --disable NodeJS"

# 9. Cleanup
USER root
RUN rm /tmp/deploy.bar
USER aceuser

# 10. Expose Ports
# We ONLY expose 7800 (Application Traffic). 
# 7600 is removed because the Web UI is gone.
EXPOSE 7800

# 11. Start the Server
CMD ["bash", "-c", "source /opt/ibm/ace-13/server/bin/mqsiprofile && IntegrationServer -w /home/aceuser/ace-server"]