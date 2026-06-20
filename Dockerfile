FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && pip3 install jupyterlab --break-system-packages \
    && rm -rf /var/lib/apt/lists/*

USER root
EXPOSE 7860

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=7860", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--ServerApp.disable_check_xsrf=True", "--ServerApp.allow_origin='*'"]
