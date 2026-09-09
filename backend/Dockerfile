FROM python:3.14-slim
WORKDIR /app
COPY server.py seed.json ./
RUN useradd --create-home app && mkdir /data && chown app:app /data
USER app
ENV DATABASE_PATH=/data/carnet.sqlite3 PORT=8000
EXPOSE 8000
CMD ["python", "server.py"]
