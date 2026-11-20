FROM python:3.12-slim
WORKDIR /app
COPY miner_sim.py fake_pool.py ./
RUN useradd -u 10001 -m app
USER 10001
CMD ["python", "miner_sim.py"]
